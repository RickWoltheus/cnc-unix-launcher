#!/bin/bash
# OpenRA handles MIX encryption and extraction; the launcher only supplies import paths.
classic_profile() { [[ "$1" == cnc || "$1" == ra ]]; }
classic_directory() { if [[ "$1" == cnc ]]; then echo TiberianDawn; else echo RedAlert; fi; }
classic_app_title() { if [[ "$1" == cnc ]]; then echo 'Tiberian Dawn'; else echo 'Red Alert'; fi; }
classic_engine_path() {
  if [[ "$PLATFORM" == macos ]]; then echo "$ROOT/engine-$1/OpenRA - $(classic_app_title "$1").app"
  else echo "$ROOT/engine-$1/squashfs-root/usr/lib/openra"; fi
}
classic_engine_ready() {
  local location; location="$(classic_engine_path "$1")"
  [[ -f "$ROOT/engine-$1/.openra-20250330" ]] || return 1
  if [[ "$PLATFORM" == macos ]]; then
    [[ -x "$location/Contents/MacOS/apphost-arm64" && -s "$location/Contents/MacOS/arm64/OpenRA.dll" && -s "$location/Contents/MacOS/arm64/libhostfxr.dylib" && -s "$location/Contents/MacOS/arm64/OpenRA.Utility.dll" && -s "$location/Contents/Resources/mods/$1/mod.yaml" ]]
  else
    [[ -x "$location/OpenRA" && -x "$location/OpenRA.Utility" && -s "$location/libhostfxr.so" && -s "$location/mods/$1/mod.yaml" ]]
  fi
}
classic_raw_ready() {
  local folder="$1" id="$2" appid=2229830 filename
  [[ "$id" != ra ]] || appid=2229840
  steam_manifest_ready "$folder" "$appid" || return 1
  local files='conquer.mix desert.mix general.mix sounds.mix temperat.mix winter.mix speech.mix tempicnh.mix transit.mix'
  [[ "$id" != ra ]] || files='redalert.mix main1.mix main2.mix main3.mix main4.mix expand2.mix hires1.mix lores1.mix'
  for filename in $files; do [[ -s "$(find_game_file "$folder" "$filename")" ]] || return 1; done
}
classic_content_ready() {
  local id="$1" file
  [[ -s "$ROOT/openra-support/Content/$id/.launcher-hashes" && "$(cat "$ROOT/openra-support/Content/$id/.launcher-complete" 2>/dev/null)" == release-20250330 ]] || return 1
  while IFS= read -r file; do [[ -s "$ROOT/openra-support/Content/$file" ]] || return 1; done < "$RESOURCES/manifests/openra-$id-required.txt"
}
classic_install() {
  local id="$PROFILE" title checksum archive location
  title="$(classic_app_title "$id")"
  mkdir -p "$WORK/classic"
  if [[ "$PLATFORM" == macos ]]; then
    archive=OpenRA-release-20250330.dmg
    download "$archive" "https://github.com/OpenRA/OpenRA/releases/download/release-20250330/$archive" 2a78cd58603fd06ed6006ae5916065455a7ac7c1290dba1d06c0292bad4238ab
    mkdir -p "$WORK/mount"
    hdiutil attach -readonly -nobrowse -mountpoint "$WORK/mount" "$CACHE/$archive"
    mounted_classic="$WORK/mount"
    ditto "$WORK/mount/OpenRA - $title.app" "$WORK/classic/OpenRA - $title.app"
    hdiutil detach "$mounted_classic"
    mounted_classic=''
    xattr -dr com.apple.quarantine "$WORK/classic/OpenRA - $title.app" 2>/dev/null || true
    file "$WORK/classic/OpenRA - $title.app/Contents/MacOS/apphost-arm64" | grep -q arm64 || fail 'OpenRA archive is missing its ARM64 runtime.'
  else
    command -v curl >/dev/null && command -v file >/dev/null || fail 'Install curl and file before installing OpenRA.'
    archive="OpenRA-${title// /-}-x86_64.AppImage"
    checksum=b3d202d1bf701be5989c41c256d19bd2b1788694df01e343ade865cf1190706b
    [[ "$id" != ra ]] || checksum=3cb71c7428188c8526dd8916993fc16fa17ba5f28a35968a8267f3db9f2186fe
    download "$archive" "https://github.com/OpenRA/OpenRA/releases/download/release-20250330/$archive" "$checksum"
    cp "$CACHE/$archive" "$WORK/classic/engine.AppImage"
    chmod +x "$WORK/classic/engine.AppImage"
    (cd "$WORK/classic"; ./engine.AppImage --appimage-extract > /dev/null)
    rm "$WORK/classic/engine.AppImage"
  fi
  printf 'release-20250330\n' > "$WORK/classic/.openra-20250330"
  if [[ -d "$ROOT/engine-$id" ]]; then mv "$ROOT/engine-$id" "$WORK/previous-classic"; fi
  if ! mv "$WORK/classic" "$ROOT/engine-$id"; then
    [[ ! -d "$WORK/previous-classic" ]] || mv "$WORK/previous-classic" "$ROOT/engine-$id"
    fail 'Could not install OpenRA; previous engine restored.'
  fi
  classic_engine_ready "$id" || fail 'OpenRA runtime is incomplete after installation.'
  echo 'Native OpenRA engine installed. Modernized gameplay; original game compatibility is not promised.'
}
classic_utility() {
  local id="$1" mod="$2"; shift 2
  local location; location="$(classic_engine_path "$id")"
  if [[ "$PLATFORM" == macos ]]; then
    ENGINE_DIR="$mod" "$location/Contents/MacOS/apphost-arm64" \
      "$location/Contents/MacOS/arm64/libhostfxr.dylib" "$location/Contents/MacOS/arm64/OpenRA.Utility.dll" "$mod" "$@"
  else
    ENGINE_DIR="$mod" "$location/OpenRA.Utility" "$mod" "$@"
  fi
}
classic_write_import_mod() {
  local location="$1" folder="$2" archive; shift 2
  cat > "$WORK/import-mod/mod.yaml" <<YAML
Metadata:
	Title: Launcher Steam content import
	Version: 1
PackageFormats: Mix
FileSystem: DefaultFileSystem
	Packages:
		$location
		$folder: source
YAML
  for archive in "$@"; do printf '\t\tsource|%s\n' "$archive" >> "$WORK/import-mod/mod.yaml"; done
  cat >> "$WORK/import-mod/mod.yaml" <<YAML
Assemblies: OpenRA.Mods.Common.dll, OpenRA.Mods.Cnc.dll
LoadScreen: NullLoadScreen
TerrainFormat: DefaultTerrain
SpriteSequenceFormat: DefaultSpriteSequence
YAML
}
classic_import() {
  local id="$PROFILE" op archive src dest path sourcefile location group=0 previous='' output
  classic_engine_ready "$id" || fail 'Prepare the OpenRA engine before importing Steam files.'
  classic_raw_ready "$GAME" "$id" || fail 'Steam files are incomplete. Retry the Steam download.'
  mkdir -p "$WORK/content/$id" "$WORK/import-mod/Support" "$WORK/extracted"
  location="$(classic_engine_path "$id")"
  [[ "$PLATFORM" != macos ]] || location="$location/Contents/Resources"
  while IFS=$'\t' read -r op archive src dest; do
    if [[ "$op" == delete ]]; then rm -f "$WORK/content/$src"; continue; fi
    mkdir -p "$(dirname "$WORK/content/$dest")"
    if [[ "$op" == copy ]]; then
      sourcefile="$(find_game_file "$GAME" "$src")"
      [[ -n "$sourcefile" ]] || { echo "Optional content absent: $src"; continue; }
      copy_file "$sourcefile" "$WORK/content/$dest"
      continue
    fi
    if [[ "$archive" == @content/* ]]; then path="$WORK/content/${archive#@content/}"
    else path="$(find_game_file "$GAME" "$archive")"; fi
    [[ -s "$path" ]] || { echo "Optional content absent: $archive"; continue; }
    if [[ "$path" != "$previous" ]]; then
      group=$((group+1)); previous="$path"
      output="$WORK/extracted/$group"; mkdir -p "$output"
      classic_write_import_mod "$location" "$(dirname "$path")" "$(basename "$path")"
      # Extract the current group in one utility invocation, including nested archives.
      files=()
      while IFS=$'\t' read -r nextop nextarchive nextsrc nextdest; do
        [[ "$nextop" != extract || "$nextarchive" != "$archive" ]] || files+=("$nextsrc")
      done < "$RESOURCES/manifests/openra-$id-import.tsv"
      (cd "$output"; classic_utility "$id" "$WORK/import-mod" --extract "${files[@]}")
    fi
    [[ -s "$output/$src" ]] || fail "OpenRA could not extract $src from $archive. Steam data may be corrupt or unsupported."
    copy_file "$output/$src" "$WORK/content/$dest"
  done < "$RESOURCES/manifests/openra-$id-import.tsv"
  if [[ "$id" == ra ]]; then
    classic_raw_ready "$ROOT/TiberianDawn" cnc || fail 'Red Alert also needs your complete C&C Steam installation. Retry the Steam download.'
    sourcefile="$(find_game_file "$ROOT/TiberianDawn" DESERT.MIX)"
    [[ -s "$sourcefile" ]] || fail 'Red Alert needs the C&C desert tileset. Download Command & Conquer through Steam as well.'
    mkdir -p "$WORK/content/ra/v2/cnc"; copy_file "$sourcefile" "$WORK/content/ra/v2/cnc/desert.mix"
  fi
  packages=()
  while IFS= read -r path; do
    [[ "$path" != *.mix ]] || packages+=("$path")
  done < "$RESOURCES/manifests/openra-$id-required.txt"
  classic_write_import_mod "$location" "$WORK/content" "${packages[@]}"
  if ! classic_utility "$id" "$WORK/import-mod" > "$WORK/content-validation.log" 2>&1; then
    cat "$WORK/content-validation.log"
    fail 'OpenRA could not read the imported MIX containers. Retry Steam validation; previous content was preserved.'
  fi
  while IFS= read -r path; do
    [[ -s "$WORK/content/$path" ]] || fail "Required OpenRA content is missing: $path. Retry Steam download."
    if command -v shasum >/dev/null; then checksum="$(shasum -a 256 "$WORK/content/$path" | awk '{print $1}')"
    else checksum="$(sha256sum "$WORK/content/$path" | awk '{print $1}')"; fi
    printf '%s\t%s\n' "$path" "$checksum" >> "$WORK/content/$id/.launcher-hashes"
  done < "$RESOURCES/manifests/openra-$id-required.txt"
  echo release-20250330 > "$WORK/content/$id/.launcher-complete"
  mkdir -p "$ROOT/openra-support/Content"
  if [[ -d "$ROOT/openra-support/Content/$id" ]]; then mv "$ROOT/openra-support/Content/$id" "$WORK/previous-content"; fi
  if ! mv "$WORK/content/$id" "$ROOT/openra-support/Content/$id"; then
    [[ ! -d "$WORK/previous-content" ]] || mv "$WORK/previous-content" "$ROOT/openra-support/Content/$id"
    fail 'Could not install imported content; previous content restored.'
  fi
  echo 'Owned Steam files imported into OpenRA. No third-party game-data download was used.'
}
classic_launch() {
  local mode=PseudoFullscreen width=1280 height=720 location path checksum
  classic_engine_ready "$PROFILE" || fail 'Prepare the OpenRA engine first.'
  classic_content_ready "$PROFILE" || fail 'Import your Steam assets first.'
  while IFS=$'\t' read -r path checksum; do verify "$ROOT/openra-support/Content/$path" "$checksum" || fail 'Imported OpenRA content is damaged. Retry Steam download to repair it.'; done < "$ROOT/openra-support/Content/$PROFILE/.launcher-hashes"
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in -win) mode=Windowed ;; -fullscreen) mode=PseudoFullscreen ;; -xres) shift; width="$1" ;; -yres) shift; height="$1" ;; *) fail "Unknown classic launch option: $1" ;; esac
    shift
  done
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || fail 'Invalid display size.'
  location="$(classic_engine_path "$PROFILE")"
  mkdir -p "$ROOT/logs"
  local arguments=("Game.Mod=$PROFILE" "Engine.SupportDir=$ROOT/openra-support" "Graphics.Mode=$mode" "Graphics.WindowedSize=$width,$height" "Graphics.FullscreenSize=0,0")
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then exec /bin/bash "$GX_LAUNCH_WRAPPER" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1; fi
  if [[ "$PLATFORM" == macos ]]; then
    cd "$location/Contents/Resources"
    exec "$location/Contents/MacOS/apphost-arm64" "$location/Contents/MacOS/arm64/libhostfxr.dylib" "$location/Contents/MacOS/arm64/OpenRA.dll" "Engine.EngineDir=$location/Contents/Resources" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1
  else
    cd "$location"
    export LD_LIBRARY_PATH="$location${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "$location/OpenRA" "Engine.EngineDir=$location" "${arguments[@]}" > "$ROOT/logs/$PROFILE.log" 2>&1
  fi
}
