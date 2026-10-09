#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
compiler="${CNC_WINDOWS_CC:-x86_64-w64-mingw32-gcc}"
"$compiler" "$REPO/resources/steam-webhelper/main.c" -municode -mwindows -O2 -Wall -Wextra -Werror -static -s -Wl,--no-insert-timestamp -o "$REPO/resources/steam-webhelper/steamwebhelper.exe"
if command -v shasum >/dev/null; then shasum -a 256 "$REPO/resources/steam-webhelper/steamwebhelper.exe" | awk '{print $1}' > "$REPO/manifests/steam-webhelper.sha256"
else sha256sum "$REPO/resources/steam-webhelper/steamwebhelper.exe" | awk '{print $1}' > "$REPO/manifests/steam-webhelper.sha256"; fi
