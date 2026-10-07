#!/bin/bash
set -euo pipefail
ulimit -c 0
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# == 1 ]] || { echo 'Usage: tests/native-mods.sh DISPOSABLE_INSTALLATION_WITH_NATIVE_RUNTIMES'; exit 2; }
export GX_INSTALL_ROOT="$1"
export GX_LAUNCH_WRAPPER="$REPO/tests/fixtures/record-launch.sh"
python3 "$REPO/tests/fixtures/classic-assets.py" "$REPO" "$GX_INSTALL_ROOT"
python3 "$REPO/tests/fixtures/remastered-assets.py" "$REPO" "$GX_INSTALL_ROOT"
BACKEND="$REPO/scripts/backend.sh"
mkdir -p "$GX_INSTALL_ROOT/native-mod-data/tdhd/CustomProgress"
printf fixture > "$GX_INSTALL_ROOT/native-mod-data/tdhd/CustomProgress/save.bin"
for id in combined-arms tdhd; do
  bash "$BACKEND" native-mod "$id"
  status="$(bash "$BACKEND" status)"
  [[ "$status" == *"$id=ready"* ]]
  bash "$BACKEND" launch "$id" -win -xres 1280 -yres 720
  grep -q 'arg=Graphics.Mode=Windowed' "$GX_INSTALL_ROOT/logs/$id.log"
  if [[ "$id" == combined-arms ]]; then grep -q 'arg=Game.Mod=ca' "$GX_INSTALL_ROOT/logs/$id.log"
  else grep -q 'arg=Game.Mod=cnc' "$GX_INSTALL_ROOT/logs/$id.log"; fi
  bash "$BACKEND" online-prepare "$id" join
  [[ -s "$GX_INSTALL_ROOT/online-$id.ready" ]]
done
OPTIONS="$GX_INSTALL_ROOT/native-mod-data/combined-arms/settings.yaml"
printf 'Player:\n\tName: Fixture player\nServer:\n\tPassword: fixture-server-secret\n\tDiscoverNatDevices: False\nGraphics:\n\tVSync: False\n' > "$OPTIONS"
bash "$BACKEND" online-prepare combined-arms host
grep -q 'DiscoverNatDevices: True' "$OPTIONS"
grep -q 'AdvertiseOnline: True' "$OPTIONS"
grep -q 'Name: Fixture player' "$OPTIONS"
grep -q 'Password: fixture-server-secret' "$OPTIONS"
grep -q 'VSync: False' "$OPTIONS"
[[ -s "$OPTIONS.before-launcher" ]]
# Steam gets a dummy client; cached synthetic sources satisfy its validation.
if [[ "$(uname -s)" == Darwin ]]; then steam="$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh"
else steam="$GX_INSTALL_ROOT/steamcmd/steamcmd.sh"; export GX_FLATPAK=true; fi
cat > "$steam" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" > "$GX_INSTALL_ROOT/fixture-native-steam-arguments"
echo 'Success! App fully installed.'
FAKE
chmod +x "$steam"
for id in combined-arms tdhd; do
  printf 'fixture-account\n' | bash "$BACKEND" steam-login "$id"
  [[ "$(cat "$GX_INSTALL_ROOT/steam-$id.status")" == complete ]]
  args="$(cat "$GX_INSTALL_ROOT/fixture-native-steam-arguments")"
  if [[ "$id" == tdhd ]]; then [[ "$args" == *1213210* ]]; else [[ "$args" == *2229840* && "$args" == *2229830* ]]; fi
done
[[ "$(cat "$GX_INSTALL_ROOT/native-mod-data/tdhd/CustomProgress/save.bin")" == fixture ]]
printf corrupted > "$GX_INSTALL_ROOT/Remastered/Data/TEXTURES_TD_SRGB.MEG"
previous="$(cat "$GX_INSTALL_ROOT/native-mod-data/tdhd/.hashes")"
if bash "$BACKEND" native-mod tdhd > "$GX_INSTALL_ROOT/invalid-remaster-test.log" 2>&1; then echo 'Corrupt MEG was accepted'; exit 1; fi
[[ "$previous" == "$(cat "$GX_INSTALL_ROOT/native-mod-data/tdhd/.hashes")" ]]
echo 'Native mod setup, archive validation, Steam routing, isolated profiles, dummy launches, hosting opt-in, settings preservation and failed-repair preservation passed. No real Steam authentication or games.'
