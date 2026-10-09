#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cnc-sage-check.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export GX_INSTALL_ROOT="$TEST_ROOT/Install With Spaces"
export GX_LAUNCH_WRAPPER="$TEST_ROOT/dummy.sh"
ROOT="$GX_INSTALL_ROOT"; RESOURCES="$REPO"; PROFILE=cnc3; PLATFORM=linux
export GX_STEAM_ROOT="$TEST_ROOT/Steam With Spaces"
source "$REPO/scripts/compatibility.sh"
source "$REPO/scripts/sage.sh"
source "$REPO/scripts/downloads.sh"
find_game_file() { find "$1" -maxdepth 1 -type f -iname "$2" -print | head -n 1; }
fail() { echo "$*" >&2; exit 1; }
mkdir -p "$GX_STEAM_ROOT/config" "$GX_STEAM_ROOT/steamapps" "$TEST_ROOT/Other Library/steamapps/common/Proton 11.0"
printf '"path" "%s"\n' "$TEST_ROOT/Other Library" > "$GX_STEAM_ROOT/steamapps/libraryfolders.vdf"
touch "$TEST_ROOT/Other Library/steamapps/common/Proton 11.0/proton"
printf '"proton_11"\n' > "$TEST_ROOT/Other Library/steamapps/common/Proton 11.0/compatibilitytool.vdf"
sage_steam_binary() { echo /bin/true; }
cat > "$GX_LAUNCH_WRAPPER" <<'FIXTURE'
#!/bin/bash
printf 'exe=%s\n' "$1"
shift
printf 'argument=%s\n' "$@"
FIXTURE
if sage_proton_ready cnc3; then echo 'Missing Proton selection accepted.'; exit 1; fi
printf '"CompatToolMapping"\n{\n"24790"\n{\n"name" "proton_11"\n}\n}\n' > "$GX_STEAM_ROOT/config/config.vdf"
sage_proton_ready cnc3
if sage_proton_ready kw; then echo 'Wrong game Proton selection accepted.'; exit 1; fi
printf '"CompatToolMapping"\n{\n"0"\n{\n"name" "proton_11"\n}\n"24790"\n{\n"name" ""\n}\n}\n' > "$GX_STEAM_ROOT/config/config.vdf"
if sage_proton_ready cnc3; then echo 'Explicitly disabled Proton accepted through global fallback.'; exit 1; fi
printf '"CompatToolMapping"\n{\n"24790"\n{\n"name" "proton_missing"\n}\n}\n' > "$GX_STEAM_ROOT/config/config.vdf"
if sage_proton_ready cnc3; then echo 'Different installed Proton accepted for selected missing tool.'; exit 1; fi
printf '"CompatToolMapping"\n{\n"24790"\n{\n"name" "proton_11"\n}\n}\n' > "$GX_STEAM_ROOT/config/config.vdf"
for profile in cnc3 kw; do
  PROFILE="$profile"
  prefix=CNC3; executable=cnc3game.dat; [[ "$profile" != kw ]] || { prefix=CNC3EP1; executable=cnc3ep1.dat; }
  appid="$(compatibility_metadata "$profile" 5)"
  folder="$TEST_ROOT/Other Library/steamapps/common/Owned $prefix"
  mkdir -p "$folder/RetailExe/1.9" "$folder/RetailExe/1.10"
  printf '"StateFlags" "4"\n"installdir" "Owned %s"\n' "$prefix" > "$TEST_ROOT/Other Library/steamapps/appmanifest_$appid.acf"
  printf 'MZsynthetic game fixture; never executed' > "$folder/RetailExe/1.10/$executable"
  printf 'set-exe RetailExe\\1.9\\%s\r\n' "$executable" > "$folder/${prefix}_english_1.9.SkuDef"
  printf 'set-exe RetailExe\\1.10\\%s\r\n' "$executable" > "$folder/${prefix}_english_1.10.SkuDef"
  [[ "$(sage_steam_game "$profile")" == "$folder" ]]
  [[ "$(sage_config "$folder" "$profile")" == "$folder/${prefix}_english_1.10.SkuDef" ]]
  sage_assets_ready "$profile"
  # The launcher copy is untouched on Linux; Steam owns files and prefix updates.
  sage_engine_ready() { return 0; }
  compatibility_running() { return 1; }
  (sage_launch launch "$profile" -win -xres 1280 -yres 720)
  grep -q "exe=$folder/RetailExe/1.10/$executable" "$ROOT/logs/$profile.log"
  grep -q 'argument=-win' "$ROOT/logs/$profile.log"
  [[ ! -d "$ROOT/compatibility/$profile/prefix" && ! -d "$ROOT/compatibility/$profile/game" ]]
  printf 'set-exe ../../outside.exe\n' > "$folder/${prefix}_english_1.10.SkuDef"
  [[ -z "$(sage_executable "$folder" "$(sage_config "$folder" "$profile")")" ]]
  if sage_assets_ready "$profile"; then echo 'Escaping executable path accepted.'; exit 1; fi
  printf '"StateFlags" "6"\n"installdir" "Owned %s"\n' "$prefix" > "$TEST_ROOT/Other Library/steamapps/appmanifest_$appid.acf"
  if sage_assets_ready "$profile"; then echo 'Incomplete Steam download accepted.'; exit 1; fi
