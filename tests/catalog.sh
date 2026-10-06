#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# == 3 ]] || { echo 'Usage: bash tests/catalog.sh BASE_ENGINE_ZIP ROTR_DOWNLOADS OTHER_MOD_DOWNLOADS' >&2; exit 2; }
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/catalog install with spaces"
export GX_PREFERENCES_DIR="$SANDBOX/preferences"
BACKEND="$REPO/scripts/backend.sh"
mkdir -p "$GX_INSTALL_ROOT/downloads"
cp -c "$1" "$GX_INSTALL_ROOT/downloads/GeneralsX-1.0.2.zip"
bash "$BACKEND" engine base
BASE="$GX_INSTALL_ROOT/Generals"
GAME="$GX_INSTALL_ROOT/GeneralsZH"
for dir in "$BASE" "$GAME"; do mkdir -p "$dir/steamapps" "$dir/Data/Scripts"; done
for name in INI.big Textures.big W3D.big Maps.big; do printf 'BIGFfixture' > "$BASE/$name"; done
for name in INIZH.big TexturesZH.big W3DZH.big MapsZH.big; do printf 'BIGFfixture' > "$GAME/$name"; done
mkdir -p "$GAME/ZH_Generals"
for name in Textures.big W3D.big; do printf 'BIGFfixture' > "$GAME/ZH_Generals/$name"; done
for name in SkirmishScripts.scb MultiplayerScripts.scb Scripts.ini; do printf 'stock fixture' > "$GAME/Data/Scripts/$name"; done
for pair in "$BASE:2229870" "$GAME:2732960"; do
  dir="${pair%:*}"; appid="${pair##*:}"
  printf '"AppState"\n{\n"StateFlags" "4"\n}\n' > "$dir/steamapps/appmanifest_$appid.acf"
done
for engine in "$GX_INSTALL_ROOT/engine-base/GeneralsX.app" "$GX_INSTALL_ROOT/engine/GeneralsXZH.app"; do
  mkdir -p "$engine/Contents/MacOS"
  cat > "$engine/Contents/MacOS/run.sh" <<'FIXTURE'
#!/bin/bash
printf 'base=%s\nzh=%s\n' "$CNC_GENERALS_PATH" "$CNC_GENERALS_ZH_PATH"
printf 'arg=%s\n' "$@"
FIXTURE
  chmod +x "$engine/Contents/MacOS/run.sh"
done
bash "$BACKEND" launch base -fullscreen -xres 1920 -yres 1080
grep -Fq "base=$BASE" "$GX_INSTALL_ROOT/logs/base.log"
bash "$BACKEND" graphics base
[[ -f "$GX_PREFERENCES_DIR/Options.ini" ]]
while IFS=$'\t' read -r id title version directory base_url support; do
  source="$3/$id"
  [[ "$id" != rotr ]] || source="$2"
  while IFS=$'\t' read -r name checksum url; do
    mkdir -p "$(dirname "$GX_INSTALL_ROOT/downloads/$id/$name")"
    cp -c "$source/$name" "$GX_INSTALL_ROOT/downloads/$id/$name"
  done < "$REPO/manifests/$id.tsv"
  bash "$BACKEND" mod "$id"
  bash "$BACKEND" mod "$id"
  bash "$BACKEND" launch "$id" -win
  grep -Fq "zh=$GX_INSTALL_ROOT/$directory" "$GX_INSTALL_ROOT/logs/$id.log"
  [[ -f "$GAME/Data/Scripts/SkirmishScripts.scb" ]]
  if [[ "$id" == teod ]]; then
    cmp "$source/Data/Scripts/SkirmishScripts.scb" "$GX_INSTALL_ROOT/$directory/Data/Scripts/SkirmishScripts.scb"
  else
    [[ ! -f "$GX_INSTALL_ROOT/$directory/Data/Scripts/SkirmishScripts.scb" ]]
  fi
  echo "Passed install, repeat-install, and dummy-launch checks: $title"
done < "$REPO/manifests/mods.tsv"
mkdir -p "$GX_INSTALL_ROOT/steamcmd/MacOS"
cat > "$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh" <<'FIXTURE'
#!/bin/bash
printf '%s\n' "$@" > "$GX_INSTALL_ROOT/steam-arguments.txt"
FIXTURE
chmod +x "$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh"
printf 'fixture-account\n' | bash "$BACKEND" steam-login base
grep -q '^2229870$' "$GX_INSTALL_ROOT/steam-arguments.txt"
echo 'Base Generals and all five curated mods passed headless checks. No real games or Steam client started.'
