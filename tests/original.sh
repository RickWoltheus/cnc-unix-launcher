#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
RESOURCES="$SANDBOX/launcher"
ROOT="$SANDBOX/Install With Spaces"
mkdir -p "$RESOURCES/resources/original-runtime/bin" "$ROOT"
cp -R "$REPO/scripts" "$REPO/manifests" "$RESOURCES/"
cp "$REPO"/resources/*.json "$RESOURCES/resources/"
export GX_INSTALL_ROOT="$ROOT" GX_LAUNCH_WRAPPER="$REPO/tests/fixtures/record-launch.sh" GX_FLATPAK=true
python3 "$REPO/tests/fixtures/classic-assets.py" "$REPO" "$ROOT"
mv "$ROOT/TiberianDawn" "$ROOT/OwnedCNC"
ln -s "$ROOT/OwnedCNC" "$ROOT/TiberianDawn"
source "$REPO/scripts/downloads.sh"
runtime="$RESOURCES/resources/original-runtime"
cp /usr/bin/true "$runtime/bin/vanillatd"
cp /usr/bin/true "$runtime/bin/vanillara"
PLATFORM=linux; [[ "$(uname -s)" != Darwin ]] || PLATFORM=macos
source "$REPO/scripts/original.sh"
original_runtime_version > "$runtime/.version"
for exe in vanillatd vanillara; do printf '%s\tbin/%s\n' "$(checksum_file "$runtime/bin/$exe")" "$exe"; done > "$runtime/.hashes"
printf original-save > "$ROOT/openra-save-fixture"
for profile in cnc-original ra-original; do
  backend="$RESOURCES/scripts/backend.sh"
  bash "$backend" engine "$profile"
  bash "$backend" import-original "$profile"
  mkdir -p "$ROOT/original-$profile/user"
  printf preserved > "$ROOT/original-$profile/user/save.fixture"
  config=CONQUER.INI; [[ "$profile" != ra-original ]] || config=REDALERT.INI
  printf '[Options]\nGameSpeed=4\n' > "$ROOT/original-$profile/user/$config"
  bash "$backend" launch "$profile" -win -xres 1280 -yres 800
  grep -q 'Windowed=yes' "$ROOT/original-$profile/user/$config"
  grep -q 'GameSpeed=4' "$ROOT/original-$profile/user/$config"
  grep -q "original-$profile" "$ROOT/logs/$profile.log"
  [[ "$(cat "$ROOT/original-$profile/user/save.fixture")" == preserved ]]
  bash "$backend" import-original "$profile"
  [[ "$(cat "$ROOT/original-$profile/user/save.fixture")" == preserved ]]
done
[[ -s "$ROOT/original-ra-original/data/allied/MAIN.MIX" && -s "$ROOT/original-ra-original/data/aftermath/MAIN.MIX" ]]
[[ "$(cat "$ROOT/openra-save-fixture")" == original-save ]]
printf corrupt > "$ROOT/engine-cnc-original/bin/vanillatd"
if bash "$backend" launch cnc-original -win > "$SANDBOX/corrupt.log" 2>&1; then echo 'Corrupt runtime was accepted'; exit 1; fi
grep -q 'failed verification' "$SANDBOX/corrupt.log"
echo 'Original engine selection, Steam asset mapping, disc layout, isolated settings/saves and corrupt-runtime rejection passed. Dummy engines only.'
