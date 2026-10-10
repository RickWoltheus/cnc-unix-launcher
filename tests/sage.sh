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
for profile in cnc3 kw ra3; do
  PROFILE="$profile"
  case "$profile" in cnc3) prefix=CNC3; executable=cnc3game.dat ;; kw) prefix=CNC3EP1; executable=cnc3ep1.dat ;; ra3) prefix=RA3; executable=ra3_1.12.game ;; esac
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
(
  COMPAT_GAME="$TEST_ROOT/Owned RA3"
  COMPAT_PREFIX="$TEST_ROOT/RA3 prefix"
  WORK="$TEST_ROOT/directx-work"
  export GX_DIRECTX_FIXTURE_WORK="$WORK"
  mkdir -p "$COMPAT_GAME/_CommonRedist/DirectX/Jun2010" "$COMPAT_PREFIX/drive_c/windows/syswow64"
  printf 'synthetic owned CAB' > "$COMPAT_GAME/_CommonRedist/DirectX/Jun2010/AUG2007_d3dx9_35_x86.cab"
  cat > "$TEST_ROOT/directx-wine" <<'DIRECTX_FIXTURE'
#!/bin/bash
if [[ "$1" == extrac32 ]]; then
  [[ "$6" == *AUG2007_d3dx9_35_x86.cab ]] || exit 9
  printf 'MZsynthetic native helper' > "$GX_DIRECTX_FIXTURE_WORK/directx/d3dx9_35.dll"
elif [[ "$1" == reg ]]; then
  [[ "$5" == d3dx9_35 && "$7" == native,builtin ]] || exit 10
else exit 11
fi
DIRECTX_FIXTURE
  chmod +x "$TEST_ROOT/directx-wine"
  copy_file() { cp "$1" "$2"; }
  sage_prepare_directx_helpers "$TEST_ROOT/directx-wine" ra3
  cmp "$WORK/directx/d3dx9_35.dll" "$COMPAT_PREFIX/drive_c/windows/syswow64/d3dx9_35.dll"
  rm "$COMPAT_GAME/_CommonRedist/DirectX/Jun2010/AUG2007_d3dx9_35_x86.cab"
  if (sage_prepare_directx_helpers "$TEST_ROOT/directx-wine" ra3) >/dev/null 2>&1; then fail 'Missing owned RA3 CAB accepted.'; fi
)
if [[ $# -ge 2 ]]; then
  /bin/bash "$REPO/tests/sage-metal.sh" "$@"
fi
printf 'C&C 3 Steam library discovery, Proton selection, versioned startup, path rejection and dummy launches passed. No game or Steam client ran.\n'
