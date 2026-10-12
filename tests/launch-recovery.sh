#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
ROOT="$TEST_ROOT/Install With Spaces"
RESOURCES="$REPO"
mkdir -p "$ROOT"
owner= outsider=
trap 'kill ${owner:-} ${outsider:-} 2>/dev/null || true; rm -rf "$TEST_ROOT"' EXIT
source "$REPO/scripts/launch-session.sh"
source "$REPO/scripts/compatibility.sh"
sleep 30 & outsider=$!
export ROOT RESOURCES
bash -c 'source "$1/scripts/compatibility.sh"; source "$1/scripts/launch-session.sh"; launch_session_register vanilla; sleep 30 & echo $! > "$ROOT/child.pid"; wait' fixture "$REPO" & owner=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$ROOT/child.pid" ]] && break; sleep .1; done
child="$(cat "$ROOT/child.pid")"
launch_session_stop base
kill -0 "$owner"
launch_session_stop vanilla
wait "$owner" 2>/dev/null || true
if kill -0 "$owner" 2>/dev/null; then echo 'Launch owner survived recovery'; exit 1; fi
kill -0 "$outsider"
if ps -p "$child" -o stat= | grep -qv '^[[:space:]]*Z'; then echo 'Launch child survived recovery'; exit 1; fi
printf '%s\nvanilla\nwrong start time\n' "$outsider" > "$ROOT/.launch-session"
launch_session_stop vanilla
source "$REPO/scripts/compatibility.sh"
compatibility_profile() { [[ "$1" == ra2 ]]; }
sage_profile() { return 1; }
PLATFORM=macos
sleep 30 & related=$!
compatibility_game_pids() { if [[ "$1" == ra2 ]] && kill -0 "$related" 2>/dev/null; then echo "$related"; fi; }
compatibility_reset_prefix() { [[ "$1" == ra2 ]] && echo prefix-cleaned > "$ROOT/prefix-cleaned"; }
mkdir -p "$ROOT/.install-lock"
printf '%s\n' "$owner" > "$ROOT/.install-lock/pid"
printf 'launch:ra2\n' > "$ROOT/.install-lock/kind"
printf '%s\nra2\nstarting\n' "$owner" > "$ROOT/.compatibility-running"
stop_launch ra2
[[ ! -f "$ROOT/.compatibility-running" && ! -d "$ROOT/.install-lock" && -f "$ROOT/prefix-cleaned" ]]
if kill -0 "$related" 2>/dev/null; then echo 'Detached game survived recovery'; exit 1; fi
kill -0 "$outsider"
kill -0 "$outsider"
launch_session_stop vanilla
(
  launch_process_identity() { cat "$ROOT/mock-identity"; }
  kill() { printf '%s\n' "$*" >> "$ROOT/mock-signals"; }
  sleep() { echo replacement > "$ROOT/mock-identity"; }
  echo original > "$ROOT/mock-identity"
  compatibility_stop_helper 999999
  if grep -q KILL "$ROOT/mock-signals"; then echo 'Reused detached PID was force-killed'; exit 1; fi
)
echo 'Launch recovery stops the owned process tree, preserves unrelated/reused PIDs and permits repeated recovery.'
