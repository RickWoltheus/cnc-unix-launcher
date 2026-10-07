#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
RESOURCES="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL="$(uname -s)"
case "$KERNEL" in
  Darwin) PLATFORM=macos; DEFAULT_ROOT="$HOME/Library/Application Support/GeneralsX Launcher" ;;
  Linux) PLATFORM=linux; DEFAULT_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/generalsx-launcher" ;;
  *) echo 'Unsupported operating system.' >&2; exit 1 ;;
esac
ROOT="${GX_INSTALL_ROOT:-$DEFAULT_ROOT}"
STEAM_COMMAND="$ROOT/steamcmd/MacOS/steamcmd.sh"
ACTION="${1:-status}"
PROFILE="${2:-vanilla}"
case "$ACTION" in rotr|shockwave|chaos|contra|teod) PROFILE="$ACTION"; ACTION=mod ;; esac
ENGINE="$ROOT/engine/GeneralsXZH.app"
GAME="$ROOT/GeneralsZH"
MOD="$ROOT/RiseOfTheReds"
CACHE="$ROOT/downloads"

fail() { printf '%s\n' "$*" >&2; exit 1; }
select_mod() {
  local row directory
  row="$(awk -F '\t' -v id="$1" '$1==id {print}' "$RESOURCES/manifests/mods.tsv")"
  [[ -n "$row" ]] || fail "Unknown mod: $1"
  IFS=$'\t' read -r MOD_ID MOD_TITLE MOD_VERSION directory MOD_URL MOD_SUPPORT <<< "$row"
  MOD="$ROOT/$directory"
  MOD_MANIFEST="$RESOURCES/manifests/$MOD_ID.tsv"
}
if [[ "$PROFILE" == base ]]; then ENGINE="$ROOT/engine-base/GeneralsX.app"; GAME="$ROOT/Generals"; fi
verify() {
  [[ -f "$1" ]] || return 1
  local digest
  if command -v shasum >/dev/null; then digest="$(shasum -a 256 "$1" | awk '{print $1}')"
  else digest="$(sha256sum "$1" | awk '{print $1}')"; fi
  [[ "$digest" == "$2" ]]
}
find_game_file() { find "$1" -maxdepth 1 -type f -iname "$2" -print | head -n 1; }
steam_manifest_ready() {
  local manifest="$1/steamapps/appmanifest_$2.acf"
  [[ -f "$manifest" ]] && [[ "$(awk '$1=="\"StateFlags\"" {gsub(/"/,"",$2); print $2}' "$manifest")" == 4 ]]
}
source "$RESOURCES/scripts/platform-$PLATFORM.sh"
source "$RESOURCES/scripts/classic.sh"
source "$RESOURCES/scripts/native-mods.sh"
source "$RESOURCES/scripts/settings.sh"
source "$RESOURCES/scripts/online.sh"
source "$RESOURCES/scripts/compatibility.sh"
if compatibility_profile "$PROFILE"; then GAME="$(compatibility_directory "$PROFILE")"; fi
if classic_profile "$PROFILE"; then
  GAME="$ROOT/$(classic_directory "$PROFILE")"; ENGINE="$(classic_engine_path "$PROFILE")"
fi
if native_profile "$PROFILE"; then
  native_select "$PROFILE"; ENGINE="$NATIVE_ENGINE"
  if [[ "$NATIVE_SOURCE" == remastered ]]; then GAME="$ROOT/Remastered"; else GAME="$ROOT/RedAlert"; fi
fi
installed_name() {
  if [[ "$1" == *.gib ]]; then printf '%s.big' "${1%.gib}"; else printf '%s' "$1"; fi
}
download() {
  local name="$1" url="$2" checksum="$3" target="$CACHE/$1"
  if verify "$target" "$checksum"; then printf 'Using verified %s\n' "$name"; return; fi
  printf 'Downloading %s\n' "$name"
  mkdir -p "$(dirname "$target")"
  curl -fL --retry 3 --connect-timeout 20 --max-time 1800 -o "$target.part" "$url"
  verify "$target.part" "$checksum" || fail "Checksum mismatch for $name. Nothing was installed."
  mv "$target.part" "$target"
}
assets_ready() {
  local folder="$1" game="${2:-vanilla}" file appid=2732960
  if compatibility_profile "$game"; then compatibility_assets_ready "$game"; return; fi
  if native_profile "$game"; then native_ready "$game"; return; fi
  if classic_profile "$game"; then classic_raw_ready "$folder" "$game" && classic_content_ready "$game"; return; fi
  local archives=(INIZH.big TexturesZH.big W3DZH.big MapsZH.big)
  if [[ "$game" == base ]]; then appid=2229870; archives=(INI.big Textures.big W3D.big Maps.big); fi
  steam_manifest_ready "$folder" "$appid" || return 1
  for file in "${archives[@]}"; do
    archive="$folder/$file"
    if [[ ! -f "$archive" ]]; then archive="$(find_game_file "$folder" "$file")"; fi
    [[ -s "$archive" ]] || return 1
    [[ "$(head -c 4 "$archive")" == BIGF || "$(head -c 4 "$archive")" == BIG4 ]] || return 1
  done
  [[ "$game" == base || ( -s "$folder/ZH_Generals/Textures.big" && -s "$folder/ZH_Generals/W3D.big" ) ]]
}
mod_ready() {
  local name checksum url
  [[ -f "$MOD/.$MOD_ID-complete" ]] || return 1
  while IFS=$'\t' read -r name checksum url; do
    [[ -n "$name" ]] || continue
    verify "$MOD/$(installed_name "$name")" "$checksum" || return 1
  done < "$MOD_MANIFEST"
}

if [[ "$ACTION" == status ]]; then
  install=idle
  if [[ -f "$ROOT/.install-lock/pid" ]] && kill -0 "$(cat "$ROOT/.install-lock/pid")" 2>/dev/null; then install=busy; fi
  echo "install=$install"
  compatibility_dependencies_ready && echo "wine_dependencies=ready" || echo "wine_dependencies=missing"
  platform_supported && echo 'platform=ready' || echo 'platform=unsupported'
  dependencies_ready && echo 'dependencies=ready' || echo 'dependencies=missing'
  engine_ready "$ENGINE" && echo 'engine=ready' || echo 'engine=missing'
  steam_ready && echo 'steam=ready' || echo 'steam=missing'
  assets_ready "$GAME" && echo 'assets=ready' || echo 'assets=missing'
  engine_ready "$ROOT/engine-base/GeneralsX.app" && echo 'base_engine=ready' || echo 'base_engine=missing'
  assets_ready "$ROOT/Generals" base && echo 'base_assets=ready' || echo 'base_assets=missing'
  for game in cnc ra; do
    classic_engine_ready "$game" && echo "${game}_engine=ready" || echo "${game}_engine=missing"
    assets_ready "$ROOT/$(classic_directory "$game")" "$game" && echo "${game}_assets=ready" || echo "${game}_assets=missing"
  done
  while IFS=$'\t' read -r id rest; do
    native_engine_ready "$id" && echo "native_engine_$id=ready" || echo "native_engine_$id=missing"
    native_ready "$id" && echo "$id=ready" || echo "$id=missing"
  done < "$RESOURCES/manifests/native-mods.tsv"
  for game in ra2 yuri ts; do
    compatibility_engine_ready && echo "${game}_engine=ready" || echo "${game}_engine=missing"
    compatibility_assets_ready "$game" && echo "${game}_assets=ready" || echo "${game}_assets=missing"
  done
  for game in vanilla base cnc ra combined-arms tdhd ra2 yuri ts; do
    state=idle
    if [[ -f "$ROOT/steam-$game.status" ]]; then state="$(cat "$ROOT/steam-$game.status")"; fi
    case "$state" in waiting|installing-rosetta|waiting-password|awaiting-guard|updating-steam|downloading|validating|complete|incomplete|wrong-password|wrong-account|wrong-code|expired-code|rate-limited|no-license|network-error) ;; *) state=idle ;; esac
    case "$state" in waiting|installing-rosetta|waiting-password|awaiting-guard|updating-steam|downloading|validating)
      if [[ "$install" != busy || "$(cat "$ROOT/.install-lock/kind" 2>/dev/null || true)" != "steam-login:$game" ]]; then state=incomplete; fi ;;
    esac
    echo "steam_download_$game=$state"
    if [[ "$install" == busy && "$(cat "$ROOT/.install-lock/kind" 2>/dev/null || true)" == "steam-login:$game" ]]; then echo "steam_session_$game=active"; fi
  done
  while IFS=$'\t' read -r id rest; do
    select_mod "$id"
    [[ -f "$MOD/.$id-complete" ]] && assets_ready "$MOD" && echo "$id=ready" || echo "$id=missing"
  done < "$RESOURCES/manifests/mods.tsv"
  exit 0
