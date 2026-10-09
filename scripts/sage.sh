#!/bin/bash
sage_profile() { [[ "$(awk -F '\t' -v id="$1" '$1==id {print $5}' "$RESOURCES/manifests/compatibility.tsv")" == sage ]]; }
sage_supported() { [[ "$PLATFORM" == linux || "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]]; }
sage_steam_root() {
  local path
  if [[ -n "${GX_STEAM_ROOT:-}" ]]; then printf '%s\n' "$GX_STEAM_ROOT"; return; fi
  for path in "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
    [[ ! -d "$path/steamapps" ]] || { printf '%s\n' "$path"; return; }
  done
}
sage_steam_binary() {
  local path
  for path in /usr/bin/steam /usr/games/steam; do
    [[ ! -x "$path" ]] || { printf '%s\n' "$path"; return; }
  done
}
sage_steam_ready() { [[ -n "$(sage_steam_binary)" && -n "$(sage_steam_root)" ]]; }
sage_libraries() {
  local root
  root="$(sage_steam_root)"; [[ -n "$root" ]] || return 0
  printf '%s\n' "$root"
  if [[ -f "$root/steamapps/libraryfolders.vdf" ]]; then
    awk -F '"' '$2=="path" {print $4}' "$root/steamapps/libraryfolders.vdf"
  fi
}
sage_steam_game() {
  local library manifest directory appid
  appid="$(compatibility_metadata "$1" 5)"
  while IFS= read -r library; do
    manifest="$library/steamapps/appmanifest_$appid.acf"
    [[ -f "$manifest" ]] || continue
    directory="$(awk -F '"' '$2=="installdir" {print $4}' "$manifest")"
    [[ -n "$directory" && "$directory" != */* && "$directory" != *\\* && "$directory" != . && "$directory" != .. ]] || continue
    printf '%s/steamapps/common/%s\n' "$library" "$directory"; return
  done < <(sage_libraries)
}
sage_proton_tool() {
  local root appid
  root="$(sage_steam_root)"; appid="$(compatibility_metadata "$1" 5)"
  [[ -f "$root/config/config.vdf" ]] || return 1
  awk -F '"' -v id="$appid" '
    $2=="CompatToolMapping" {pending=1}
    pending && index($0,"{") {mapping=1; mapDepth=depth+1; pending=0}
    mapping && depth==mapDepth && ($2==id || $2=="0") {entry=$2}
    mapping && entry && depth==mapDepth+1 && $2=="name" {if (entry==id) {specific=$4; explicit=1} else fallback=$4}
    {line=$0; opens=gsub(/\{/,"",line); closes=gsub(/}/,"",line); depth+=opens-closes
     if (closes && mapping && depth<=mapDepth) entry=0
     if (mapping && depth<mapDepth) mapping=0}
    END {tool=explicit ? specific : fallback; if (tolower(tool) ~ /^proton/) print tool; else exit 1}' "$root/config/config.vdf"
}
sage_proton_ready() {
  local library path tool
  tool="$(sage_proton_tool "$1")" || return 1
  while IFS= read -r library; do
    for path in "$library"/steamapps/common/Proton*/proton; do
      [[ -f "$path" && -f "$(dirname "$path")/compatibilitytool.vdf" ]] || continue
      if awk -F '"' -v tool="$tool" '$2==tool {found=1} END {exit !found}' "$(dirname "$path")/compatibilitytool.vdf"; then return 0; fi
    done
  done < <(sage_libraries)
  return 1
}
sage_engine_ready() {
  sage_supported || return 1
  if [[ "$PLATFORM" == linux ]]; then sage_steam_ready && sage_proton_ready "${1:-$PROFILE}"; return; fi
  [[ -x "$ROOT/sage-runtime/wine/wswine.bundle/bin/wine" &&
     "$(cat "$ROOT/sage-runtime/.version" 2>/dev/null)" == WS12WineSikarugir11.0_1+Template-1.0.21 &&
     -s "$ROOT/sage-runtime/Frameworks/renderer/d9vk/wine/i386-windows/d3d9.dll" &&
     -s "$ROOT/sage-runtime/Frameworks/libvulkan_kosmickrisp.dylib" &&
     -s "$ROOT/sage-runtime/Resources/vulkan/icd.d/kosmickrisp_mesa_icd.json" ]]
}
sage_config() {
  local folder="$1" prefix=CNC3 config name major minor best_major=-1 best_minor=-1 selected=''
  [[ "$2" != kw ]] || prefix=CNC3EP1
  for config in "$folder"/"${prefix}"_english_*.SkuDef "$folder"/"${prefix}"_english_*.skudef; do
    [[ -f "$config" ]] || continue
    name="${config##*/}"; name="${name#${prefix}_english_}"; name="${name%.*}"
    [[ "$name" =~ ^([0-9]+)\.([0-9]+)$ ]] || continue
    major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"
    if (( 10#$major > best_major || (10#$major == best_major && 10#$minor > best_minor) )); then
      best_major=$((10#$major)); best_minor=$((10#$minor)); selected="$config"
    fi
  done
  printf '%s\n' "$selected"
}
sage_executable() {
  local folder="$1" config="$2" relative
  [[ -f "$config" ]] || return 0
  relative="$(awk 'tolower($1)=="set-exe" {sub(/^[^ \t]+[ \t]+/, ""); sub(/\r$/, ""); print; exit}' "$config")"
  relative="${relative//\\//}"; relative="${relative#\"}"; relative="${relative%\"}"
  [[ -n "$relative" && "$relative" != /* && "$relative" != *:* && "/$relative/" != */../* && "/$relative/" != */./* ]] || return 0
  [[ -f "$folder/$relative" ]] && printf '%s/%s\n' "$folder" "$relative"
}
sage_assets_ready() {
  local id="$1" folder appid config executable manifest
  compatibility_select "$id"; folder="$COMPAT_GAME"; appid="$(compatibility_metadata "$id" 5)"
  [[ -d "$folder" ]] || return 1
  if [[ "$PLATFORM" == linux ]]; then
    manifest="$(dirname "$(dirname "$folder")")/appmanifest_$appid.acf"
    [[ "$(awk -F '"' '$2=="StateFlags" {print $4}' "$manifest" 2>/dev/null)" == 4 ]] || return 1
  else steam_manifest_ready "$folder" "$appid" || return 1; fi
  config="$(sage_config "$folder" "$id")"; executable="$(sage_executable "$folder" "$config")"
  [[ -s "$executable" && "$(head -c 2 "$executable")" == MZ ]]
}
sage_open_steam() {
  local binary
  binary="$(sage_steam_binary)"; [[ -n "$binary" ]] || fail 'Install the native Linux Steam client from your distribution first. Flatpak Steam integration is not supported yet.'
  mkdir -p "$ROOT/logs"
  "$binary" "$1" > /dev/null 2>&1 < /dev/null &
}
sage_install() {
  sage_supported || fail 'C&C 3 on Mac currently requires macOS Tahoe 26 or later. Older games keep their existing requirements.'
  if [[ "$PLATFORM" == linux ]]; then
    sage_steam_ready || fail 'Install and open the native Linux Steam client, then use Open Steam setup.'
    sage_proton_ready "$PROFILE" || fail 'In Steam, enable Proton for this game in Properties → Compatibility, then install it and start it once to download Proton. Return here afterwards.'
    echo 'Steam manages Proton and its updates. Set this game to Proton 11 in Steam Properties → Compatibility.'; return
  fi
  local template binary
  compatibility_package sage-macos
  download "$COMPAT_ARCHIVE" "$COMPAT_URL" "$COMPAT_SHA"
  mkdir -p "$WORK/sage/wine"
  tar -xJf "$CACHE/$COMPAT_ARCHIVE" -C "$WORK/sage/wine"
  binary="$WORK/sage/wine/$COMPAT_BINARY"
  [[ -x "$binary" ]] || fail 'Sikarugir engine is incomplete.'
  compatibility_package sage-graphics
  download "$COMPAT_ARCHIVE" "$COMPAT_URL" "$COMPAT_SHA"
  mkdir -p "$WORK/template" "$WORK/sage/Frameworks/renderer" "$WORK/sage/Resources/vulkan/icd.d"
  tar -xJf "$CACHE/$COMPAT_ARCHIVE" -C "$WORK/template"
  template="$WORK/template/$COMPAT_BINARY"
  cp -R "$template/Frameworks/"*.dylib "$WORK/sage/Frameworks/"
  cp -R "$template/Frameworks/GStreamer.framework" "$WORK/sage/Frameworks/"
  cp -R "$template/Frameworks/renderer/d9vk" "$WORK/sage/Frameworks/renderer/"
  cp "$template/Resources/vulkan/icd.d/kosmickrisp_mesa_icd.json" "$WORK/sage/Resources/vulkan/icd.d/"
  [[ "$(head -c 2 "$WORK/sage/Frameworks/renderer/d9vk/wine/i386-windows/d3d9.dll")" == MZ ]] || fail 'DirectX 9 renderer is incomplete.'
  cp "$RESOURCES/manifests/sage-notice.txt" "$WORK/sage/NOTICE.txt"
  printf 'WS12WineSikarugir11.0_1+Template-1.0.21\n' > "$WORK/sage/.version"
  xattr -dr com.apple.quarantine "$WORK/sage" 2>/dev/null || true
  if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then "$binary" --version; fi
  [[ ! -d "$ROOT/sage-runtime" ]] || mv "$ROOT/sage-runtime" "$WORK/previous-sage"
  if ! mv "$WORK/sage" "$ROOT/sage-runtime"; then
    [[ ! -d "$WORK/previous-sage" ]] || mv "$WORK/previous-sage" "$ROOT/sage-runtime"
    fail 'Sikarugir installation failed; previous runtime restored.'
  fi
  sage_engine_ready || fail 'Sikarugir runtime is incomplete.'
  echo 'Experimental Sikarugir DirectX 9 runtime prepared. No game or Wine prefix was started.'
}
sage_launch() {
  local profile="$PROFILE" full=false width=1280 height=720 argument folder config executable binary result=0 attempt seen=0
  compatibility_running && fail 'A game is already running. Quit it before switching games.'
  pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1 && fail 'Quit the running game before switching games.'
  sage_engine_ready "$profile" || fail 'Prepare the C&C 3 runtime first. Mac requires Tahoe; Linux requires Steam and Proton.'
  sage_assets_ready "$profile" || fail 'Install and validate the English Steam game first.'
  shift 2
  compatibility_parse_display "$@"
  compatibility_begin_launch "$profile"
  if [[ "$PLATFORM" == macos ]]; then compatibility_prepare_game "$profile"; folder="$COMPAT_PLAY"; else folder="$COMPAT_GAME"; fi
  config="$(sage_config "$folder" "$profile")"; executable="$(sage_executable "$folder" "$config")"
  local args=(-config "Z:$config" -xres "$width" -yres "$height")
  [[ "$full" == true ]] || args+=(-win)
  printf '%s\n%s\nstarting\n' "$$" "$profile" > "$ROOT/.compatibility-running"
  rm -rf "$LOCK"
  cd "$folder"
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then
    /bin/bash "$GX_LAUNCH_WRAPPER" "$executable" "${args[@]}" > "$ROOT/logs/$profile.log" 2>&1; return
  fi
  if [[ "$PLATFORM" == linux ]]; then
    binary="$(sage_steam_binary)"
    local steam_args=(-applaunch "$(compatibility_metadata "$profile" 5)" -xres "$width" -yres "$height")
    if [[ "$full" == true ]]; then steam_args+=(-fullscreen); else steam_args+=(-win); fi
    printf 'Handing the selected game to Steam Proton. Steam diagnostics stay in Steam.\n' > "$ROOT/logs/$profile.log"
    "$binary" "${steam_args[@]}" > /dev/null 2>&1 < /dev/null &
    # The Steam command returns before Proton's game process. Keep our session open.
    for attempt in $(seq 1 240); do
      if [[ -n "$(compatibility_game_pids "$profile")" ]]; then seen=1; break; fi
      sleep 0.5
    done
    [[ "$seen" == 1 ]] || fail 'Steam did not start a detectable game within two minutes. Check its Compatibility setting and launch it once from Steam.'
    printf '%s\n%s\nplaying\n' "$$" "$profile" > "$ROOT/.compatibility-running"
    while [[ -n "$(compatibility_game_pids "$profile")" ]]; do sleep 0.5; done
  else
    binary="$ROOT/sage-runtime/wine/wswine.bundle/bin/wine"
    export SikarugirAppWine11=1
    export WINEPREFIX="$COMPAT_PREFIX" WINEARCH=win64 WINEDEBUG=-all
    export DYLD_FALLBACK_LIBRARY_PATH="$ROOT/sage-runtime/Frameworks:/usr/lib"
    export GST_PLUGIN_PATH="$ROOT/sage-runtime/Frameworks/GStreamer.framework/Versions/1.0/lib/gstreamer-1.0"
    export VK_DRIVER_FILES="$ROOT/sage-runtime/Resources/vulkan/icd.d/kosmickrisp_mesa_icd.json"
    export WINEDLLOVERRIDES='d3d9=n,b;winemenubuilder.exe=d;mscoree,mshtml=d'
    compatibility_reset_prefix "$profile" || fail 'Could not clean up the old C&C 3 Wine session.'
    if [[ ! -f "$COMPAT_PREFIX/.initialized" ]]; then
      "$binary" wineboot -u > "$ROOT/logs/$profile.log" 2>&1 || fail 'C&C 3 prefix initialization failed. Check its profile log.'
      touch "$COMPAT_PREFIX/.initialized"
    fi
    cp "$ROOT/sage-runtime/Frameworks/renderer/d9vk/wine/i386-windows/d3d9.dll" "$COMPAT_PREFIX/drive_c/windows/syswow64/d3d9.dll"
    cp "$ROOT/sage-runtime/Frameworks/renderer/d9vk/wine/x86_64-windows/d3d9.dll" "$COMPAT_PREFIX/drive_c/windows/system32/d3d9.dll"
    "$binary" "$executable" "${args[@]}" >> "$ROOT/logs/$profile.log" 2>&1 &
    compatibility_wait_for_game "$!" "$profile"
  fi
}
