#!/bin/bash
original_profile() { [[ "$1" == cnc-original || "$1" == ra-original ]]; }
original_source_id() { if [[ "$1" == cnc-original ]]; then echo cnc; else echo ra; fi; }
original_binary() { if [[ "$1" == cnc-original ]]; then echo vanillatd; else echo vanillara; fi; }
original_config() { if [[ "$1" == cnc-original ]]; then echo CONQUER.INI; else echo REDALERT.INI; fi; }
original_runtime_version() {
  local architecture=x86_64
  [[ "$PLATFORM" != macos ]] || architecture=arm64
  awk -F '\t' '$1=="vanilla-conquer" {engine=$2} $1=="sdl2" {sdl=$2} END {printf "%s+sdl2-%s",engine,sdl}' "$RESOURCES/manifests/original-sources.tsv"
  printf '+%s-%s+%s\n' "$PLATFORM" "$architecture" "$(checksum_file "$RESOURCES/scripts/build-original.sh")"
}
original_dependencies_ready() {
  [[ "$PLATFORM" == linux ]] || return 0
  local binary="$RESOURCES/resources/original-runtime/bin/vanillatd" dependencies
  [[ -x "$binary" ]] || return 1
  dependencies="$(LD_LIBRARY_PATH="$RESOURCES/resources/original-runtime/lib" ldd "$binary" 2>/dev/null)" || return 1
  [[ "$dependencies" != *'not found'* ]]
}
original_engine_ready() {
  local path="$ROOT/engine-$1" stamp
  stamp="$(original_runtime_version)"
  [[ -x "$path/bin/$(original_binary "$1")" && "$(cat "$path/.version" 2>/dev/null)" == "$stamp" && -s "$path/.hashes" ]]
}
original_verify_runtime() {
  local folder="$1" hash file
  [[ -s "$folder/.hashes" ]] || fail 'The original engine package is incomplete. Reinstall the launcher.'
  while IFS=$'\t' read -r hash file; do
    [[ "$file" == bin/* || "$file" == lib/* ]] && [[ "$file" != *..* ]] || fail 'Invalid runtime inventory.'
    verify "$folder/$file" "$hash" || fail 'Original engine files failed verification. Repair the engine.'
    security_scan_download "$folder/$file" "$hash"
  done < "$folder/.hashes"
}
original_install() {
  local source="$RESOURCES/resources/original-runtime" target="$ROOT/engine-$PROFILE"
  original_verify_runtime "$source"
  [[ "$(cat "$source/.version" 2>/dev/null)" == "$(original_runtime_version)" ]] || fail 'The bundled original runtime does not match this platform. Install the correct launcher package.'
  [[ -x "$source/bin/vanillatd" && -x "$source/bin/vanillara" ]] || fail 'This launcher package has no original-game runtime. Install a package built with scripts/build-original.sh.'
  copy_tree "$source" "$WORK/original-engine"
  if [[ "$PLATFORM" == macos ]]; then xattr -dr com.apple.quarantine "$WORK/original-engine" 2>/dev/null || true; fi
  if [[ -d "$target" ]]; then mv "$target" "$WORK/previous-engine"; fi
  if ! mv "$WORK/original-engine" "$target"; then
    [[ ! -d "$WORK/previous-engine" ]] || mv "$WORK/previous-engine" "$target"
    fail 'Could not install original engine; previous installation restored.'
  fi
  original_engine_ready "$PROFILE" || fail 'Original engine installation is incomplete.'
  local id
  id="$(original_source_id "$PROFILE")"
  if classic_raw_ready "$ROOT/$(classic_directory "$id")" "$id"; then original_import; fi
  echo 'Original Vanilla Conquer engine installed. OpenRA remains separate.'
}
original_assets_ready() {
  local profile="$1" source id data
  id="$(original_source_id "$profile")"
  source="$ROOT/$(classic_directory "$id")"
  data="$ROOT/original-$profile/data"
  classic_raw_ready "$source" "$id" || return 1
  [[ -s "$data/.hashes" && -s "$data/$(if [[ "$id" == cnc ]]; then echo CONQUER.MIX; else echo REDALERT.MIX; fi)" ]] || return 1
  if [[ "$id" == ra ]]; then
    local disc
    for disc in allied soviet counterstrike aftermath; do [[ -s "$data/$disc/MAIN.MIX" ]] || return 1; done
  fi
}
original_import() {
  local id source file filename target="$ROOT/original-$PROFILE/data" staged="$WORK/original-data"
  id="$(original_source_id "$PROFILE")"; source="$ROOT/$(classic_directory "$id")"
  classic_raw_ready "$source" "$id" || fail 'Download your owned Steam game first. Original mode needs its complete MIX files.'
  echo 'Preparing your existing Steam files for Original mode…'
  mkdir -p "$staged"
  for file in "$source"/*; do
    [[ -f "$file" ]] || continue
    filename="$(basename "$file" | tr '[:lower:]' '[:upper:]')"
    [[ "$filename" == *.MIX ]] || continue
    cp "$file" "$staged/$filename"
  done
  if [[ "$id" == ra ]]; then
    local number=1 disc
    for disc in allied soviet counterstrike aftermath; do
      mkdir -p "$staged/$disc"
      mv "$staged/MAIN$number.MIX" "$staged/$disc/MAIN.MIX"
      number=$((number+1))
    done
  fi
  (cd "$staged"; find . -type f | LC_ALL=C sort | while read -r file; do printf '%s\t%s\n' "$(checksum_file "$file")" "$file"; done) > "$WORK/original-hashes"
  mv "$WORK/original-hashes" "$staged/.hashes"
  mkdir -p "$(dirname "$target")"
  if [[ -d "$target" ]]; then mv "$target" "$WORK/previous-data"; fi
  if ! mv "$staged" "$target"; then
    [[ ! -d "$WORK/previous-data" ]] || mv "$WORK/previous-data" "$target"
    fail 'Original data import failed; previous files restored.'
  fi
  echo 'Your owned Steam MIX files are prepared for Original mode. No game data was downloaded elsewhere.'
}
original_launch() {
  local full=false width=1280 height=800 argument support="$ROOT/original-$PROFILE" binary config hash file
  if compatibility_running || launcher_native_running; then fail 'Quit the running game before switching games.'; fi
  original_engine_ready "$PROFILE" || fail 'Prepare the original engine first.'
  original_assets_ready "$PROFILE" || fail 'Import or download the owned Steam files for Original mode.'
  original_verify_runtime "$ROOT/engine-$PROFILE"
  while IFS=$'\t' read -r hash file; do verify "$support/data/$file" "$hash" || fail 'Original game files are damaged. Import them again.'; done < "$support/data/.hashes"
  shift 2
  compatibility_parse_display "$@"
  mkdir -p "$support/user" "$ROOT/logs"
  WORK="$(mktemp -d "$ROOT/.original-launch.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT
  binary="$(original_binary "$PROFILE")"; config="$support/user/$(original_config "$PROFILE")"
  printf 'DataPath\t\nUserPath\t\n' > "$support/.paths.tsv"
  merge_ini_settings "$config" Paths "$support/.paths.tsv"
  printf 'Windowed\t%s\nWindowWidth\t%s\nWindowHeight\t%s\n' "$(if [[ "$full" == true ]]; then echo no; else echo yes; fi)" "$width" "$height" > "$support/.video.tsv"
  merge_ini_settings "$config" Video "$support/.video.tsv"
  for file in "$support/data"/*; do
    [[ -e "$file" ]] || continue
    local link="$support/user/$(basename "$file")"
    [[ ! -e "$link" || -L "$link" ]] || fail 'An existing user file conflicts with the original game-data layout. Keep it backed up and move it before retrying.'
    ln -sfn "$file" "$link"
  done
  cp "$ROOT/engine-$PROFILE/bin/$binary" "$support/user/$binary"
  ln -sf "$ROOT/engine-$PROFILE/lib" "$support/lib"
  rm -rf "$WORK"
  trap - EXIT
  export LD_LIBRARY_PATH="$ROOT/engine-$PROFILE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then exec /bin/bash "$GX_LAUNCH_WRAPPER" "$support/user/$binary" > "$ROOT/logs/$PROFILE.log" 2>&1
  else exec "$support/user/$binary" > "$ROOT/logs/$PROFILE.log" 2>&1; fi
}
