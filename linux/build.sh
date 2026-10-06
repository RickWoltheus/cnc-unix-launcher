#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Build this package on x86_64 Linux.' >&2; exit 1; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m PyInstaller --noconfirm --clean --onedir --name GeneralsXLauncher \
  --distpath "$REPO/dist/linux" --workpath "$REPO/.build/linux" --specpath "$REPO/.build/linux" \
  --add-data "$REPO/scripts:share/scripts" --add-data "$REPO/resources:share/resources" \
  --add-data "$REPO/manifests:share/manifests" --add-data "$REPO/LICENSE:share" \
  --copy-metadata PySide6 --copy-metadata PySide6_Essentials --copy-metadata PySide6_Addons --copy-metadata shiboken6 \
  "$REPO/linux/app.py"
cp "$REPO/linux/THIRD-PARTY.md" "$REPO/dist/linux/GeneralsXLauncher/"
cp "$REPO/linux/start-launcher.sh" "$REPO/dist/linux/GeneralsXLauncher/"
chmod +x "$REPO/dist/linux/GeneralsXLauncher/start-launcher.sh"
cp -R "$REPO/linux/licenses" "$REPO/dist/linux/GeneralsXLauncher/"
tar -czf "$REPO/dist/GeneralsX-Launcher-linux-x86_64.tar.gz" -C "$REPO/dist/linux" GeneralsXLauncher
printf 'Built %s\n' "$REPO/dist/GeneralsX-Launcher-linux-x86_64.tar.gz"
