#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Linux ]] || { echo 'Run this test on Linux.' >&2; exit 1; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export GX_INSTALL_ROOT="$SANDBOX/classic engine check"
if [[ $# == 1 ]]; then
  mkdir -p "$GX_INSTALL_ROOT/downloads"
  cp "$1"/OpenRA-*-x86_64.AppImage "$GX_INSTALL_ROOT/downloads/"
fi
for game in cnc ra; do bash "$REPO/scripts/backend.sh" engine "$game"; done
bash "$REPO/tests/classic.sh" "$GX_INSTALL_ROOT"
