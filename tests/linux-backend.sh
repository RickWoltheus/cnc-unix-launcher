#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname -s)" == Linux && $# == 3 ]] || { echo 'Usage on Linux: tests/linux-backend.sh ZH_FLATPAK BASE_FLATPAK STEAMCMD_TAR' >&2; exit 2; }
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/installation with spaces"
export GX_LAUNCH_WRAPPER="$REPO/tests/fixtures/record-launch.sh"
export GX_FAKE_FLATPAK_STATE="$SANDBOX/flatpak-state"
export GX_FLATPAK="$SANDBOX/flatpak"
mkdir -p "$GX_INSTALL_ROOT/downloads" "$GX_FAKE_FLATPAK_STATE"
cat > "$GX_FLATPAK" <<'FAKE'
#!/bin/bash
set -e
printf '%s\n' "$@" >> "$GX_FAKE_FLATPAK_STATE/arguments"
case "$1" in
  info)
    [[ -f "$GX_FAKE_FLATPAK_STATE/${@: -1}" ]] || exit 1
    if [[ "$*" == *--show-commit* ]]; then echo "fixture-commit-${@: -1}"; fi ;;
  install)
    archive="${@: -1}"
    if [[ "$archive" == *GeneralsXZH* ]]; then touch "$GX_FAKE_FLATPAK_STATE/com.fbraz3.GeneralsXZH"
    else touch "$GX_FAKE_FLATPAK_STATE/com.fbraz3.GeneralsX"; fi ;;
  *) exit 0 ;;
esac
FAKE
chmod +x "$GX_FLATPAK"
cp "$1" "$GX_INSTALL_ROOT/downloads/GeneralsXZH-1.0.2.flatpak"
cp "$2" "$GX_INSTALL_ROOT/downloads/GeneralsX-1.0.2.flatpak"
cp "$3" "$GX_INSTALL_ROOT/downloads/steamcmd-linux-bootstrap.tar.gz"
BACKEND="$REPO/scripts/backend.sh"
bash "$BACKEND" engine
bash "$BACKEND" engine base
bash "$BACKEND" steam
[[ "$(bash "$BACKEND" status)" == *'platform=ready'* ]]
[[ "$(bash "$BACKEND" status)" == *'base_engine=ready'* ]]
GAME="$GX_INSTALL_ROOT/GeneralsZH"
mkdir -p "$GAME/ZH_Generals" "$GAME/steamapps"
for name in INIZH.big TexturesZH.big W3DZH.big mapszh.big; do printf 'BIGFfixture' > "$GAME/$name"; done
for name in Textures.big W3D.big; do printf 'BIGFfixture' > "$GAME/ZH_Generals/$name"; done
printf '"AppState"\n{\n"StateFlags" "4"\n}\n' > "$GAME/steamapps/appmanifest_2732960.acf"
bash "$BACKEND" graphics vanilla balanced
grep -q 'AntiAliasing = 2' "$GX_INSTALL_ROOT/user-data/GeneralsX/GeneralsZH/Options.ini"
bash "$BACKEND" launch vanilla -win -xres 1280 -yres 720
grep -Fq "profile=$GAME" "$GX_INSTALL_ROOT/logs/vanilla.log"
grep -q 'hud=0' "$GX_INSTALL_ROOT/logs/vanilla.log"
cat > "$GX_INSTALL_ROOT/steamcmd/steamcmd.sh" <<'FAKE'
#!/bin/bash
echo 'FAILED (InvalidPassword)'
exit 1
FAKE
if printf 'fixture-account\n' | bash "$BACKEND" steam-login; then exit 1; fi
[[ "$(cat "$GX_INSTALL_ROOT/steam-vanilla.status")" == wrong-password ]]
grep -q 'remote-add' "$GX_FAKE_FLATPAK_STATE/arguments"
echo 'Linux backend passed actual archive checks, Steam extraction, adapter dispatch, graphics paths and dummy launch; Flatpak service and Steam authentication were simulated.'
