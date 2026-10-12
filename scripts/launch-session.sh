#!/bin/bash
launch_session_register() {
  local previous identity
  if [[ -f "$ROOT/.launch-session" ]]; then
    previous="$(head -n 1 "$ROOT/.launch-session")"
    identity="$(sed -n '3p' "$ROOT/.launch-session")"
    if [[ "$previous" =~ ^[0-9]+$ && -n "$identity" && "$(launch_process_identity "$previous")" == "$identity" ]]; then
      fail 'A launch is still active. Use Stop & retry before playing again.'
    fi
  fi
  mkdir -p "$ROOT"
  identity="$(launch_process_identity "$$")"
  [[ -n "$identity" ]] || fail 'Cannot track the launch process. Check process inspection permissions.'
  (umask 077; printf '%s\n%s\n%s\n' "$$" "$1" "$identity" > "$ROOT/.launch-session.$$")
  mv "$ROOT/.launch-session.$$" "$ROOT/.launch-session"
}
launch_session_stop() {
  local profile="$1" marker="$ROOT/.launch-session" owner identity snapshot pid stamp attempt
  [[ -f "$marker" ]] || return 0
  [[ "$(sed -n '2p' "$marker")" == "$profile" ]] || return 0
  owner="$(head -n 1 "$marker")"; identity="$(sed -n '3p' "$marker")"
  if [[ ! "$owner" =~ ^[0-9]+$ || -z "$identity" || "$(launch_process_identity "$owner")" != "$identity" ]]; then
    rm -f "$marker"; return 0
  fi
  [[ "$owner" != "$$" && "$owner" != "$PPID" ]] || return 1
  snapshot="$(mktemp "$ROOT/.stop-processes.XXXXXX")"
  # Detached Wine processes are handled separately through their profile prefix.
  ps -axo pid=,ppid= | awk -v owner="$owner" '
    {parent[$1]=$2}
    END {for (pid in parent) {node=pid; for (i=0;i<256 && node>1;i++) {
      if (node==owner) {print pid; break} node=parent[node]
    }}}' | while read -r pid; do
      stamp="$(launch_process_identity "$pid")"
      [[ -z "$stamp" ]] || printf '%s\t%s\n' "$pid" "$stamp"
    done > "$snapshot"
  while IFS=$'\t' read -r pid stamp; do
    [[ "$(launch_process_identity "$pid")" != "$stamp" ]] || kill -TERM "$pid" 2>/dev/null || true
  done < "$snapshot"
  sleep 1
  while IFS=$'\t' read -r pid stamp; do
    [[ "$(launch_process_identity "$pid")" != "$stamp" ]] || kill -KILL "$pid" 2>/dev/null || true
  done < "$snapshot"
  rm -f "$snapshot" "$marker"
}
stop_launch() {
  local profile="$1" pid lock="$ROOT/.install-lock"
  launch_session_stop "$profile" || fail 'Could not stop the launch process.'
  if compatibility_profile "$profile"; then
    for pid in $(compatibility_game_pids "$profile"); do compatibility_stop_helper "$pid"; done
    compatibility_reset_prefix "$profile" || fail 'Some game processes remain. Close their windows and retry Stop & retry.'
    if [[ "$PLATFORM" == linux ]] && sage_profile "$profile"; then
      local steam_binary
      steam_binary="$(sage_steam_binary)"
      if [[ -n "$steam_binary" ]]; then
        "$steam_binary" -shutdown >/dev/null 2>&1 </dev/null & pid=$!
        sleep 1
        compatibility_stop_helper "$pid"
      fi
    fi
  fi
  if [[ "$(sed -n '2p' "$ROOT/.compatibility-running" 2>/dev/null)" == "$profile" ]]; then rm -f "$ROOT/.compatibility-running"; fi
  if [[ -f "$lock/pid" && "$(cat "$lock/kind" 2>/dev/null)" == "launch:$profile" ]]; then
    pid="$(cat "$lock/pid")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$lock"; fi
  fi
  if sage_profile "$profile"; then sage_launch_phase "$profile" closed; fi
  echo 'Launch stopped. You can retry Play. Your installed files and saves were kept.'
}
