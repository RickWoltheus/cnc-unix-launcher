#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Mac-specific Steam environment check skipped.'; exit 0; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"; trap 'rm -rf "$TEST_ROOT"' EXIT
export GX_INSTALL_ROOT="$TEST_ROOT" GX_LAUNCH_WRAPPER=/bin/true
runtime="$TEST_ROOT/sage-metal-runtime"
mkdir -p "$runtime/wine/bin" "$runtime/wine/lib/wine/d3d9/mtld3d/i386-windows" "$runtime/wine/lib/wine/d3d9/mtld3d/x86_64-unix"
printf 'cx-26.3.0-7+mtld3d-0.12.0\n' > "$runtime/.version"
printf 'MZsynthetic renderer' > "$runtime/wine/lib/wine/d3d9/mtld3d/i386-windows/d3d9.dll"
printf 'synthetic unix library' > "$runtime/wine/lib/wine/d3d9/mtld3d/x86_64-unix/mtld3d.so"
cat > "$runtime/wine/bin/wine" <<'FIXTURE'
#!/bin/bash
printf '%s\n%s\n%s\n' "$WINEPREFIX" "$WINE_COMPATDB" "$WINEDLLOVERRIDES" > "$GX_INSTALL_ROOT/open-steam.txt"
printf '%s\n' "$@" >> "$GX_INSTALL_ROOT/open-steam.txt"
FIXTURE
chmod +x "$runtime/wine/bin/wine"
mkdir -p "$TEST_ROOT/compatibility/cnc3/game/Data" "$TEST_ROOT/compatibility/cnc3/metal/prefix/drive_c/Program Files (x86)/Steam"
printf 'MZsynthetic game' > "$TEST_ROOT/compatibility/cnc3/game/Data/cnc3game.dat"
printf 'set-exe Data\\cnc3game.dat\n' > "$TEST_ROOT/compatibility/cnc3/game/CNC3_english_1.10.SkuDef"
printf 'MZsynthetic Steam' > "$TEST_ROOT/compatibility/cnc3/metal/prefix/drive_c/Program Files (x86)/Steam/steam.exe"
bash "$REPO/scripts/backend.sh" game-steam cnc3
for attempt in 1 2 3 4 5 6 7 8 9 10; do [[ ! -f "$TEST_ROOT/open-steam.txt" ]] || break; sleep 0.1; done
grep -q 'exe=cnc3game.dat;d3d9=mtld3d' "$TEST_ROOT/open-steam.txt"
grep -q 'gameoverlayrenderer,gameoverlayrenderer64=d' "$TEST_ROOT/open-steam.txt"
grep -qx 'steam://nav/games/details/24790' "$TEST_ROOT/open-steam.txt"
printf 'Guide Open Steam retained the selected Metal environment and overlay settings. Synthetic client only.\n'