fi

if [[ "$ACTION" == launch ]]; then
  [[ ! -d "$ROOT/.install-lock" ]] || fail 'An installation or Steam download is still running. Wait for it to finish before playing.'
  if compatibility_profile "$PROFILE"; then compatibility_launch "$@"; fi
  if native_profile "$PROFILE"; then
    if compatibility_running || pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1; then fail 'Quit the running game before switching profiles.'; fi
    native_launch "$@"
  fi
  if classic_profile "$PROFILE"; then
    if compatibility_running || pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1; then fail 'A game is already running. Quit it before switching games.'; fi
    classic_launch "$@"
  fi
  [[ "$PROFILE" == vanilla || "$PROFILE" == base ]] || select_mod "$PROFILE"
  if compatibility_running || pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1; then fail 'A game is already running. Quit it before switching games.'; fi
  if ! engine_ready "$ENGINE"; then
    repair_profile=vanilla
    [[ "$PROFILE" != base ]] || repair_profile=base
    echo 'Repairing missing engine runtime files before launch.'
    /bin/bash "$0" engine "$repair_profile"
    engine_ready "$ENGINE" || fail 'The engine runtime is incomplete after repair.'
  fi
  assets_ready "$GAME" "$PROFILE" || fail 'Download and verify your Steam assets first.'
  export CNC_GENERALS_ZH_PATH="$GAME"
  if [[ "$PROFILE" != vanilla && "$PROFILE" != base ]]; then
    mod_ready || fail "$MOD_TITLE is incomplete or damaged. Install it again."
    export CNC_GENERALS_ZH_PATH="$MOD"
  fi
  export CNC_GENERALS_PATH="$CNC_GENERALS_ZH_PATH/ZH_Generals"
  if [[ "$PROFILE" == base ]]; then export CNC_GENERALS_PATH="$GAME"; fi
  export CNC_GENERALS_INSTALLPATH="$CNC_GENERALS_PATH"
  export DXVK_HUD=0
  mkdir -p "$ROOT/logs"
  shift 2
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then
    exec /bin/bash "$GX_LAUNCH_WRAPPER" -noshellmap "$@" > "$ROOT/logs/$PROFILE.log" 2>&1
  else
    launch_engine -noshellmap "$@" > "$ROOT/logs/$PROFILE.log" 2>&1
  fi
