#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
RESOURCES="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${GX_INSTALL_ROOT:-$HOME/Library/Application Support/GeneralsX Launcher}"
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
verify() { [[ -f "$1" ]] && [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]]; }
engine_ready() {
  local app="$1" binary library
  binary="$(basename "$app" .app)"
  [[ -x "$app/Contents/MacOS/run.sh" && -s "$app/Contents/Resources/bin/$binary" ]] || return 1
  for library in libvulkan.1.dylib libMoltenVK.dylib libdxvk_d3d8.0.dylib libdxvk_d3d9.0.dylib libSDL3.0.dylib; do
    [[ -s "$app/Contents/Resources/lib/$library" ]] || return 1
  done
}
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
  local archives=(INIZH.big TexturesZH.big W3DZH.big MapsZH.big)
  if [[ "$game" == base ]]; then appid=2229870; archives=(INI.big Textures.big W3D.big Maps.big); fi
  [[ -f "$folder/steamapps/appmanifest_$appid.acf" ]] || return 1
  [[ "$(awk '$1 == "\"StateFlags\"" { gsub(/"/, "", $2); print $2 }' "$folder/steamapps/appmanifest_$appid.acf")" == 4 ]] || return 1
  for file in "${archives[@]}"; do
    [[ -s "$folder/$file" ]] || return 1
    [[ "$(head -c 4 "$folder/$file")" == BIGF || "$(head -c 4 "$folder/$file")" == BIG4 ]] || return 1
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
  engine_ready "$ENGINE" && echo 'engine=ready' || echo 'engine=missing'
  [[ -x "$ROOT/steamcmd/MacOS/steamcmd.sh" ]] && echo 'steam=ready' || echo 'steam=missing'
  assets_ready "$GAME" && echo 'assets=ready' || echo 'assets=missing'
  engine_ready "$ROOT/engine-base/GeneralsX.app" && echo 'base_engine=ready' || echo 'base_engine=missing'
  assets_ready "$ROOT/Generals" base && echo 'base_assets=ready' || echo 'base_assets=missing'
  for game in vanilla base; do
    state=idle
    if [[ -f "$ROOT/steam-$game.status" ]]; then state="$(cat "$ROOT/steam-$game.status")"; fi
    case "$state" in waiting|installing-rosetta|waiting-password|awaiting-guard|updating-steam|downloading|complete|incomplete|wrong-password|wrong-account|wrong-code|expired-code|rate-limited|no-license|network-error) ;; *) state=idle ;; esac
    case "$state" in waiting|installing-rosetta|waiting-password|awaiting-guard|updating-steam|downloading)
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
  [[ "$PROFILE" == vanilla || "$PROFILE" == base ]] || select_mod "$PROFILE"
  if pgrep -x 'GeneralsX(ZH)?' >/dev/null 2>&1; then fail 'A game is already running. Quit it before switching games.'; fi
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
  launch_wrapper="${GX_LAUNCH_WRAPPER:-$ENGINE/Contents/MacOS/run.sh}"
  exec /bin/bash "$launch_wrapper" -noshellmap "$@" > "$ROOT/logs/$PROFILE.log" 2>&1
fi

[[ "$(uname -m)" == arm64 ]] || fail 'This launcher requires an Apple Silicon Mac and a native Terminal.'
OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$OS_MAJOR" -ge 15 ]] || fail 'GeneralsX 1.0.2 requires macOS 15 or later.'
if pgrep -x 'GeneralsX(ZH)?' >/dev/null 2>&1; then fail 'Quit the game before installing, downloading assets, or changing settings.'; fi
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
    if pgrep -x GeneralsXZH >/dev/null 2>&1; then fail 'Quit Zero Hour before changing graphics settings.'; fi
    leaf=GeneralsZH
    [[ "$PROFILE" != base ]] || leaf=Generals
    OPTIONS_DIR="${GX_PREFERENCES_DIR:-$HOME/Library/Application Support/GeneralsX/$leaf}"
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
    ;;
  steam)
    download steamcmd-bootstrap.tar.gz \
      https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz \
      8ecc17c8988e5acadcc78e631c48490f76150f2dfaa6cf8d7b4b67b097bd753b
    mkdir -p "$WORK/steamcmd/MacOS"
    tar -xzf "$CACHE/steamcmd-bootstrap.tar.gz" -C "$WORK/steamcmd/MacOS"
    [[ -x "$WORK/steamcmd/MacOS/steamcmd.sh" ]] || fail 'SteamCMD bootstrap is incomplete.'
    if [[ ! -d "$ROOT/steamcmd" ]]; then mv "$WORK/steamcmd" "$ROOT/steamcmd"; fi
    echo 'SteamCMD installed. Valve updates it on first run.'
    ;;
  steam-login)
    [[ "$PROFILE" == vanilla || "$PROFILE" == base ]] || fail 'Choose Generals or Zero Hour for Steam downloads.'
    appid=2732960; title='Zero Hour'
    if [[ "$PROFILE" == base ]]; then appid=2229870; title=Generals; fi
    printf 'waiting\n' > "$ROOT/steam-$PROFILE.status"
    [[ -x "$ROOT/steamcmd/MacOS/steamcmd.sh" ]] || fail 'Install SteamCMD first.'
    if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
      printf 'installing-rosetta\n' > "$ROOT/steam-$PROFILE.status"
      printf 'SteamCMD needs Apple Rosetta. Review and accept Apple’s agreement below.\n'
      /usr/sbin/softwareupdate --install-rosetta || fail 'Rosetta installation did not complete.'
    fi
    printf 'waiting\n' > "$ROOT/steam-$PROFILE.status"
    printf 'Own %s on this Steam account (The Ultimate Collection, not Remastered).\n' "$title"
    printf 'Enter your password and Steam Guard only in this Terminal.\n'
    printf 'Use your Steam account login name, not your profile display name.\n'
    read -r -p 'Steam account username: ' steam_account
    [[ -n "$steam_account" && "$steam_account" != -* && "$steam_account" != +* ]] || fail 'Enter a Steam account username.'
    mkdir -p "$GAME"
    printf 'downloading\n' > "$ROOT/steam-$PROFILE.status"
    mkfifo "$WORK/steam-status.pipe"
    /bin/bash "$RESOURCES/scripts/steam-status.sh" "$ROOT/steam-$PROFILE.status" < "$WORK/steam-status.pipe" &
    status_reader=$!
    steam_result=0
    "$ROOT/steamcmd/MacOS/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$GAME" +login "$steam_account" +app_update "$appid" validate +quit \
      2>&1 | tee "$WORK/steam-status.pipe" || steam_result=$?
    wait "$status_reader" || true
    [[ "$steam_result" == 0 ]] || fail 'Steam sign-in stopped. Check the launcher for the next step.'
    assets_ready "$GAME" "$PROFILE" || fail "Steam files are incomplete. No subscription means this account lacks the $title license. Retry after checking ownership."
    steam_finished=1
    printf 'complete\n' > "$ROOT/steam-$PROFILE.status"
    echo "$title assets verified. Return to the launcher and click Refresh."
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
    cp -cR "$GAME" "$WORK/rotr" || { rm -rf "$WORK/rotr"; ditto "$GAME" "$WORK/rotr"; }
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
      cp -c "$cached" "$destination" || cp "$cached" "$destination"
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
  *) fail "Unknown action: $ACTION" ;;
esac