done
if [[ $# == 2 ]]; then
  [[ "$(uname -s)" == Darwin ]] || fail 'Real Sikarugir archive checks require Mac.'
  mkdir -p "$ROOT/downloads"
  cp "$1" "$ROOT/downloads/WS12WineSikarugir11.0_1.tar.xz"
  cp "$2" "$ROOT/downloads/Template-1.0.21.tar.xz"
  /bin/bash "$REPO/scripts/backend.sh" engine cnc3
  [[ ! -d "$ROOT/compatibility/cnc3/prefix" ]]
  [[ ! -e "$ROOT/sage-runtime/Frameworks/SikarugirSdk.framework" && ! -e "$ROOT/sage-runtime/Frameworks/renderer/d3dmetal" ]]
  /bin/bash "$REPO/scripts/backend.sh" status > "$TEST_ROOT/status.txt"
  grep -q 'cnc3_engine=ready' "$TEST_ROOT/status.txt"
  for profile in cnc3 kw; do
    prefix=CNC3; executable=cnc3game.dat; [[ "$profile" != kw ]] || { prefix=CNC3EP1; executable=cnc3ep1.dat; }
    appid="$(compatibility_metadata "$profile" 5)"; game="$ROOT/$(compatibility_metadata "$profile" 6)"
    mkdir -p "$game/steamapps" "$game/RetailExe/1.10"
    printf '"StateFlags" "4"\n' > "$game/steamapps/appmanifest_$appid.acf"
    printf 'MZsynthetic executable; never executed' > "$game/RetailExe/1.10/$executable"
    printf 'set-exe RetailExe\\1.10\\%s\r\n' "$executable" > "$game/${prefix}_english_1.10.SkuDef"
    /bin/bash "$REPO/scripts/backend.sh" launch "$profile" -win -xres 1280 -yres 720
    grep -q 'argument=-win' "$ROOT/logs/$profile.log"
    [[ ! -d "$ROOT/compatibility/$profile/prefix" && ! -f "$ROOT/compatibility/$profile/game/ddraw.dll" ]]
  done
  # A shell Wine fixture exercises actual prefix initialization, without a game.
  fixture_wine="$ROOT/sage-runtime/wine/wswine.bundle/bin/wine"
  mv "$fixture_wine" "$fixture_wine.original"
  cat > "$fixture_wine" <<'WINE_FIXTURE'
#!/bin/bash
[[ "${SikarugirAppWine11:-}" == 1 ]] || { echo 'Missing Sikarugir startup flag'; exit 77; }
if [[ "$1" == wineboot ]]; then
  mkdir -p "$WINEPREFIX/drive_c/windows/syswow64" "$WINEPREFIX/drive_c/windows/system32"
  printf 'prefix setup received SikarugirAppWine11=1\n'
else printf 'synthetic game handoff received SikarugirAppWine11=1\n'; fi
WINE_FIXTURE
  chmod +x "$fixture_wine"
  env -u GX_LAUNCH_WRAPPER /bin/bash "$REPO/scripts/backend.sh" launch cnc3 -win
  grep -q 'prefix setup received SikarugirAppWine11=1' "$ROOT/logs/cnc3.log"
  grep -q 'synthetic game handoff received SikarugirAppWine11=1' "$ROOT/logs/cnc3.log"
  [[ -f "$ROOT/compatibility/cnc3/prefix/.initialized" ]]

fi
printf 'C&C 3 Steam library discovery, Proton selection, versioned startup, path rejection and dummy launches passed. No game or Steam client ran.\n'
