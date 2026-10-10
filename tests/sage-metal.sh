#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname -s)" == Darwin && $# -ge 2 ]] || { echo 'Provide pinned Wine and mtld3d archives on Mac.'; exit 1; }
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export GX_INSTALL_ROOT="$TEST_ROOT/Install With Spaces"
ROOT="$GX_INSTALL_ROOT"
mkdir -p "$ROOT/downloads" "$ROOT/wine-runtime"
printf 'old engine retained' > "$ROOT/wine-runtime/retained"
cp "$1" "$ROOT/downloads/wine-cx-26.3.0-7-macos-x86_64.tar.xz"
cp "$2" "$ROOT/downloads/mtld3d-0.12.0.tar.xz"
bash "$REPO/scripts/backend.sh" engine cnc3
[[ ! -d "$ROOT/compatibility/cnc3" ]]
[[ "$(cat "$ROOT/wine-runtime/retained")" == 'old engine retained' ]]
for architecture in i386-windows x86_64-windows; do
 [[ -s "$ROOT/sage-metal-runtime/wine/lib/wine/d3d9/mtld3d/$architecture/d3d9.dll" ]]
done
[[ -s "$ROOT/sage-metal-runtime/mtld3d-LICENSE" ]]
if [[ $# -ge 3 ]]; then cp "$3" "$ROOT/downloads/SteamSetup-2026-10-09.exe"; fi
fixture="$ROOT/sage-metal-runtime/wine/bin/wine"
mv "$fixture" "$fixture.original"
export GX_METAL_FIXTURE_ROOT="$ROOT"
cat > "$fixture" <<'WINE_FIXTURE'
#!/bin/bash
set -eu
if [[ "$1" == wineboot ]]; then
 mkdir -p "$WINEPREFIX/drive_c/windows/syswow64" "$WINEPREFIX/drive_c/windows/system32"
elif [[ "$1" == extrac32 ]]; then
 destination="${5#Z:}"
 case "$6" in *35_x86.cab) dll=d3dx9_35.dll ;; *29_x86.cab) dll=d3dx9_29.dll ;; *36_x86.cab) dll=d3dx9_36.dll ;; *) exit 8 ;; esac
 printf 'MZsynthetic native helper' > "$destination/$dll"
elif [[ "$1" == *SteamSetup* ]]; then
 mkdir -p "$WINEPREFIX/drive_c/Program Files (x86)/Steam"
 printf 'MZsynthetic Steam' > "$WINEPREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
elif [[ "$1" == reg ]]; then
 printf '%s\n' "$@" >> "$GX_METAL_FIXTURE_ROOT/registry.txt"
else
 printf '%s\n' "$WINE_COMPATDB" > "$GX_METAL_FIXTURE_ROOT/handoff.txt"
 printf '%s\n' "$@" >> "$GX_METAL_FIXTURE_ROOT/handoff.txt"
 case "$*" in *24790*) id=cnc3; exe=cnc3game.dat ;; *24810*) id=kw; exe=cnc3ep1.dat ;; *17480*) id=ra3; exe=ra3_1.13.game ;; *) exit 9 ;; esac
 exec python3 -c 'import os,sys; os.execv("/bin/sleep", [sys.argv[1], "3"])' "$GX_METAL_FIXTURE_ROOT/compatibility/$id/game/Data/$exe"
fi
WINE_FIXTURE
chmod +x "$fixture"
for id in cnc3 kw ra3; do
 case "$id" in cnc3) app=24790; dir=TiberiumWars; prefix=CNC3; exe=cnc3game.dat ;; kw) app=24810; dir=KanesWrath; prefix=CNC3EP1; exe=cnc3ep1.dat ;; ra3) app=17480; dir=RedAlert3; prefix=RA3; exe=ra3_1.13.game ;; esac
 game="$ROOT/$dir"; prefix_dir="$ROOT/compatibility/$id/metal/prefix"
 if [[ "$id" == cnc3 ]]; then
   prefix_dir="$ROOT/compatibility/cnc3/wine10-test/prefix"
   mkdir -p "$(dirname "$prefix_dir")"
   printf 'wine10-test\n' > "$ROOT/compatibility/cnc3/.runtime-choice"
   mkdir -p "$prefix_dir/drive_c/users/test/Saved Games"
   printf 'synthetic save preserved' > "$prefix_dir/drive_c/users/test/Saved Games/sentinel.sav"
 fi
 steam="$prefix_dir/drive_c/Program Files (x86)/Steam"
 mkdir -p "$game/steamapps" "$game/Data" "$game/_CommonRedist/DirectX/Jun2010" "$steam/bin/cef/cef.win64"
 printf '"StateFlags" "4"\n"installdir" "Owned %s"\n' "$prefix" > "$game/steamapps/appmanifest_$app.acf"
 printf 'MZsynthetic executable' > "$game/Data/$exe"
 printf 'set-exe Data\\%s\n' "$exe" > "$game/${prefix}_english_1.13.SkuDef"
 printf 'synthetic CAB' > "$game/_CommonRedist/DirectX/Jun2010/AUG2007_d3dx9_35_x86.cab"
 printf 'synthetic CAB' > "$game/_CommonRedist/DirectX/Jun2010/Feb2006_d3dx9_29_x86.cab"
 printf 'synthetic CAB' > "$game/_CommonRedist/DirectX/Jun2010/Nov2007_d3dx9_36_x86.cab"
 if [[ $# -lt 3 || "$id" != cnc3 ]]; then printf 'MZsynthetic Steam' > "$steam/steam.exe"; fi
 python3 "$REPO/tests/fixtures/steam-browser.py" "$steam/bin/cef/cef.win64/steamwebhelper.exe" 'synthetic browser'
 bash "$REPO/scripts/backend.sh" launch "$id" -win
 grep -q "exe=$exe;d3d9=mtld3d" "$ROOT/handoff.txt"
 grep -qx "$app" "$ROOT/handoff.txt"
 [[ "$(head -n 1 "$ROOT/launch-$id.status")" == closed ]]
 [[ -s "$ROOT/compatibility/$id/metal/prefix/.metal-version" ]]
 if [[ "$id" == cnc3 ]]; then
   cmp "$prefix_dir/drive_c/users/test/Saved Games/sentinel.sav" "$ROOT/compatibility/$id/metal/prefix/drive_c/users/test/Saved Games/sentinel.sav"
   [[ -L "$ROOT/compatibility/$id/metal/prefix/drive_c/Program Files (x86)/Steam/steamapps/common/Owned CNC3" ]]
 fi
done
printf 'Clean pinned Metal install, per-game Wine prefix setup, owned dependency repair and Steam handoff passed. Synthetic processes only.\n'
