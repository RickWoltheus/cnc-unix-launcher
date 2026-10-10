#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(mktemp -d)"; RESOURCES="$REPO"; PLATFORM=macos
trap 'rm -rf "$ROOT"' EXIT
source "$REPO/scripts/sage.sh"
compatibility_game_pids() { return 0; }
sage_launch_phase cnc3 steam-update
[[ "$(sage_launch_status cnc3)" == steam-update ]]
if sage_launch_phase cnc3 secret-password; then echo 'Unknown phase accepted'; exit 1; fi
printf 'secret-password\n%s\n' "$$" > "$ROOT/launch-cnc3.status"
[[ "$(sage_launch_status cnc3)" == idle ]]
printf 'starting\n99999999\n' > "$ROOT/launch-cnc3.status"
[[ "$(sage_launch_status cnc3)" == failed ]]
mkdir -p "$ROOT/Steam/logs"
printf 'Old downloading update\nVerification complete\n' > "$ROOT/Steam/logs/bootstrap_log.txt"
if sage_steam_update_state "$ROOT/Steam" 2; then echo 'Old log treated as current update'; exit 1; fi
printf 'Downloading update (20 MB)\nprivate-account-placeholder\n' >> "$ROOT/Steam/logs/bootstrap_log.txt"
sage_steam_update_state "$ROOT/Steam" 2
printf 'Verification complete\n' >> "$ROOT/Steam/logs/bootstrap_log.txt"
if sage_steam_update_state "$ROOT/Steam" 2; then echo 'Finished update still active'; exit 1; fi
printf 'Launch guide phase validation, stale owner and update-state checks passed. No Steam, credentials or games used.\n'
