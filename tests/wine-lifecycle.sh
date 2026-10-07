#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
ROOT="$TEST_ROOT/Install With Spaces"
mkdir -p "$ROOT"
RESOURCES="$REPO"
helper_pid= game_pid=
cleanup() {
  [[ -z "$helper_pid" ]] || kill "$helper_pid" 2>/dev/null || true
  [[ -z "$game_pid" ]] || kill "$game_pid" 2>/dev/null || true
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT
source "$REPO/scripts/compatibility.sh"
sleep 30 & helper_pid=$!
printf '%s\n' "$helper_pid" > "$ROOT/.compatibility-running"
if compatibility_running; then
  echo 'FAIL: Wine helper alone incorrectly keeps the game running.' >&2
  exit 1
fi
mkdir -p "$ROOT/compatibility/ra2/game"
if [[ "$(uname -s)" == Darwin ]]; then touch "$ROOT/compatibility/ra2/game/game.exe"
else cp /bin/sleep "$ROOT/compatibility/ra2/game/game.exe"; fi
start_fixture() {
  if [[ "$(uname -s)" == Darwin ]]; then
    exec python3 -c 'import os,sys; os.execv("/bin/sleep", [sys.argv[1], sys.argv[2]])' "$1" "$2"
  else exec "$1" "$2"; fi
}
export -f start_fixture
start_fixture "$ROOT/compatibility/ra2/game/game.exe" 30 & game_pid=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do compatibility_running && break; sleep 0.1; done
compatibility_running || { echo 'FAIL: actual game process was not detected.' >&2; exit 1; }
kill "$game_pid"; wait "$game_pid" 2>/dev/null || true; game_pid=
if compatibility_running; then echo 'FAIL: closed game is still marked running.' >&2; exit 1; fi
kill -0 "$helper_pid"
if [[ "$(uname -s)" == Darwin ]]; then
windows_path="Z:${ROOT//\//\\}\\compatibility\\ra2\\game\\game.exe"
python3 -c 'import os,sys; os.execv("/bin/sleep", [sys.argv[1], "30"])' "$windows_path" & game_pid=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do compatibility_running && break; sleep 0.1; done
compatibility_running || { echo 'FAIL: Wine Windows-style executable path was not detected.' >&2; exit 1; }
kill "$game_pid"; wait "$game_pid" 2>/dev/null || true; game_pid=
fi
kill "$helper_pid"; wait "$helper_pid" 2>/dev/null || true; helper_pid=
# The tracked game exits while its Wine-like helper remains waiting.
cat > "$ROOT/helper.sh" <<'FIXTURE'
#!/bin/bash
start_fixture "$1" 2 &
wait $!
exec sleep 30
FIXTURE
/bin/bash "$ROOT/helper.sh" "$ROOT/compatibility/ra2/game/game.exe" & helper_pid=$!
printf '%s\nra2\nstarting\n' "$$" > "$ROOT/.compatibility-running"
compatibility_wait_for_game "$helper_pid" ra2
helper_pid=
[[ ! -f "$ROOT/.compatibility-running" ]]
# A wrapper that exits before starting a game must preserve its failure code.
/bin/bash -c 'exit 7' & helper_pid=$!
result=0
compatibility_wait_for_game "$helper_pid" ra2 || result=$?
helper_pid=
[[ "$result" == 7 ]]
echo 'Wine lifecycle checks passed: helpers ignored, live game tracked, closure releases wrapper, launch errors preserved. POSIX sleep fixtures only.'
