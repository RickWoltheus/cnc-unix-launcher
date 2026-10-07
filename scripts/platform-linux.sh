#!/bin/bash
STEAM_COMMAND="$ROOT/steamcmd/steamcmd.sh"
FLATPAK="${GX_FLATPAK:-flatpak}"
platform_supported() { [[ "$(uname -m)" == x86_64 ]]; }
platform_requirement_message() { echo 'Linux preview requires an x86_64 Linux desktop with Vulkan support.'; }
dependencies_ready() {
  command -v "$FLATPAK" >/dev/null && command -v curl >/dev/null && command -v file >/dev/null && command -v zip >/dev/null &&
    [[ -e /lib/ld-linux.so.2 || -e /lib32/ld-linux.so.2 || -e /lib/i386-linux-gnu/ld-linux.so.2 ]] &&
    { ! compatibility_profile "$PROFILE" || compatibility_dependencies_ready; }
}
steam_ready() { [[ -x "$STEAM_COMMAND" ]] && dependencies_ready; }
app_id() { if [[ "$1" == */GeneralsX.app ]]; then echo com.fbraz3.GeneralsX; else echo com.fbraz3.GeneralsXZH; fi; }
engine_ready() {
  local id stamp commit
  id="$(app_id "$1")"; stamp="$ROOT/linux-engines/$id.commit"
  [[ -s "$stamp" && "$(head -n 1 "$stamp")" == 1.0.2 ]] || return 1
  command -v "$FLATPAK" >/dev/null || return 1
  commit="$("$FLATPAK" info --user --show-commit "$id" 2>/dev/null)" || return 1
  [[ "$commit" == "$(tail -n 1 "$stamp")" ]]
}
copy_tree() { cp --reflink=auto -a "$1" "$2"; }
copy_file() { cp --reflink=auto "$1" "$2"; }
options_directory() { echo "$ROOT/user-data/GeneralsX/$1"; }
prepare_steam_login() { dependencies_ready || fail 'Install Linux dependencies from Prepare Mac/Linux before signing in.'; }
engine_install() {
  dependencies_ready || fail 'Linux dependencies are missing. Install Flatpak and 32-bit SteamCMD support first.'
  local name=GeneralsXZH checksum=0d7212559c239c29db4117096ebcb7bdc8fdb8c4825c931cc3d4093a3e2f85c2
  if [[ "$PROFILE" == base ]]; then
    name=GeneralsX
    checksum=73ed661306dbb5faac90b1cdcf6ecae47245ac69a1070d0f9e04e05345085451
  fi
  download "$name-1.0.2.flatpak" "https://github.com/fbraz3/GeneralsX/releases/download/1.0.2/Linux-$name.flatpak" "$checksum"
  "$FLATPAK" remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  "$FLATPAK" install --user --noninteractive --reinstall -y "$CACHE/$name-1.0.2.flatpak"
  mkdir -p "$ROOT/linux-engines"
  commit="$("$FLATPAK" info --user --show-commit "$(app_id "$ENGINE")")"
  [[ -n "$commit" ]] || fail 'Could not verify the installed Flatpak commit.'
  printf '1.0.2\n%s\n' "$commit" > "$ROOT/linux-engines/$(app_id "$ENGINE").commit"
  engine_ready "$ENGINE" || fail 'Flatpak engine installation did not complete.'
  echo 'Native Linux engine installed.'
}
steam_install() {
  dependencies_ready || fail 'Linux dependencies are missing. Install 32-bit SteamCMD support first.'
  download steamcmd-linux-bootstrap.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    cebf0046bfd08cf45da6bc094ae47aa39ebf4155e5ede41373b579b8f1071e7c
  mkdir -p "$WORK/steamcmd"
  tar -xzf "$CACHE/steamcmd-linux-bootstrap.tar.gz" -C "$WORK/steamcmd"
  [[ -x "$WORK/steamcmd/steamcmd.sh" ]] || fail 'SteamCMD bootstrap is incomplete.'
  if [[ ! -d "$ROOT/steamcmd" ]]; then mv "$WORK/steamcmd" "$ROOT/steamcmd"; fi
  echo 'Linux SteamCMD installed; Valve updates it on first run.'
}
launch_engine() {
  local game_path="$CNC_GENERALS_ZH_PATH"
  [[ "$PROFILE" != base ]] || game_path="$CNC_GENERALS_PATH"
  mkdir -p "$ROOT/user-data"
  exec "$FLATPAK" run --user --filesystem="$ROOT" \
    --env="CNC_GENERALS_ZH_PATH=$CNC_GENERALS_ZH_PATH" \
    --env="CNC_GENERALS_PATH=$CNC_GENERALS_PATH" \
    --env="CNC_GENERALS_INSTALLPATH=$game_path" \
    --env="XDG_DATA_HOME=$ROOT/user-data" --env=DXVK_HUD=0 \
    "$(app_id "$ENGINE")" "$@"
}
install_linux_tools() {
  [[ -f /etc/os-release ]] || fail 'Cannot identify this Linux distribution.'
  source /etc/os-release
  case "${ID:-} ${ID_LIKE:-}" in
    *ubuntu*|*debian*|*linuxmint*|*pop*)
      printf 'Install Flatpak, download tools and 32-bit support for Valve SteamCMD.\n'
      sudo apt-get update
      sudo apt-get install -y flatpak curl file zip unzip xz-utils lib32gcc-s1 lib32stdc++6
      if compatibility_profile "$PROFILE"; then sudo apt-get install -y wine wine64 libwine libgl1 libvulkan1; fi
      ;;
    *) fail 'Automatic dependency setup supports Ubuntu/Debian-based desktops. Install Flatpak, curl, file, zip and 32-bit glibc/libstdc++ through your distribution, then retry.' ;;
  esac
  dependencies_ready || fail 'Linux dependencies are still incomplete.'
  echo 'Linux dependencies installed. Return to the launcher.'
}
