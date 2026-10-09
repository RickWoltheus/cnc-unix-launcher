#!/bin/bash
sage_profile() { [[ "$(awk -F '\t' -v id="$1" '$1==id {print $5}' "$RESOURCES/manifests/compatibility.tsv")" == sage ]]; }
sage_wine10_profile() {
  [[ "$PLATFORM" == macos && "$(cat "$ROOT/compatibility/$1/.runtime-choice" 2>/dev/null)" == wine10-test ]]
}
sage_mac_prefix() {
  if sage_wine10_profile "$1"; then printf '%s/compatibility/%s/wine10-test/prefix\n' "$ROOT" "$1"
  else printf '%s/compatibility/%s/prefix\n' "$ROOT" "$1"; fi
}
sage_mac_wine() {
  if sage_wine10_profile "$1"; then printf '%s/compatibility/%s/wine10-test/engine/wswine.bundle/bin/wine\n' "$ROOT" "$1"
  else printf '%s/sage-runtime/wine/wswine.bundle/bin/wine\n' "$ROOT"; fi
}
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
  if sage_wine10_profile "${1:-$PROFILE}"; then
    [[ -x "$(sage_mac_wine "${1:-$PROFILE}")" && "$(cat "$ROOT/compatibility/${1:-$PROFILE}/wine10-test/.version" 2>/dev/null)" == WS12WineSikarugir10.0_6 ]]; return
  fi
  [[ -x "$ROOT/sage-runtime/wine/wswine.bundle/bin/wine" &&
     "$(cat "$ROOT/sage-runtime/.version" 2>/dev/null)" == WS12WineSikarugir10.0_6+Template-1.0.21+D9VK &&
     -s "$ROOT/sage-runtime/Frameworks/renderer/dxvk/wine/i386-windows/d3d9.dll" ]] || return 1
  local architecture
  for architecture in i386-windows x86_64-windows; do
    cmp -s "$ROOT/sage-runtime/wine/wswine.bundle/lib/wine/$architecture/d3d9.dll" "$ROOT/sage-runtime/Frameworks/renderer/dxvk/wine/$architecture/d3d9.dll" || return 1
  done
}
sage_config() {
  local folder="$1" prefix config name major minor best_major=-1 best_minor=-1 selected=''
  prefix="$(awk -F '\t' -v id="$2" '$1==id {print $2}' "$RESOURCES/manifests/compatibility.tsv")"; prefix="${prefix%.*}"
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
  sage_supported || fail 'These DirectX 9 games on Mac currently require macOS Tahoe 26 or later. Older games keep their existing requirements.'
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
  cp -R "$template/Frameworks/renderer/dxvk" "$WORK/sage/Frameworks/renderer/"
  local architecture
  for architecture in i386-windows x86_64-windows; do
    cp "$template/Frameworks/renderer/dxvk/wine/$architecture/d3d9.dll" "$WORK/sage/wine/wswine.bundle/lib/wine/$architecture/d3d9.dll"
  done
  [[ "$(head -c 2 "$WORK/sage/Frameworks/renderer/dxvk/wine/i386-windows/d3d9.dll")" == MZ ]] || fail 'DirectX 9 renderer is incomplete.'
  cp "$RESOURCES/manifests/sage-notice.txt" "$WORK/sage/NOTICE.txt"
  printf 'WS12WineSikarugir10.0_6+Template-1.0.21+D9VK\n' > "$WORK/sage/.version"
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
sage_prepare_windows_steam() {
  local binary="$1" profile="$2" steam_directory installer manifest directory
  steam_directory="$COMPAT_PREFIX/drive_c/Program Files (x86)/Steam"
  SAGE_STEAM_EXE="$steam_directory/steam.exe"
  if [[ ! -s "$SAGE_STEAM_EXE" ]]; then
    compatibility_package sage-steam
    download "$COMPAT_ARCHIVE" "$COMPAT_URL" "$COMPAT_SHA"
    installer="$CACHE/$COMPAT_ARCHIVE"
    printf 'Installing Valve’s Windows Steam client for game authentication.\n'
    "$binary" "$installer" /S > /dev/null 2>&1 || fail 'Windows Steam installation failed. Retry Play to run the official installer again.'
    [[ -s "$SAGE_STEAM_EXE" ]] || fail 'Valve’s installer did not create the Windows Steam client.'
  fi
  manifest="$COMPAT_GAME/steamapps/appmanifest_$(compatibility_metadata "$profile" 5).acf"
  directory="$(awk -F '\"' '$2=="installdir" {print $4}' "$manifest")"
  [[ -n "$directory" && "$directory" != */* && "$directory" != *\\* && "$directory" != . && "$directory" != .. ]] || fail 'The owned Steam manifest has an invalid installation directory.'
  mkdir -p "$steam_directory/steamapps/common"
  if [[ ! -e "$steam_directory/steamapps/common/$directory" ]]; then
    ln -s "$COMPAT_PLAY" "$steam_directory/steamapps/common/$directory"
  fi
  [[ "$steam_directory/steamapps/common/$directory" -ef "$COMPAT_PLAY" ]] || fail 'Steam already has a different copy of this game. Use its installation or select a separate profile.'
  local destination="$steam_directory/steamapps/$(basename "$manifest")"
  # Steam may update its own manifest after registration; retain that newer state.
  [[ -f "$destination" ]] || copy_file "$manifest" "$destination"
}
sage_prepare_steam_browser() {
  local binary="$1" profile="$2" steam_directory="$(dirname "$SAGE_STEAM_EXE")" result=0 attempt
  steam_webhelper_install "$steam_directory" || result=$?
  [[ "$result" != 0 ]] || return 0
  [[ "$result" == 2 ]] || return "$result"
  printf 'Steam is downloading its browser components. Applying the Wine compatibility fix when ready.\n'
  "$binary" "$SAGE_STEAM_EXE" -silent -cef-disable-gpu > /dev/null 2>&1 < /dev/null &
  local ready=0
  for attempt in $(seq 1 480); do
    if [[ -d "$steam_directory/bin/cef" ]] && [[ -n "$(find "$steam_directory/bin/cef" -maxdepth 2 -type f -name steamwebhelper.exe -print -quit)" ]]; then ready=1; break; fi
    sleep 0.5
  done
  [[ "$ready" == 1 ]] || fail 'Steam has not finished downloading its browser. Let its update finish, then retry Play.'
  sleep 2
  compatibility_reset_prefix "$profile" || fail 'Close this profile’s Steam window before applying its browser fix.'
  steam_webhelper_install "$steam_directory" || fail 'Steam browser setup is incomplete. Finish its update and retry Play.'
}
sage_wait_for_game() {
  local profile="$1" limit="$2" seen=0 attempt
  for attempt in $(seq 1 "$limit"); do
    if [[ -n "$(compatibility_game_pids "$profile")" ]]; then seen=1; break; fi
    sleep 0.5
  done
  [[ "$seen" == 1 ]] || fail 'Steam did not start the game. Finish signing in in the Steam window, then retry Play or start the game from its Steam library.'
  printf '%s\n%s\nplaying\n' "$$" "$profile" > "$ROOT/.compatibility-running"
  while [[ -n "$(compatibility_game_pids "$profile")" ]]; do sleep 0.5; done
}
sage_launch() {
  local profile="$PROFILE" full=false width=1280 height=720 argument folder config executable binary result=0 attempt seen=0
  compatibility_running && fail 'A game is already running. Quit it before switching games.'
  pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1 && fail 'Quit the running game before switching games.'
  sage_engine_ready "$profile" || fail 'Prepare the DirectX 9 runtime first. Mac requires Tahoe; Linux requires Steam and Proton.'
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
    sage_wait_for_game "$profile" 240
  else
    binary="$(sage_mac_wine "$profile")"
    export SikarugirAppWine10=1 SikarugirAppWine11=1
    export WINEPREFIX="$COMPAT_PREFIX" WINEARCH=win64 WINEDEBUG=-all
    export DYLD_FALLBACK_LIBRARY_PATH="$ROOT/sage-runtime/Frameworks:/usr/lib"
    export GST_PLUGIN_PATH="$ROOT/sage-runtime/Frameworks/GStreamer.framework/Versions/1.0/lib/gstreamer-1.0"
    unset DYLD_LIBRARY_PATH VK_DRIVER_FILES VK_ICD_FILENAMES DXVK_FORCE_WINDOWED
    export WINEDLLOVERRIDES='d3d9=b;d3dx9_29,d3dx9_36=n,b;gameoverlayrenderer,gameoverlayrenderer64=d;winemenubuilder.exe=d;mscoree,mshtml=d'
    export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=0 DXVK_ASYNC=1 DXVK_LOG_PATH="$ROOT/logs"
    if [[ ! -f "$COMPAT_PREFIX/.initialized" ]]; then
      "$binary" wineboot -u > "$ROOT/logs/$profile.log" 2>&1 || fail 'Game prefix initialization failed. Check its profile log.'
      touch "$COMPAT_PREFIX/.initialized"
    fi
    sage_prepare_windows_steam "$binary" "$profile"
    sage_prepare_steam_browser "$binary" "$profile"
    local renderer_choice
    renderer_choice="$(cat "$ROOT/compatibility/$profile/.renderer-choice" 2>/dev/null || true)"
    if sage_wine10_profile "$profile" && [[ "$renderer_choice" != builtin ]]; then
      binary="$ROOT/compatibility/$profile/wine10-test/engine-legacy/wswine.bundle/bin/wine"
      [[ -x "$binary" ]] || fail 'The comparison renderer is missing. Restore the built-in renderer before retrying.'
    elif sage_wine10_profile "$profile"; then
      unset MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS DXVK_ASYNC
    fi
    local steam_args=(-cef-disable-gpu -cef-disable-gpu-compositing -applaunch "$(compatibility_metadata "$profile" 5)" -xres "$width" -yres "$height")
    if [[ "$full" == true ]]; then steam_args+=(-fullscreen); else steam_args+=(-win); fi
    printf 'Opening Valve’s Windows Steam client. Complete sign-in in its own window if requested.\n'
    "$binary" "$SAGE_STEAM_EXE" "${steam_args[@]}" > /dev/null 2>&1 < /dev/null &
    sage_wait_for_game "$profile" 1200
  fi
}
