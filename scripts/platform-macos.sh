#!/bin/bash
platform_supported() { [[ "$(uname -m)" == arm64 && "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ]]; }
platform_requirement_message() { echo 'This launcher requires Apple Silicon and macOS 15 or later.'; }
dependencies_ready() { return 0; }
steam_ready() { [[ -x "$STEAM_COMMAND" ]]; }
engine_ready() {
  local app="$1" binary library
  binary="$(basename "$app" .app)"
  [[ -x "$app/Contents/MacOS/run.sh" && -s "$app/Contents/Resources/bin/$binary" ]] || return 1
  for library in libvulkan.1.dylib libMoltenVK.dylib libdxvk_d3d8.0.dylib libdxvk_d3d9.0.dylib libSDL3.0.dylib; do
    [[ -s "$app/Contents/Resources/lib/$library" ]] || return 1
  done
}
copy_tree() { cp -cR "$1" "$2" || { rm -rf "$2"; ditto "$1" "$2"; }; }
copy_file() { cp -c "$1" "$2" || cp "$1" "$2"; }
options_directory() { echo "$HOME/Library/Application Support/GeneralsX/$1"; }
launch_engine() { exec /bin/bash "$ENGINE/Contents/MacOS/run.sh" "$@"; }
prepare_steam_login() {
  if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
      printf 'installing-rosetta\n' > "$ROOT/steam-$PROFILE.status"
      printf 'SteamCMD needs Apple Rosetta. Review and accept Apple’s agreement below.\n'
      /usr/sbin/softwareupdate --install-rosetta || fail 'Rosetta installation did not complete.'
    fi

}
engine_install() {
    engine_name=GeneralsXZH; engine_directory=engine; pin=generalsx-macos-vanilla
    if [[ "$PROFILE" == base ]]; then engine_name=GeneralsX; engine_directory=engine-base; pin=generalsx-macos-base; fi
    download_package engine-packages.tsv "$pin"
    ditto -x -k "$CACHE/$PACKAGE_ARCHIVE" "$WORK/engine"
    [[ -x "$WORK/engine/$engine_name.app/Contents/MacOS/run.sh" ]] || fail 'Engine archive is missing its launcher.'
    file "$WORK/engine/$engine_name.app/Contents/Resources/bin/$engine_name" | grep -q arm64 || fail 'Engine is not ARM64.'
    xattr -dr com.apple.quarantine "$WORK/engine/$engine_name.app" 2>/dev/null || true
    if [[ -d "$ROOT/$engine_directory" ]]; then mv "$ROOT/$engine_directory" "$WORK/previous-engine"; fi
    if ! mv "$WORK/engine" "$ROOT/$engine_directory"; then
      [[ ! -d "$WORK/previous-engine" ]] || mv "$WORK/previous-engine" "$ROOT/$engine_directory"
      fail 'Could not install the engine; previous engine restored.'
    fi
    echo 'Engine installed.'

}
steam_install() {
    download_package engine-packages.tsv steamcmd-macos
    mkdir -p "$WORK/steamcmd/MacOS"
    tar -xzf "$CACHE/$PACKAGE_ARCHIVE" -C "$WORK/steamcmd/MacOS"
    [[ -x "$WORK/steamcmd/MacOS/steamcmd.sh" ]] || fail 'SteamCMD bootstrap is incomplete.'
    if [[ ! -d "$ROOT/steamcmd" ]]; then mv "$WORK/steamcmd" "$ROOT/steamcmd"; fi
    echo 'SteamCMD installed. Valve updates it on first run.'

}