fi

platform_supported || fail "$(platform_requirement_message)"
if compatibility_running || pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1; then fail 'Quit the game before installing, downloading assets, or changing settings.'; fi
mkdir -p "$ROOT" "$CACHE"
LOCK="$ROOT/.install-lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  [[ -f "$LOCK/pid" ]] || fail 'An installation lock is being created or was interrupted. Retry; if it persists, remove .install-lock from the installation folder after confirming no installer is running.'
  if kill -0 "$(cat "$LOCK/pid")" 2>/dev/null; then
    fail 'Another installation is running. Wait for it to finish.'
  fi
  rm -rf "$LOCK"
  mkdir "$LOCK" || fail 'Could not acquire installation lock.'
fi
printf '%s\n' "$$" > "$LOCK/pid"
printf '%s:%s\n' "$ACTION" "$PROFILE" > "$LOCK/kind"
WORK="$(mktemp -d "$ROOT/.staging.XXXXXX")"
cleanup() {
  if [[ -n "${mounted_classic:-}" ]]; then hdiutil detach "$mounted_classic" >/dev/null 2>&1 || true; fi
  if [[ "$ACTION" == steam-login && "${steam_finished:-0}" != 1 ]]; then
    current="$(cat "$ROOT/steam-$PROFILE.status" 2>/dev/null || true)"
    case "$current" in wrong-password|wrong-account|wrong-code|expired-code|rate-limited|no-license|network-error) ;; *) printf 'incomplete\n' > "$ROOT/steam-$PROFILE.status" ;; esac
  fi
  rm -rf "$WORK" "$LOCK"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

