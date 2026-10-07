#!/bin/bash
set -euo pipefail
ulimit -c 0
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# == 1 ]] || { echo 'Usage: tests/classic.sh INSTALLATION_WITH_OPENRA_ENGINES'; exit 2; }
export GX_INSTALL_ROOT="$1"
export GX_LAUNCH_WRAPPER="$REPO/tests/fixtures/record-launch.sh"
python3 "$REPO/tests/fixtures/classic-assets.py" "$REPO" "$GX_INSTALL_ROOT"
for id in cnc ra; do
  bash "$REPO/scripts/backend.sh" import-classic "$id"
  status="$(bash "$REPO/scripts/backend.sh" status)"
  [[ "$status" == *"${id}_assets=ready"* ]]
  bash "$REPO/scripts/backend.sh" launch "$id" -win -xres 1280 -yres 720
  grep -q "arg=Game.Mod=$id" "$GX_INSTALL_ROOT/logs/$id.log"
  grep -q 'arg=Graphics.Mode=Windowed' "$GX_INSTALL_ROOT/logs/$id.log"
  grep -q 'arg=Graphics.WindowedSize=1280,720' "$GX_INSTALL_ROOT/logs/$id.log"
  bash "$REPO/scripts/backend.sh" launch "$id" -fullscreen -xres 2560 -yres 1440
  grep -q 'arg=Graphics.Mode=PseudoFullscreen' "$GX_INSTALL_ROOT/logs/$id.log"
done
if [[ "$(uname -s)" == Darwin ]]; then steam="$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh"
else steam="$GX_INSTALL_ROOT/steamcmd/steamcmd.sh"; export GX_FLATPAK=true; fi
mkdir -p "$(dirname "$steam")"
cat > "$steam" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" > "$GX_INSTALL_ROOT/fixture-steam-arguments"
echo "Success! App fully installed."
FAKE
chmod +x "$steam"
printf 'fixture-account\n' | bash "$REPO/scripts/backend.sh" steam-login ra
arguments="$(cat "$GX_INSTALL_ROOT/fixture-steam-arguments")"
[[ "$arguments" == *2229840* && "$arguments" == *2229830* && "$arguments" == *"$GX_INSTALL_ROOT/RedAlert"* && "$arguments" == *"$GX_INSTALL_ROOT/TiberianDawn"* ]]
[[ "$(cat "$GX_INSTALL_ROOT/steam-ra.status")" == complete ]]
cat > "$steam" <<'FAKE'
#!/bin/bash
echo "ERROR! Failed to install app '2229830' (No subscription)"
exit 1
FAKE
if printf 'fixture-account\n' | bash "$REPO/scripts/backend.sh" steam-login ra; then echo 'Missing ownership was accepted'; exit 1; fi
[[ "$(cat "$GX_INSTALL_ROOT/steam-ra.status")" == no-license ]]
printf damaged > "$GX_INSTALL_ROOT/openra-support/Content/ra/v2/conquer.mix"
if bash "$REPO/scripts/backend.sh" launch ra -win; then echo 'Damaged content was accepted'; exit 1; fi
bash "$REPO/scripts/backend.sh" import-classic ra
before="$(cat "$GX_INSTALL_ROOT/openra-support/Content/ra/.launcher-hashes")"
printf damaged > "$GX_INSTALL_ROOT/RedAlert/main1.mix"
if bash "$REPO/scripts/backend.sh" import-classic ra > "$GX_INSTALL_ROOT/corrupt-import-test.log" 2>&1; then echo 'Corrupt Steam source was accepted'; exit 1; fi
[[ "$before" == "$(cat "$GX_INSTALL_ROOT/openra-support/Content/ra/.launcher-hashes")" ]]
python3 "$REPO/tests/fixtures/classic-assets.py" "$REPO" "$GX_INSTALL_ROOT"
printf damaged > "$GX_INSTALL_ROOT/TiberianDawn/conquer.mix"
if bash "$REPO/scripts/backend.sh" import-classic cnc > "$GX_INSTALL_ROOT/corrupt-copy-test.log" 2>&1; then echo 'Corrupt copied MIX was accepted'; exit 1; fi
echo 'Classic imports, expansion/music/video extraction, per-game readiness, display arguments, corruption checks and failed-import preservation passed. Synthetic assets and dummy launches only.'
