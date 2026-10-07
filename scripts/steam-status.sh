#!/bin/bash
set -uo pipefail
STATUS_FILE="$1"
last_state=""
missing_license=false
classify() {
  local line="$1" state=""
  case "$line" in
    *InvalidPassword*|*"Invalid password"*|*"Incorrect password"*) state=wrong-password ;;
    *InvalidAccountName*|*"Invalid account name"*) state=wrong-account ;;
    *TwoFactorCodeMismatch*|*InvalidLoginAuthCode*) state=wrong-code ;;
    *ExpiredLoginAuthCode*) state=expired-code ;;
    *RateLimitExceeded*|*AccountLoginDeniedThrottle*|*"too many login"*) state=rate-limited ;;
    *"No subscription"*|*NoSubscription*) state=no-license ;;
    *"Steam Guard"*|*"Waiting for confirmation"*|*"authenticator code"*) state=awaiting-guard ;;
    *"password:"*|*"Password:"*) state=waiting-password ;;
    *"Success! App "*|*"Update state"*) state=downloading ;;
    *"Downloading update"*|*"Extracting package"*) state=updating-steam ;;
    *"Failed to connect"*|*NoConnection*|*ServiceUnavailable*) state=network-error ;;
    *) return ;;
  esac
  [[ "$state" != no-license ]] || missing_license=true
  if [[ "$missing_license" == true ]]; then state=no-license; fi
  if [[ "$state" != "$last_state" ]]; then
    printf '%s\n' "$state" > "$STATUS_FILE"
    last_state="$state"
  fi
}
buffer=""
while IFS= read -r -n 1 character || [[ -n "$character" ]]; do
  if [[ -z "$character" ]]; then classify "$buffer"; buffer=""
  else
    buffer="$buffer$character"
    if [[ ${#buffer} -gt 4096 ]]; then buffer="${buffer: -4096}"; fi
    case "$character" in ':'|')') classify "$buffer" ;; esac
  fi
done
[[ -z "$buffer" ]] || classify "$buffer"
