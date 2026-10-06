#!/bin/bash
set -euo pipefail
PACKAGE="$(cd "$(dirname "$0")" && pwd)"
[[ "$(uname -m)" == x86_64 ]] || { echo 'This package requires x86_64 Linux.' >&2; exit 1; }
command -v ldd >/dev/null || { echo 'Install glibc tools (ldd) before running this package.' >&2; exit 1; }
version="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' || true)"
[[ -n "$version" ]] && [[ "$(printf '%s\n' 2.36 "$version" | sort -V | head -n 1)" == 2.36 ]] || {
  echo 'This package requires glibc 2.36 or newer: Ubuntu 24.04+ or Debian 12+.' >&2; exit 1;
}
missing_libraries() {
  LD_LIBRARY_PATH="$PACKAGE/_internal:$PACKAGE/_internal/PySide6/Qt/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    ldd "$PACKAGE/_internal/PySide6/QtGui.abi3.so" \
        "$PACKAGE/_internal/PySide6/Qt/plugins/platforms/libqxcb.so" \
        "$PACKAGE/_internal/PySide6/Qt/plugins/platforms/libqwayland.so" 2>&1 | awk '/not found/ {print $1}' | sort -u
}
missing="$(missing_libraries)"
if [[ -n "$missing" ]]; then
  printf 'Missing desktop libraries:\n%s\n' "$missing" >&2
  printf 'Ubuntu/Debian fix: sudo apt-get install libgl1 libegl1 libglib2.0-0 libdbus-1-3 libxkbcommon0 libfontconfig1 libxcb-cursor0 libxcb1 libwayland-client0 libwayland-cursor0 libx11-xcb1 libxkbcommon-x11-0 libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 libxcb-xkb1\n' >&2
  [[ "${1:-}" != --check ]] || exit 1
  source /etc/os-release
  case "${ID:-} ${ID_LIKE:-}" in
    *ubuntu*|*debian*|*linuxmint*|*pop*)
      read -r -p 'Install these desktop libraries now? [y/N] ' answer
      [[ "$answer" == y || "$answer" == Y ]] || exit 1
      sudo apt-get update
      sudo apt-get install -y libgl1 libegl1 libglib2.0-0 libdbus-1-3 libxkbcommon0 libfontconfig1 libxcb-cursor0 libxcb1 libwayland-client0 libwayland-cursor0 libx11-xcb1 libxkbcommon-x11-0 libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 libxcb-xkb1
      [[ -z "$(missing_libraries)" ]] || { echo 'Desktop libraries are still missing.' >&2; exit 1; }
      ;;
    *) echo 'Install the missing libraries using your distribution package manager, then retry.' >&2; exit 1 ;;
  esac
fi
[[ "${1:-}" != --check ]] || { echo 'Linux architecture, glibc and desktop libraries passed.'; exit 0; }
exec "$PACKAGE/GeneralsXLauncher" "$@"