case "$ACTION" in
  graphics)
    if compatibility_profile "$PROFILE"; then echo "Display mode is applied through cnc-ddraw at launch; graphics settings stay in the game."; exit 0; fi
    if classic_profile "$PROFILE" || native_profile "$PROFILE"; then echo 'OpenRA uses its own graphics settings. Display mode is applied at launch.'; exit 0; fi
    if pgrep -x GeneralsXZH >/dev/null 2>&1; then fail 'Quit Zero Hour before changing graphics settings.'; fi
    leaf=GeneralsZH
    [[ "$PROFILE" != base ]] || leaf=Generals
    OPTIONS_DIR="${GX_PREFERENCES_DIR:-$(options_directory "$leaf")}"
    mkdir -p "$OPTIONS_DIR"
    OPTIONS="$OPTIONS_DIR/Options.ini"
    BACKUP="$OPTIONS_DIR/Options.before-launcher.ini"
    if [[ -f "$OPTIONS" && ! -f "$BACKUP" ]]; then cp "$OPTIONS" "$BACKUP"; fi
    touch "$WORK/empty-options"
    EXISTING="$OPTIONS"
    [[ -f "$EXISTING" ]] || EXISTING="$WORK/empty-options"
    preset=max-options.ini
    [[ "${3:-maximum}" != balanced ]] || preset=balanced-options.ini
    awk -F= '
      NR==FNR { key=$1; gsub(/^[ \t]+|[ \t]+$/, "", key); updated[key]=$0; next }
      { key=$1; gsub(/^[ \t]+|[ \t]+$/, "", key); if (!(key in updated)) print }
      END { for (key in updated) print updated[key] }
    ' "$RESOURCES/resources/$preset" "$EXISTING" > "$WORK/Options.ini"
    mv "$WORK/Options.ini" "$OPTIONS"
    echo 'Graphics preset saved; previous options backed up.'
    ;;
  engine)
    if compatibility_profile "$PROFILE"; then compatibility_install
    elif classic_profile "$PROFILE"; then classic_install; else engine_install; fi
    ;;
  steam)
    steam_install
    ;;
  steam-login)
    [[ "$PROFILE" == vanilla || "$PROFILE" == base || "$PROFILE" == cnc || "$PROFILE" == ra ]] || native_profile "$PROFILE" || compatibility_profile "$PROFILE" || fail 'Choose a game for Steam downloads.'
    appid=2732960; title='Zero Hour'
    if compatibility_profile "$PROFILE"; then
      appid="$(compatibility_metadata "$PROFILE" 5)"; title="$(compatibility_metadata "$PROFILE" 2)"
    fi
    if [[ "$PROFILE" == base ]]; then appid=2229870; title=Generals; fi
    if classic_profile "$PROFILE"; then
      appid="$(awk -F '\t' -v id="$PROFILE" '$1==id {print $5}' "$RESOURCES/manifests/games.tsv")"
      title="$(classic_app_title "$PROFILE")"
    fi
    if native_profile "$PROFILE"; then
      native_select "$PROFILE"; title="$NATIVE_TITLE"
      if [[ "$NATIVE_SOURCE" == remastered ]]; then appid=1213210; else appid=2229840; fi
    fi
    printf 'waiting\n' > "$ROOT/steam-$PROFILE.status"
    steam_ready || fail 'Prepare the Steam downloader and platform dependencies first.'
    prepare_steam_login
    printf 'waiting\n' > "$ROOT/steam-$PROFILE.status"
    if [[ "$PROFILE" == tdhd ]]; then
      printf 'Own Remastered Collection on this Steam account; Ultimate Collection does not supply HD art. Allow up to 40 GB for its download.\n'
    else printf 'Own %s and its required source games on this Steam account (Ultimate Collection).\n' "$title"; fi
    printf 'Enter your password and Steam Guard only in this Terminal.\n'
    printf 'Use your Steam account login name, not your profile display name.\n'
    read -r -p 'Steam account username: ' steam_account
    [[ -n "$steam_account" && "$steam_account" != -* && "$steam_account" != +* ]] || fail 'Enter a Steam account username.'
    mkdir -p "$GAME"
    printf 'updating-steam\n' > "$ROOT/steam-$PROFILE.status"
    mkfifo "$WORK/steam-status.pipe"
    /bin/bash "$RESOURCES/scripts/steam-status.sh" "$ROOT/steam-$PROFILE.status" < "$WORK/steam-status.pipe" &
    status_reader=$!
    steam_result=0
    steam_arguments=(+@sSteamCmdForcePlatformType windows +force_install_dir "$GAME" +login "$steam_account" +app_update "$appid" validate)
    if [[ "$PROFILE" == ra || "$PROFILE" == combined-arms ]]; then
      echo 'OpenRA Red Alert also needs the C&C desert tileset. Steam will download your owned C&C copy.'
      steam_arguments+=(+force_install_dir "$ROOT/TiberianDawn" +app_update 2229830 validate)
    fi
    "$STEAM_COMMAND" "${steam_arguments[@]}" +quit \
      2>&1 | tee "$WORK/steam-status.pipe" || steam_result=$?
    wait "$status_reader" || true
    [[ "$steam_result" == 0 ]] || fail 'Steam sign-in stopped. Check the launcher for the next step.'
    reported_state="$(cat "$ROOT/steam-$PROFILE.status")"
    case "$reported_state" in
      wrong-password|wrong-account|wrong-code|expired-code|rate-limited|no-license|network-error)
        fail 'Steam reported a sign-in or ownership error. Check the Steam guide before retrying.' ;;
    esac
    printf 'validating\n' > "$ROOT/steam-$PROFILE.status"
    if native_profile "$PROFILE"; then native_finish
    elif classic_profile "$PROFILE"; then classic_import; fi
    assets_ready "$GAME" "$PROFILE" || fail "Steam files are incomplete. No subscription means this account lacks the $title license. Retry after checking ownership."
    steam_finished=1
    printf 'complete\n' > "$ROOT/steam-$PROFILE.status"
    echo "$title assets verified. Return to the launcher and click Refresh."
    ;;
  online-prepare)
    prepare_online "$@"
    ;;
  native-mod)
    native_profile "$PROFILE" || fail 'Choose a supported native mod.'
    native_prepare
    native_finish
    ;;
  import-classic)
    classic_profile "$PROFILE" || fail 'Choose C&C or Red Alert for this import.'
    classic_import
    ;;
  mod)
    select_mod "$PROFILE"
    assets_ready "$GAME" || fail 'Download your Zero Hour Steam assets before installing mods.'
    if mod_ready; then echo "$MOD_TITLE already installed and verified."; exit 0; fi
    while IFS=$'\t' read -r name checksum url; do
      [[ -n "$name" ]] || continue
      [[ -n "$url" ]] || url="$MOD_URL/$name"
      download "$MOD_ID/$name" "$url" "$checksum"
    done < "$MOD_MANIFEST"
    copy_tree "$GAME" "$WORK/rotr"
    for name in SkirmishScripts.scb MultiplayerScripts.scb Scripts.ini; do
      stock="$WORK/rotr/Data/Scripts/$name"
      [[ ! -f "$stock" ]] || mv "$stock" "$stock.stock-disabled"
    done
    while IFS=$'\t' read -r name checksum url; do
      [[ -n "$name" ]] || continue
      cached="$CACHE/$MOD_ID/$name"
      if [[ "$name" == *.gib || "$name" == *.big ]]; then
        [[ "$(head -c 4 "$cached")" == BIGF || "$(head -c 4 "$cached")" == BIG4 ]] || fail "Invalid BIG archive: $name"
      fi
      destination="$WORK/rotr/$(installed_name "$name")"
      mkdir -p "$(dirname "$destination")"
      copy_file "$cached" "$destination"
    done < "$MOD_MANIFEST"
    printf '%s\n' "$MOD_VERSION" > "$WORK/rotr/.$MOD_ID-complete"
    mkdir -p "$(dirname "$MOD")"
    if [[ -d "$MOD" ]]; then mv "$MOD" "$WORK/previous-rotr"; fi
    if ! mv "$WORK/rotr" "$MOD"; then
      [[ ! -d "$WORK/previous-rotr" ]] || mv "$WORK/previous-rotr" "$MOD"
      fail 'Could not install ROTR; previous installation restored.'
    fi
    echo "$MOD_TITLE installed. Gameplay compatibility is experimental."
    ;;
  linux-tools)
    [[ "$PLATFORM" == linux ]] || fail 'Linux dependencies are only available on Linux.'
    install_linux_tools
    ;;
  *) fail "Unknown action: $ACTION" ;;
esac
