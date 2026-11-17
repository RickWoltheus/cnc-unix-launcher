#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Mac-specific Steam environment check skipped.'; exit 0; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"; trap 'rm -rf "$TEST_ROOT"' EXIT
export GX_LAUNCH_WRAPPER=/bin/true
mach9="mach9-$(awk -F '\t' '$1=="sage-metal-wine" {print $2}' "$REPO/manifests/compatibility-packages.tsv")"
# Installed x86_64 runtimes keep their prefix and rule format; Mach9 gets its own prefix.
for case in "cx-26.3.0-7+mtld3d-0.12.0 x86_64-unix metal" "$mach9 aarch64-unix mach9"; do
  read -r version unix prefix <<< "$case"
  export GX_INSTALL_ROOT="$TEST_ROOT/$prefix"
  runtime="$GX_INSTALL_ROOT/sage-metal-runtime"
  mkdir -p "$runtime/wine/bin" "$runtime/wine/lib/wine/d3d9/mtld3d/i386-windows" "$runtime/wine/lib/wine/d3d9/mtld3d/$unix"
  printf '%s\n' "$version" > "$runtime/.version"
  printf 'MZsynthetic renderer' > "$runtime/wine/lib/wine/d3d9/mtld3d/i386-windows/d3d9.dll"
  printf 'synthetic unix library' > "$runtime/wine/lib/wine/d3d9/mtld3d/$unix/mtld3d.so"
  cat > "$runtime/wine/bin/wine" <<'FIXTURE'
#!/bin/bash
printf '%s\n%s\n%s\n' "$WINEPREFIX" "$WINE_COMPATDB" "$WINEDLLOVERRIDES" > "$GX_INSTALL_ROOT/open-steam.txt"
printf '%s\n' "$@" >> "$GX_INSTALL_ROOT/open-steam.txt"
FIXTURE
  chmod +x "$runtime/wine/bin/wine"
  game="$GX_INSTALL_ROOT/compatibility/cnc3/game"
  steam="$GX_INSTALL_ROOT/compatibility/cnc3/$prefix/prefix/drive_c/Program Files (x86)/Steam"
  mkdir -p "$game/Data" "$steam"
  printf 'MZsynthetic game' > "$game/Data/cnc3game.dat"
  printf 'set-exe Data\\cnc3game.dat\n' > "$game/CNC3_english_1.10.SkuDef"
  printf 'MZsynthetic Steam' > "$steam/steam.exe"
  bash "$REPO/scripts/backend.sh" game-steam cnc3
  for attempt in 1 2 3 4 5 6 7 8 9 10; do [[ ! -f "$GX_INSTALL_ROOT/open-steam.txt" ]] || break; sleep 0.1; done
  grep -qx "$GX_INSTALL_ROOT/compatibility/cnc3/$prefix/prefix" "$GX_INSTALL_ROOT/open-steam.txt"
  grep -q 'exe=cnc3game.dat;d3d9=mtld3d' "$GX_INSTALL_ROOT/open-steam.txt"
  if [[ "$prefix" == mach9 ]]; then
    if grep -q '^v=3$' "$GX_INSTALL_ROOT/open-steam.txt"; then echo 'Mach9 received the legacy rule header.'; exit 1; fi
  else grep -qx 'v=3' "$GX_INSTALL_ROOT/open-steam.txt"; fi
  grep -q 'gameoverlayrenderer,gameoverlayrenderer64=d' "$GX_INSTALL_ROOT/open-steam.txt"
  grep -qx 'steam://nav/games/details/24790' "$GX_INSTALL_ROOT/open-steam.txt"
  if [[ "$prefix" == metal ]]; then
    # Repair keeps the runtime whose archive is gone, below and above Mach9's minimum.
    for macos in 26.3 26.4; do
      output="$(GX_MACOS_VERSION="$macos" bash "$REPO/scripts/backend.sh" engine cnc3)"
      [[ "$output" == *'is complete and kept'* ]]
      [[ "$(cat "$runtime/.version")" == "$version" && -s "$runtime/wine/lib/wine/d3d9/mtld3d/x86_64-unix/mtld3d.so" ]]
    done
  fi
done
printf 'Guide Open Steam retained the selected Metal environment (installed x86_64 and Mach9) and overlay settings. Synthetic client only.\n'
