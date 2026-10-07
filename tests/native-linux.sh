#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Linux ]] || { echo 'Run this test on Linux.' >&2; exit 1; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/native mod check" GX_FLATPAK=true
for id in combined-arms tdhd; do
  if bash "$REPO/scripts/backend.sh" native-mod "$id" > "$SANDBOX/prepare-$id.log" 2>&1; then
    echo 'Fresh native profile unexpectedly had assets.' >&2; exit 1
  fi
  grep -q NATIVE_ASSETS_REQUIRED "$SANDBOX/prepare-$id.log"
done
bash "$REPO/tests/native-mods.sh" "$GX_INSTALL_ROOT"
