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
    engine_name=GeneralsXZH; engine_directory=engine
    checksum=92930b71c232eb289cf743eb8cdc4081020a870dfdaa2adad553bec2798ac568
    if [[ "$PROFILE" == base ]]; then
      engine_name=GeneralsX; engine_directory=engine-base
      checksum=d5e0d6ff0af760cb157f1602a67ef59212797e4c80cc8a3e4ad1ee4a3a5ef0f2
    fi
    archive="$engine_name-1.0.2.zip"
    download "$archive" "https://github.com/fbraz3/GeneralsX/releases/download/1.0.2/macOS-$engine_name.zip" "$checksum"
    ditto -x -k "$CACHE/$archive" "$WORK/engine"
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
    download steamcmd-bootstrap.tar.gz \
      https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz \
      8ecc17c8988e5acadcc78e631c48490f76150f2dfaa6cf8d7b4b67b097bd753b
    mkdir -p "$WORK/steamcmd/MacOS"
    tar -xzf "$CACHE/steamcmd-bootstrap.tar.gz" -C "$WORK/steamcmd/MacOS"
    [[ -x "$WORK/steamcmd/MacOS/steamcmd.sh" ]] || fail 'SteamCMD bootstrap is incomplete.'
    if [[ ! -d "$ROOT/steamcmd" ]]; then mv "$WORK/steamcmd" "$ROOT/steamcmd"; fi
    echo 'SteamCMD installed. Valve updates it on first run.'

}
