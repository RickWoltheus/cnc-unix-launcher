#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
command -v Xvfb >/dev/null || { echo 'Install Xvfb for this launcher-only virtual-display test.' >&2; exit 1; }
[[ ! -S /tmp/.X11-unix/X98 ]] || { echo 'Display 98 is already in use.' >&2; exit 1; }
Xvfb :98 -screen 0 1280x900x24 -nolisten tcp -ac >/dev/null 2>&1 &
display_pid=$!
trap 'kill "$display_pid" 2>/dev/null || true; wait "$display_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 25); do
  [[ ! -S /tmp/.X11-unix/X98 ]] || break
  sleep 0.2
done
[[ -S /tmp/.X11-unix/X98 ]] || { echo 'Virtual display did not become ready.' >&2; exit 1; }
DISPLAY=:98 QT_QPA_PLATFORM=xcb timeout 30s "$REPO/dist/linux/CnCUnixLauncher/CnCUnixLauncher" --ui-smoke-test
DISPLAY=:98 QT_QPA_PLATFORM=xcb timeout 30s "$REPO/dist/linux/CnCUnixLauncher/CnCUnixLauncher" --steam-guide-smoke-test
