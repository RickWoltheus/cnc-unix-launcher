#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Build this package on x86_64 Linux.' >&2; exit 1; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
IFS=$'\t' read -r PRODUCT_NAME PRODUCT_VERSION PRODUCT_REPO MAC_ARCHIVE LINUX_ARCHIVE EXECUTABLE < "$REPO/manifests/product.tsv"
python3 -m PyInstaller --noconfirm --clean --onedir --name "$EXECUTABLE" \
  --distpath "$REPO/dist/linux" --workpath "$REPO/.build/linux" --specpath "$REPO/.build/linux" \
  --add-data "$REPO/scripts:share/scripts" --add-data "$REPO/resources:share/resources" \
  --add-data "$REPO/manifests:share/manifests" --add-data "$REPO/LICENSE:share" \
  --copy-metadata PySide6 --copy-metadata PySide6_Essentials --copy-metadata PySide6_Addons --copy-metadata shiboken6 \
  "$REPO/linux/app.py"
cp "$REPO/THIRD-PARTY-NOTICES.md" "$REPO/dist/linux/$EXECUTABLE/"
cp "$REPO/linux/THIRD-PARTY.md" "$REPO/dist/linux/$EXECUTABLE/"
cp "$REPO/linux/start-launcher.sh" "$REPO/dist/linux/$EXECUTABLE/"
chmod +x "$REPO/dist/linux/$EXECUTABLE/start-launcher.sh"
cp -R "$REPO/linux/licenses" "$REPO/dist/linux/$EXECUTABLE/"
tar -czf "$REPO/dist/$LINUX_ARCHIVE" -C "$REPO/dist/linux" "$EXECUTABLE"
printf 'Built %s\n' "$REPO/dist/$LINUX_ARCHIVE"
