#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# == 3 ]] || { echo 'Usage: bash tests/install.sh ENGINE_ZIP STEAMCMD_TAR ROTR_DOWNLOAD_FOLDER' >&2; exit 2; }
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/installation with spaces"
export GX_PREFERENCES_DIR="$SANDBOX/preferences"
BACKEND="$REPO/scripts/backend.sh"
export GX_LAUNCH_WRAPPER="$REPO/tests/fixtures/record-launch.sh"
mkdir -p "$GX_INSTALL_ROOT/downloads"
cp -c "$1" "$GX_INSTALL_ROOT/downloads/GeneralsXZH-1.0.2.zip"
cp -c "$2" "$GX_INSTALL_ROOT/downloads/steamcmd-bootstrap.tar.gz"
mkdir -p "$GX_INSTALL_ROOT/downloads/rotr"
while IFS=$'\t' read -r name checksum url; do
  cp -c "$3/$name" "$GX_INSTALL_ROOT/downloads/rotr/$name"
done < "$REPO/manifests/rotr.tsv"
bash "$BACKEND" engine
bash "$BACKEND" engine
bash "$BACKEND" steam
bash "$BACKEND" steam
[[ "$(bash "$BACKEND" status)" == *'engine=ready'* ]]
[[ "$(bash "$BACKEND" status)" == *'steam=ready'* ]]
GAME="$GX_INSTALL_ROOT/GeneralsZH"
mkdir -p "$GAME/ZH_Generals" "$GAME/steamapps" "$GAME/Data/Scripts"
for name in INIZH.big TexturesZH.big W3DZH.big MapsZH.big; do printf 'BIGFfixture' > "$GAME/$name"; done
for name in Textures.big W3D.big; do printf 'BIGFfixture' > "$GAME/ZH_Generals/$name"; done
for name in SkirmishScripts.scb MultiplayerScripts.scb Scripts.ini; do printf 'stock fixture' > "$GAME/Data/Scripts/$name"; done
printf '"AppState"\n{\n"StateFlags" "4"\n}\n' > "$GAME/steamapps/appmanifest_2732960.acf"
bash "$BACKEND" rotr
bash "$BACKEND" rotr
[[ -f "$GAME/Data/Scripts/SkirmishScripts.scb" ]]
[[ -f "$GX_INSTALL_ROOT/RiseOfTheReds/Data/Scripts/SkirmishScripts.scb.stock-disabled" ]]
[[ ! -f "$GX_INSTALL_ROOT/RiseOfTheReds/Data/Scripts/SkirmishScripts.scb" ]]
[[ "$(bash "$BACKEND" status)" == *'rotr=ready'* ]]
bash "$BACKEND" launch vanilla -fullscreen -xres 1920 -yres 1080
grep -Fq "profile=$GAME" "$GX_INSTALL_ROOT/logs/vanilla.log"
grep -q 'arg=-fullscreen' "$GX_INSTALL_ROOT/logs/vanilla.log"
grep -q 'hud=0' "$GX_INSTALL_ROOT/logs/vanilla.log"
rm "$GX_INSTALL_ROOT/engine/GeneralsXZH.app/Contents/Resources/lib/libMoltenVK.dylib"
bash "$BACKEND" launch vanilla -win
[[ -s "$GX_INSTALL_ROOT/engine/GeneralsXZH.app/Contents/Resources/lib/libMoltenVK.dylib" ]]
bash "$BACKEND" launch rotr -win -xres 1280 -yres 720
grep -Fq "profile=$GX_INSTALL_ROOT/RiseOfTheReds" "$GX_INSTALL_ROOT/logs/rotr.log"
grep -q 'arg=-noshellmap' "$GX_INSTALL_ROOT/logs/rotr.log"
printf 'corrupt' > "$GX_INSTALL_ROOT/RiseOfTheReds/!Rotr_Blckr.big"
if bash "$BACKEND" launch rotr -win; then echo 'Corrupt mod should not launch.' >&2; exit 1; fi
bash "$BACKEND" rotr
bash "$BACKEND" launch rotr -win
STEAM="$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh"
cat > "$STEAM" <<'FIXTURE'
#!/bin/bash
printf 'Steam fixture received: %s\n' "$@"
FIXTURE
chmod +x "$STEAM"
printf 'fixture-account\n' | bash "$BACKEND" steam-login
[[ "$(cat "$GX_INSTALL_ROOT/steam-vanilla.status")" == complete ]]
cat > "$STEAM" <<'FIXTURE'
#!/bin/bash
echo 'FAILED (InvalidPassword)'
exit 1
FIXTURE
if printf 'fixture-account\n' | bash "$BACKEND" steam-login; then echo 'Rejected login should fail.' >&2; exit 1; fi
[[ "$(cat "$GX_INSTALL_ROOT/steam-vanilla.status")" == wrong-password ]]
cat > "$STEAM" <<'FIXTURE'
#!/bin/bash
echo "ERROR! Failed to install app '2732960' (No subscription)"
FIXTURE
if printf '+invalid\n' | bash "$BACKEND" steam-login; then echo 'Invalid account argument should fail.' >&2; exit 1; fi
printf 'corrupt' > "$GAME/INIZH.big"
if printf 'fixture-account\n' | bash "$BACKEND" steam-login; then echo 'Incomplete Steam download should fail.' >&2; exit 1; fi
[[ "$(cat "$GX_INSTALL_ROOT/steam-vanilla.status")" == no-license ]]
echo 'Engine, SteamCMD, ROTR, repair, and dummy-launch integration checks passed. No real game or Steam client was started.'
