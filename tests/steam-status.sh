#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
check() {
  printf '%s\n' "$1" | bash "$REPO/scripts/steam-status.sh" "$SANDBOX/status"
  [[ "$(cat "$SANDBOX/status")" == "$2" ]]
}
check 'password:' waiting-password
printf 'password:' | bash "$REPO/scripts/steam-status.sh" "$SANDBOX/status"
[[ "$(cat "$SANDBOX/status")" == waiting-password ]]
check 'Waiting for confirmation in the Steam Guard app' awaiting-guard
check 'FAILED (InvalidPassword)' wrong-password
check 'FAILED (InvalidAccountName)' wrong-account
check 'FAILED (TwoFactorCodeMismatch)' wrong-code
check 'FAILED (ExpiredLoginAuthCode)' expired-code
check 'FAILED (RateLimitExceeded)' rate-limited
check "ERROR! Failed to install app '2732960' (No subscription)" no-license
check 'FAILED (NoConnection)' network-error
check 'Update state (0x61) downloading, progress: 50.0' downloading
check 'Downloading update (1 MB)' updating-steam
check 'Update state (0x61) downloading, progress: 50.0' downloading
printf 'fixture-user\nfixture-private-input\n' | bash "$REPO/scripts/steam-status.sh" "$SANDBOX/status"
[[ "$(cat "$SANDBOX/status")" == downloading ]]
[[ "$(find "$SANDBOX" -type f | wc -l | tr -d ' ')" == 1 ]]
echo 'Steam guidance codes passed; only a status enum was retained, not raw input/output.'
