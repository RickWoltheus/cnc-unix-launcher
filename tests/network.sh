#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/fresh network install"
bash "$REPO/scripts/backend.sh" engine
bash "$REPO/scripts/backend.sh" steam
EXPECTED="$(awk -F '\t' '$1 == "!Rotr_Blckr.gib" {print $2}' "$REPO/manifests/rotr.tsv")"
curl -fL --retry 2 --max-time 60 -sS \
  'http://gen.insave.ovh:9000/rotr/rotr-individual-files/%21Rotr_Blckr.gib' -o "$SANDBOX/sample.gib"
[[ "$(shasum -a 256 "$SANDBOX/sample.gib" | awk '{print $1}')" == "$EXPECTED" ]]
mkdir -p "$SANDBOX/fixture/scripts" "$SANDBOX/fixture/manifests"
cp "$REPO/scripts/backend.sh" "$SANDBOX/fixture/scripts/backend.sh"
printf '!Rotr_Blckr.gib\t%064d\n' 0 > "$SANDBOX/fixture/manifests/rotr.tsv"
GAME="$GX_INSTALL_ROOT/GeneralsZH"
mkdir -p "$GAME/ZH_Generals" "$GAME/steamapps" "$GX_INSTALL_ROOT/RiseOfTheReds"
for name in INIZH.big TexturesZH.big W3DZH.big MapsZH.big; do printf 'BIGFfixture' > "$GAME/$name"; done
for name in Textures.big W3D.big; do printf 'BIGFfixture' > "$GAME/ZH_Generals/$name"; done
printf '"AppState"\n{\n"StateFlags" "4"\n}\n' > "$GAME/steamapps/appmanifest_2732960.acf"
printf 'working installation' > "$GX_INSTALL_ROOT/RiseOfTheReds/preserved.txt"
if bash "$SANDBOX/fixture/scripts/backend.sh" rotr > "$SANDBOX/rejection.log" 2>&1; then
  echo 'Bad checksum should have stopped the installation.' >&2; exit 1
fi
grep -q 'Checksum mismatch' "$SANDBOX/rejection.log"
[[ "$(cat "$GX_INSTALL_ROOT/RiseOfTheReds/preserved.txt")" == 'working installation' ]]
[[ ! -d "$GX_INSTALL_ROOT/.install-lock" ]]
echo 'Fresh downloads, mirror checksum, and checksum rejection without replacing an installation passed. No applications launched.'
