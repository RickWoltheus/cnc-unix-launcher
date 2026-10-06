#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/installation with spaces"
export GX_PREFERENCES_DIR="$SANDBOX/preferences"
BACKEND="$REPO/scripts/backend.sh"
bash -n "$BACKEND"
bash -n "$REPO/scripts/build.sh"
result="$(bash "$BACKEND" status)"
[[ "$result" == *'assets=missing'* && "$result" == *'rotr=missing'* ]]
mkdir -p "$GX_INSTALL_ROOT/GeneralsZH/ZH_Generals" "$GX_INSTALL_ROOT/GeneralsZH/steamapps"
printf '"AppState"\n{\n"StateFlags" "4"\n}\n' > "$GX_INSTALL_ROOT/GeneralsZH/steamapps/appmanifest_2732960.acf"
for name in INIZH.big TexturesZH.big W3DZH.big MapsZH.big; do
  printf 'BIGFfixture' > "$GX_INSTALL_ROOT/GeneralsZH/$name"
done
printf 'BIGFfixture' > "$GX_INSTALL_ROOT/GeneralsZH/ZH_Generals/Textures.big"
printf 'BIGFfixture' > "$GX_INSTALL_ROOT/GeneralsZH/ZH_Generals/W3D.big"
[[ "$(bash "$BACKEND" status)" == *'assets=ready'* ]]
printf 'corrupt' > "$GX_INSTALL_ROOT/GeneralsZH/TexturesZH.big"
[[ "$(bash "$BACKEND" status)" == *'assets=missing'* ]]
mkdir -p "$GX_PREFERENCES_DIR"
OPTIONS="$GX_PREFERENCES_DIR/Options.ini"
printf 'CampaignDifficulty = 2\nUseShadowVolumes = no\n' > "$OPTIONS"
bash "$BACKEND" graphics
grep -q 'CampaignDifficulty = 2' "$OPTIONS"
grep -q 'UseShadowVolumes = yes' "$OPTIONS"
[[ "$(grep -c '^UseShadowVolumes' "$OPTIONS")" == 1 ]]
grep -q 'UseShadowVolumes = no' "${OPTIONS%.ini}.before-launcher.ini"
bash "$BACKEND" graphics
[[ "$(grep -c '^UseShadowVolumes' "$OPTIONS")" == 1 ]]
bash "$BACKEND" graphics vanilla balanced
grep -q 'AntiAliasing = 2' "$OPTIONS"
grep -q 'UseShadowVolumes = no' "${OPTIONS%.ini}.before-launcher.ini"
mkdir "$GX_INSTALL_ROOT/.install-lock"
printf '%s\n' "$$" > "$GX_INSTALL_ROOT/.install-lock/pid"
if bash "$BACKEND" engine; then echo 'Concurrent install should have failed.' >&2; exit 1; fi
echo 'Backend checks passed.'
