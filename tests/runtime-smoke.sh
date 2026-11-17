#!/bin/bash
# Installs the pinned Mach9 runtime through the launcher (real download and SHA-256),
# boots a throwaway Wine prefix and runs Wine's D3D9 device tests through mtld3d.
# No Steam client or game runs. Wine may show windows; CI runs it on macos-26.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo 'The Mach9 runtime smoke test needs a Mac.'; exit 1; }
IFS=. read -r major minor _ <<< "$(sw_vers -productVersion).0"
if (( 10#$major < 26 || (10#$major == 26 && 10#$minor < 4) )); then
  echo "Mach9 needs macOS 26.4 or later; this Mac runs $(sw_vers -productVersion)."
  [[ -z "${GX_REQUIRE_RUNTIME_SMOKE:-}" ]] || exit 1
  exit 0
fi
TEST_ROOT="$(mktemp -d)"
export GX_INSTALL_ROOT="$TEST_ROOT/Install With Spaces"
runtime="$GX_INSTALL_ROOT/sage-metal-runtime/wine"
export WINEPREFIX="$TEST_ROOT/prefix" WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml=d;winemenubuilder.exe=d'
trap '"$runtime/bin/wineserver" -k >/dev/null 2>&1 || true; rm -rf "$TEST_ROOT"' EXIT
# macOS has no timeout(1); this stops a hung Wine instead of hanging the job.
limited() {
  local seconds="$1"; shift
  "$@" & local child=$!
  ( sleep "$seconds"; kill "$child" 2>/dev/null ) & local watchdog=$!
  local status=0; wait "$child" || status=$?
  kill "$watchdog" 2>/dev/null || true
  return "$status"
}

bash "$REPO/scripts/backend.sh" engine cnc3
[[ "$(cat "$GX_INSTALL_ROOT/sage-metal-runtime/.version")" == mach9-* ]]
limited 300 "$runtime/bin/wine" wineboot -u
[[ -d "$WINEPREFIX/drive_c/windows/syswow64" ]] || { echo 'Wine did not create a 64-bit prefix.'; exit 1; }

# The launcher's rule format, applied to Wine's own D3D9 tests.
export WINE_COMPATDB='exe=d3d9_test.exe;d3d9=mtld3d'
output="$TEST_ROOT/d3d9.txt"
status=0
limited 600 "$runtime/bin/wine" "$runtime/lib/wine/tests/i386-windows/d3d9_test.exe" device > "$output" 2>&1 || status=$?
summary="$(grep -E 'tests executed' "$output" | tail -n 1 || true)"
[[ -n "$summary" ]] || { tail -n 40 "$output"; echo "The D3D9 device tests did not finish (exit $status)."; exit 1; }
printf 'Mach9 D3D9 device tests through mtld3d: %s\n' "$summary"
[[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || printf 'Mach9 D3D9 device tests through mtld3d: `%s`\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
printf 'Pinned Mach9 runtime downloaded, verified, installed and booted a prefix; D3D9 ran through mtld3d. No Steam client or game ran.\n'
