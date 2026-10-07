#!/bin/bash
native_profile() { awk -F '\t' -v id="$1" '$1==id {found=1} END {exit !found}' "$RESOURCES/manifests/native-mods.tsv"; }
native_select() {
  local row
  row="$(awk -F '\t' -v id="$1" '$1==id {print}' "$RESOURCES/manifests/native-mods.tsv")"
  [[ -n "$row" ]] || fail "Unknown native mod: $1"
  IFS=$'\t' read -r NATIVE_ID NATIVE_TITLE NATIVE_PARENTS NATIVE_VERSION NATIVE_MOD NATIVE_APP NATIVE_SOURCE NATIVE_HOME NATIVE_IMAGE NATIVE_SUMMARY <<< "$row"
  NATIVE_ENGINE="$ROOT/engine-native-$NATIVE_ID"
  NATIVE_SUPPORT="$ROOT/native-mod-data/$NATIVE_ID"
  if [[ "$PLATFORM" == macos ]]; then NATIVE_BIN="$NATIVE_ENGINE/$NATIVE_APP.app/Contents/MacOS/arm64"; NATIVE_RESOURCES="$NATIVE_ENGINE/$NATIVE_APP.app/Contents/Resources"
  else NATIVE_BIN="$NATIVE_ENGINE/squashfs-root/usr/lib/openra"; NATIVE_RESOURCES="$NATIVE_BIN"; fi
}
native_engine_ready() {
  native_select "$1"
  [[ "$(cat "$NATIVE_ENGINE/.version" 2>/dev/null)" == "$NATIVE_VERSION" && -s "$NATIVE_BIN/OpenRA.dll" && -s "$NATIVE_BIN/OpenRA.Utility.dll" && -s "$NATIVE_RESOURCES/mods/$NATIVE_MOD/mod.yaml" ]] || return 1
  if [[ "$PLATFORM" == macos ]]; then [[ -s "$NATIVE_BIN/libhostfxr.dylib" && -x "$NATIVE_ENGINE/$NATIVE_APP.app/Contents/MacOS/apphost-arm64" ]]
  else [[ -s "$NATIVE_BIN/libhostfxr.so" && -x "$NATIVE_BIN/OpenRA" ]]; fi
}
remastered_ready() {
  local folder="$ROOT/Remastered" path
  [[ -f "$folder/steamapps/appmanifest_1213210.acf" ]] || return 1
  [[ "$(awk '$1 == "\"StateFlags\"" {gsub(/"/, "", $2); print $2}' "$folder/steamapps/appmanifest_1213210.acf")" == 4 ]] || return 1
  while IFS= read -r path; do [[ -s "$folder/$path" ]] || return 1; done < "$RESOURCES/manifests/tdhd-required.txt"
}
native_ready() {
  local id="$1" path digest
  native_engine_ready "$id" || return 1
  [[ "$(cat "$NATIVE_SUPPORT/.complete" 2>/dev/null)" == "$NATIVE_VERSION" && -s "$NATIVE_SUPPORT/.hashes" ]] || return 1
  if [[ "$NATIVE_SOURCE" == remastered ]]; then remastered_ready || return 1
  else
    while IFS= read -r path; do [[ -s "$NATIVE_SUPPORT/Content/ca/${path#ra/v2/}" ]] || return 1; done < "$RESOURCES/manifests/openra-ra-required.txt"
  fi
}
native_install_engine() {
  native_select "$PROFILE"
  local mac_url mac_hash linux_url linux_hash archive
  IFS=$'\t' read -r id mac_url mac_hash linux_url linux_hash < <(awk -F '\t' -v id="$PROFILE" '$1==id {print}' "$RESOURCES/manifests/native-packages.tsv")
  mkdir -p "$WORK/native-engine"
  if [[ "$PLATFORM" == macos ]]; then
    archive="$(basename "$mac_url")"; download "$archive" "$mac_url" "$mac_hash"
    mkdir -p "$WORK/native-mount"
    hdiutil attach -readonly -nobrowse -mountpoint "$WORK/native-mount" "$CACHE/$archive"
    mounted_classic="$WORK/native-mount"
    ditto "$WORK/native-mount/$NATIVE_APP.app" "$WORK/native-engine/$NATIVE_APP.app"
    hdiutil detach "$mounted_classic"; mounted_classic=''
    xattr -dr com.apple.quarantine "$WORK/native-engine/$NATIVE_APP.app" 2>/dev/null || true
    file "$WORK/native-engine/$NATIVE_APP.app/Contents/MacOS/apphost-arm64" | grep -q arm64 || fail 'Native mod archive lacks its ARM64 runtime.'
  else
    archive="$(basename "$linux_url")"; download "$archive" "$linux_url" "$linux_hash"
    cp "$CACHE/$archive" "$WORK/native-engine/mod.AppImage"; chmod +x "$WORK/native-engine/mod.AppImage"
    (cd "$WORK/native-engine"; ./mod.AppImage --appimage-extract > /dev/null)
    rm "$WORK/native-engine/mod.AppImage"
  fi
  echo "$NATIVE_VERSION" > "$WORK/native-engine/.version"
  if [[ -d "$NATIVE_ENGINE" ]]; then mv "$NATIVE_ENGINE" "$WORK/previous-native-engine"; fi
  if ! mv "$WORK/native-engine" "$NATIVE_ENGINE"; then
    [[ ! -d "$WORK/previous-native-engine" ]] || mv "$WORK/previous-native-engine" "$NATIVE_ENGINE"
    fail 'Could not install the native mod engine; previous engine restored.'
  fi
  native_engine_ready "$PROFILE" || fail 'Native mod runtime is incomplete.'
}
native_prepare() {
  native_engine_ready "$PROFILE" || native_install_engine
  local saved_profile="$PROFILE" saved_game="$GAME"
  native_select "$PROFILE"
  if [[ "$NATIVE_SOURCE" == ra ]] && ! classic_engine_ready ra; then PROFILE=ra; classic_install; PROFILE="$saved_profile"; GAME="$saved_game"; fi
  native_select "$saved_profile"
  steam_ready || steam_install
}
native_utility() {
  local mod="$1"; shift
  if [[ "$PLATFORM" == macos ]]; then
    ENGINE_DIR="$mod" "$NATIVE_ENGINE/$NATIVE_APP.app/Contents/MacOS/apphost-arm64" "$NATIVE_BIN/libhostfxr.dylib" "$NATIVE_BIN/OpenRA.Utility.dll" "$mod" "$@"
  else ENGINE_DIR="$mod" "$NATIVE_BIN/OpenRA.Utility" "$mod" "$@"; fi
}
native_finish() {
  native_select "$PROFILE"
  command -v zip >/dev/null || fail 'Install zip before preparing native mod content.'
  mkdir -p "$WORK/native-content"
  if [[ -d "$NATIVE_SUPPORT" ]]; then copy_tree "$NATIVE_SUPPORT/." "$WORK/native-content"; fi
  rm -rf "$WORK/native-content/Content"
  rm -f "$WORK/native-content/.hashes"
  if [[ "$NATIVE_SOURCE" == ra ]]; then
    classic_raw_ready "$ROOT/RedAlert" ra && classic_raw_ready "$ROOT/TiberianDawn" cnc || fail 'NATIVE_ASSETS_REQUIRED: Combined Arms needs your owned Red Alert and C&C Steam downloads.'
    local saved_profile="$PROFILE" saved_game="$GAME"
    PROFILE=ra; GAME="$ROOT/RedAlert"; classic_import; PROFILE="$saved_profile"; GAME="$saved_game"
    native_select "$PROFILE"
    mkdir -p "$WORK/native-content/Content"
    copy_tree "$ROOT/openra-support/Content/ra/v2" "$WORK/native-content/Content/ca"
    mkdir -p "$WORK/native-content/Content/ca/ra"
    if [[ -s "$WORK/native-content/Content/ca/scores.mix" ]]; then cp "$WORK/native-content/Content/ca/scores.mix" "$WORK/native-content/Content/ca/ra/scores.mix"; fi
    if [[ -s "$ROOT/openra-support/Content/cnc/scores.mix" ]]; then cp "$ROOT/openra-support/Content/cnc/scores.mix" "$WORK/native-content/Content/ca/cnc/scores.mix"; fi
  else
    remastered_ready || fail 'NATIVE_ASSETS_REQUIRED: Tiberian Dawn HD needs your owned Steam Remastered Collection (1213210), separate from Ultimate Collection.'
    mkdir -p "$WORK/native-content/Content/cnc" "$WORK/native-marker"
    echo 'Managed owned Steam source. No EA data is contained in this marker.' > "$WORK/native-marker/source.txt"
    (cd "$WORK/native-marker"; zip -q "$WORK/native-content/Content/cnc/launcher-owned-marker.zip" source.txt)
    local manifest="$NATIVE_RESOURCES/mods/cnc/mod.yaml"
    if [[ ! -f "$NATIVE_ENGINE/mod.yaml.original" ]]; then
      if [[ -f "$manifest.launcher-original" ]]; then cp "$manifest.launcher-original" "$NATIVE_ENGINE/mod.yaml.original"
      else cp "$manifest" "$NATIVE_ENGINE/mod.yaml.original"; fi
    fi
    awk -v path="$ROOT/Remastered" '
      /^\tSystemPackages:/ {print; print "\t\t" path ": data"; next}
      /^\t\tremaster:/ {inside=1; print; next}
      inside && /^\t\ttuc:/ {inside=0}
      inside && /^\t\t\tOrigins:/ {
        print "\t\t\tOrigins:"; print "\t\t\t\tlauncher: CncFreeware";
        print "\t\t\t\t\tPackage: content|launcher-owned-marker.zip";
        print "\t\t\t\t\tPackageMount: launcher-marker";
        print "\t\t\t\t\tISOVolumes:";
        print "\t\t\t\t\tAttributes:";
        print "\t\t\t\t\t\tAudioLanguage: en, de, fr"; print "\t\t\t\t\t\tVideoLanguage: en";
        print "\t\t\t\t\t\tArtworkStyle: remastered, classic"; print "\t\t\t\t\t\tAudioStyle: remastered, classic"; print "\t\t\t\t\t\tMusicStyle: remastered, classic";
        skipping=1; next
      }
      skipping && /^\t\t\tPackages:/ {skipping=0}
      !skipping {print}
    ' "$NATIVE_ENGINE/mod.yaml.original" > "$WORK/native-mod.yaml"
    if [[ -f "$NATIVE_SUPPORT/settings.yaml" ]]; then cp "$NATIVE_SUPPORT/settings.yaml" "$WORK/native-content/settings.yaml"; fi
    printf 'ContentSource\tremaster\nAudioLanguage\ten\nVideoLanguage\ten\nArtworkStyle\tremastered\nAudioStyle\tremastered\nMusicStyle\tremastered\n' > "$WORK/source-settings.tsv"
    merge_yaml_settings "$WORK/native-content/settings.yaml" 'ContentSource@cnc' "$WORK/source-settings.tsv"
  fi
  mkdir -p "$WORK/native-validation/Support"
  cat > "$WORK/native-validation/mod.yaml" <<YAML
Metadata:
	Title: Native mod owned-content validation
	Version: 1
PackageFormats: Mix, MegV3, ZipFile
FileSystem: DefaultFileSystem
	Packages:
		$NATIVE_RESOURCES
YAML
  if [[ "$NATIVE_SOURCE" == remastered ]]; then
    printf '\t\t%s: data\n' "$ROOT/Remastered" >> "$WORK/native-validation/mod.yaml"
    while IFS= read -r path; do printf '\t\tdata|%s\n' "$path" >> "$WORK/native-validation/mod.yaml"; done < "$RESOURCES/manifests/tdhd-required.txt"
  else
    printf '\t\t%s: data\n' "$WORK/native-content/Content/ca" >> "$WORK/native-validation/mod.yaml"
    while IFS= read -r path; do
      [[ "$path" != *.mix ]] || printf '\t\tdata|%s\n' "${path#ra/v2/}" >> "$WORK/native-validation/mod.yaml"
    done < "$RESOURCES/manifests/openra-ra-required.txt"
  fi
  cat >> "$WORK/native-validation/mod.yaml" <<'YAML'
Assemblies: OpenRA.Mods.Common.dll, OpenRA.Mods.Cnc.dll
LoadScreen: NullLoadScreen
TerrainFormat: DefaultTerrain
SpriteSequenceFormat: DefaultSpriteSequence
YAML
  if ! native_utility "$WORK/native-validation" > "$WORK/native-content-validation.log" 2>&1; then
    cat "$WORK/native-content-validation.log"
    fail 'Native runtime could not read the owned source archives. Retry Steam validation; prior profile was preserved.'
  fi
  if [[ "$NATIVE_SOURCE" == remastered ]]; then
    cp "$WORK/native-mod.yaml" "$NATIVE_RESOURCES/mods/cnc/mod.yaml"
    if [[ "$PLATFORM" == macos ]]; then codesign --force --deep --sign - "$NATIVE_ENGINE/$NATIVE_APP.app"; fi
  fi
  if [[ -f "$NATIVE_SUPPORT/settings.yaml" && "$NATIVE_SOURCE" != remastered ]]; then cp "$NATIVE_SUPPORT/settings.yaml" "$WORK/native-content/settings.yaml"; fi
  if [[ "$NATIVE_SOURCE" == ra ]]; then
    while IFS= read -r path; do
      path="Content/ca/${path#ra/v2/}"
      [[ -s "$WORK/native-content/$path" ]] || fail "Required mod content missing: $path"
      if command -v shasum >/dev/null; then digest="$(shasum -a 256 "$WORK/native-content/$path" | awk '{print $1}')"
      else digest="$(sha256sum "$WORK/native-content/$path" | awk '{print $1}')"; fi
      printf '%s\t%s\n' "$path" "$digest" >> "$WORK/native-content/.hashes"
    done < "$RESOURCES/manifests/openra-ra-required.txt"
  else
    digest="$(if command -v shasum >/dev/null; then shasum -a 256 "$NATIVE_RESOURCES/mods/cnc/mod.yaml"; else sha256sum "$NATIVE_RESOURCES/mods/cnc/mod.yaml"; fi | awk '{print $1}')"
    printf 'mod.yaml\t%s\n' "$digest" > "$WORK/native-content/.hashes"
  fi
  echo "$NATIVE_VERSION" > "$WORK/native-content/.complete"
  mkdir -p "$(dirname "$NATIVE_SUPPORT")"
  if [[ -d "$NATIVE_SUPPORT" ]]; then mv "$NATIVE_SUPPORT" "$WORK/previous-native-content"; fi
  if ! mv "$WORK/native-content" "$NATIVE_SUPPORT"; then
    [[ ! -d "$WORK/previous-native-content" ]] || mv "$WORK/previous-native-content" "$NATIVE_SUPPORT"
    fail 'Could not install mod content; previous profile restored.'
  fi
  echo "$NATIVE_TITLE installed using owned Steam assets. Gameplay remains experimental."
}
native_launch() {
  native_ready "$PROFILE" || fail 'Install the native mod and download its required owned Steam assets first.'
  local path digest mode=PseudoFullscreen width=1280 height=720
  while IFS=$'\t' read -r path digest; do
    if [[ "$path" == mod.yaml ]]; then verify "$NATIVE_RESOURCES/mods/cnc/mod.yaml" "$digest" || fail 'Native mod source mapping changed. Repair the mod.'
    else verify "$NATIVE_SUPPORT/$path" "$digest" || fail 'Native mod content is damaged. Repair the mod.'; fi
  done < "$NATIVE_SUPPORT/.hashes"
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in -win) mode=Windowed ;; -fullscreen) mode=PseudoFullscreen ;; -xres) shift; width="$1" ;; -yres) shift; height="$1" ;; *) fail "Unknown launch option: $1" ;; esac
    shift
  done
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || fail 'Invalid display size.'
  mkdir -p "$ROOT/logs"
  local arguments=("Game.Mod=$NATIVE_MOD" "Engine.EngineDir=$NATIVE_RESOURCES" "Engine.SupportDir=$NATIVE_SUPPORT" "Graphics.Mode=$mode" "Graphics.WindowedSize=$width,$height" "Graphics.FullscreenSize=0,0")
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then exec /bin/bash "$GX_LAUNCH_WRAPPER" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1; fi
  cd "$NATIVE_RESOURCES"
  if [[ "$PLATFORM" == macos ]]; then exec "$NATIVE_ENGINE/$NATIVE_APP.app/Contents/MacOS/apphost-arm64" "$NATIVE_BIN/libhostfxr.dylib" "$NATIVE_BIN/OpenRA.dll" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1
  else export LD_LIBRARY_PATH="$NATIVE_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; exec "$NATIVE_BIN/OpenRA" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1; fi
}
