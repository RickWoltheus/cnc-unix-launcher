#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
RESOURCES="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${GX_INSTALL_ROOT:-$HOME/Library/Application Support/GeneralsX Launcher}"
ACTION="${1:-status}"
ENGINE="$ROOT/engine/GeneralsXZH.app"
GAME="$ROOT/GeneralsZH"
MOD="$ROOT/RiseOfTheReds"
CACHE="$ROOT/downloads"

fail() { printf '%s\n' "$*" >&2; exit 1; }
verify() { [[ -f "$1" ]] && [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]]; }
installed_name() {
  if [[ "$1" == *.gib ]]; then printf '%s.big' "${1%.gib}"; else printf '%s' "$1"; fi
}
download() {
  local name="$1" url="$2" checksum="$3" target="$CACHE/$1"
  if verify "$target" "$checksum"; then printf 'Using verified %s\n' "$name"; return; fi
  printf 'Downloading %s\n' "$name"
  curl -fL --retry 3 --connect-timeout 20 --max-time 1800 -o "$target.part" "$url"
  verify "$target.part" "$checksum" || fail "Checksum mismatch for $name. Nothing was installed."
  mv "$target.part" "$target"
}
assets_ready() {
  local folder="$1" file
  [[ -f "$folder/steamapps/appmanifest_2732960.acf" ]] || return 1
  [[ "$(awk '$1 == "\"StateFlags\"" { gsub(/"/, "", $2); print $2 }' "$folder/steamapps/appmanifest_2732960.acf")" == 4 ]] || return 1
  for file in INIZH.big TexturesZH.big W3DZH.big MapsZH.big; do
    [[ -s "$folder/$file" ]] || return 1
    [[ "$(head -c 4 "$folder/$file")" == BIGF || "$(head -c 4 "$folder/$file")" == BIG4 ]] || return 1
  done
  [[ -s "$folder/ZH_Generals/Textures.big" && -s "$folder/ZH_Generals/W3D.big" ]]
}
mod_ready() {
  local name checksum
  [[ -f "$MOD/.rotr-complete" ]] || return 1
  while IFS=$'\t' read -r name checksum; do
    [[ -n "$name" ]] || continue
    verify "$MOD/$(installed_name "$name")" "$checksum" || return 1
  done < "$RESOURCES/manifests/rotr.tsv"
}

if [[ "$ACTION" == status ]]; then
  [[ -x "$ENGINE/Contents/MacOS/run.sh" ]] && echo 'engine=ready' || echo 'engine=missing'
  [[ -x "$ROOT/steamcmd/MacOS/steamcmd.sh" ]] && echo 'steam=ready' || echo 'steam=missing'
  assets_ready "$GAME" && echo 'assets=ready' || echo 'assets=missing'
  [[ -f "$MOD/.rotr-complete" ]] && assets_ready "$MOD" && echo 'rotr=ready' || echo 'rotr=missing'
  exit 0
fi

if [[ "$ACTION" == launch ]]; then
  PROFILE="${2:-vanilla}"
  [[ "$PROFILE" == vanilla || "$PROFILE" == rotr ]] || fail 'Unknown game profile.'
  [[ -x "$ENGINE/Contents/MacOS/run.sh" ]] || fail 'Install the engine first.'
  if pgrep -x GeneralsXZH >/dev/null 2>&1; then fail 'Zero Hour is already running. Quit it before switching games.'; fi
  assets_ready "$GAME" || fail 'Download and verify your Steam assets first.'
  export CNC_GENERALS_ZH_PATH="$GAME"
  if [[ "$PROFILE" == rotr ]]; then
    mod_ready || fail 'ROTR is incomplete or damaged. Install ROTR again.'
    export CNC_GENERALS_ZH_PATH="$MOD"
  fi
  export CNC_GENERALS_PATH="$CNC_GENERALS_ZH_PATH/ZH_Generals"
  export CNC_GENERALS_INSTALLPATH="$CNC_GENERALS_PATH"
  mkdir -p "$ROOT/logs"
  shift 2
  exec "$ENGINE/Contents/MacOS/run.sh" -noshellmap "$@" > "$ROOT/logs/$PROFILE.log" 2>&1
fi

[[ "$(uname -m)" == arm64 ]] || fail 'This launcher requires an Apple Silicon Mac and a native Terminal.'
OS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[[ "$OS_MAJOR" -ge 15 ]] || fail 'GeneralsX 1.0.2 requires macOS 15 or later.'
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
WORK="$(mktemp -d "$ROOT/.staging.XXXXXX")"
cleanup() { rm -rf "$WORK" "$LOCK"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

case "$ACTION" in
  graphics)
    if pgrep -x GeneralsXZH >/dev/null 2>&1; then fail 'Quit Zero Hour before changing graphics settings.'; fi
    OPTIONS_DIR="${GX_PREFERENCES_DIR:-$HOME/Library/Application Support/GeneralsX/GeneralsZH}"
    mkdir -p "$OPTIONS_DIR"
    OPTIONS="$OPTIONS_DIR/Options.ini"
    if [[ -f "$OPTIONS" && ! -f "$OPTIONS.before-launcher.ini" ]]; then cp "$OPTIONS" "$OPTIONS.before-launcher.ini"; fi
    touch "$WORK/empty-options"
    EXISTING="$OPTIONS"
    [[ -f "$EXISTING" ]] || EXISTING="$WORK/empty-options"
    awk -F= '
      NR==FNR { key=$1; gsub(/^[ \t]+|[ \t]+$/, "", key); updated[key]=$0; next }
      { key=$1; gsub(/^[ \t]+|[ \t]+$/, "", key); if (!(key in updated)) print }
      END { for (key in updated) print updated[key] }
    ' "$RESOURCES/resources/max-options.ini" "$EXISTING" > "$WORK/Options.ini"
    mv "$WORK/Options.ini" "$OPTIONS"
    echo 'Maximum graphics saved; previous options backed up.'
    ;;
  engine)
    download engine-1.0.2.zip \
      https://github.com/fbraz3/GeneralsX/releases/download/1.0.2/macOS-GeneralsXZH.zip \
      92930b71c232eb289cf743eb8cdc4081020a870dfdaa2adad553bec2798ac568
    ditto -x -k "$CACHE/engine-1.0.2.zip" "$WORK/engine"
    [[ -x "$WORK/engine/GeneralsXZH.app/Contents/MacOS/run.sh" ]] || fail 'Engine archive is missing its launcher.'
    file "$WORK/engine/GeneralsXZH.app/Contents/Resources/bin/GeneralsXZH" | grep -q arm64 || fail 'Engine is not ARM64.'
    xattr -dr com.apple.quarantine "$WORK/engine/GeneralsXZH.app" 2>/dev/null || true
    if [[ -d "$ROOT/engine" ]]; then mv "$ROOT/engine" "$WORK/previous-engine"; fi
    if ! mv "$WORK/engine" "$ROOT/engine"; then
      [[ ! -d "$WORK/previous-engine" ]] || mv "$WORK/previous-engine" "$ROOT/engine"
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
    [[ -x "$ROOT/steamcmd/MacOS/steamcmd.sh" ]] || fail 'Install SteamCMD first.'
    if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
      printf 'SteamCMD needs Apple Rosetta. Review and accept Apple’s agreement below.\n'
      /usr/sbin/softwareupdate --install-rosetta || fail 'Rosetta installation did not complete.'
    fi
    printf 'Own Zero Hour on this Steam account (The Ultimate Collection, not Remastered).\n'
    printf 'Enter your password and Steam Guard only in this Terminal.\n'
    read -r -p 'Steam account username: ' steam_account
    [[ -n "$steam_account" && "$steam_account" != -* && "$steam_account" != +* ]] || fail 'Enter a Steam account username.'
    mkdir -p "$GAME"
    "$ROOT/steamcmd/MacOS/steamcmd.sh" +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$GAME" +login "$steam_account" +app_update 2732960 validate +quit
    assets_ready "$GAME" || fail 'Steam files are incomplete. No subscription means this account lacks the Zero Hour license. Retry after checking ownership.'
    echo 'Zero Hour assets verified. Return to the launcher and click Refresh.'
    ;;
  rotr)
    assets_ready "$GAME" || fail 'Download your Steam assets before installing ROTR.'
    if mod_ready; then echo 'ROTR already installed and verified.'; exit 0; fi
    while IFS=$'\t' read -r name checksum; do
      [[ -n "$name" ]] || continue
      download "$name" "http://gen.insave.ovh:9000/rotr/rotr-individual-files/$name" "$checksum"
    done < "$RESOURCES/manifests/rotr.tsv"
    cp -cR "$GAME" "$WORK/rotr" || { rm -rf "$WORK/rotr"; ditto "$GAME" "$WORK/rotr"; }
    while IFS=$'\t' read -r name checksum; do
      [[ -n "$name" ]] || continue
      if [[ "$name" == *.gib ]]; then
        [[ "$(head -c 4 "$CACHE/$name")" == BIGF || "$(head -c 4 "$CACHE/$name")" == BIG4 ]] || fail "Invalid BIG archive: $name"
      fi
      cp -c "$CACHE/$name" "$WORK/rotr/$(installed_name "$name")" || cp "$CACHE/$name" "$WORK/rotr/$(installed_name "$name")"
    done < "$RESOURCES/manifests/rotr.tsv"
    for name in SkirmishScripts.scb MultiplayerScripts.scb Scripts.ini; do
      stock="$WORK/rotr/Data/Scripts/$name"
      [[ ! -f "$stock" ]] || mv "$stock" "$stock.stock-disabled"
    done
    printf '1.87 Public Build 2.0\n' > "$WORK/rotr/.rotr-complete"
    if [[ -d "$MOD" ]]; then mv "$MOD" "$WORK/previous-rotr"; fi
    if ! mv "$WORK/rotr" "$MOD"; then
      [[ ! -d "$WORK/previous-rotr" ]] || mv "$WORK/previous-rotr" "$MOD"
      fail 'Could not install ROTR; previous installation restored.'
    fi
    echo 'Rise of the Reds installed.'
    ;;
  *) fail "Unknown action: $ACTION" ;;
esac
