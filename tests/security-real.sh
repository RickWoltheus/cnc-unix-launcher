#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${GX_INSTALL_ROOT:?Use a disposable root with freshly prepared official ClamAV definitions}"
CACHE="$ROOT/downloads"
mkdir -p "$CACHE"
fail() { echo "$*" >&2; exit 1; }
source "$REPO/scripts/downloads.sh"
source "$REPO/scripts/security.sh"
export GX_SCAN_DOWNLOADS=1
printf 'Harmless C&C Unix Launcher scanner fixture. No game data.' > "$ROOT/clean-source"
checksum="$(checksum_file "$ROOT/clean-source")"
download clean.txt "file://$ROOT/clean-source" "$checksum"
# Generate the harmless signature at runtime so source archives do not contain it.
python3 - "$ROOT/eicar-source" <<'PYTHON'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(bytes([88, 53, 79, 33, 80, 37, 64, 65, 80, 91, 52, 92, 80, 90, 88, 53, 52, 40, 80, 94, 41, 55, 67, 67, 41, 55, 125, 36, 69, 73, 67, 65, 82, 45, 83, 84, 65, 78, 68, 65, 82, 68, 45, 65, 78, 84, 73, 86, 73, 82, 85, 83, 45, 84, 69, 83, 84, 45, 70, 73, 76, 69, 33, 36, 72, 43, 72, 42, 10]))
PYTHON
checksum="$(checksum_file "$ROOT/eicar-source")"
if (download eicar.txt "file://$ROOT/eicar-source" "$checksum") > "$ROOT/eicar-result.log" 2>&1; then
  fail 'The real scanner did not block the harmless EICAR test signature.'
fi
grep -q 'SECURITY_DETECTION' "$ROOT/eicar-result.log"
[[ ! -f "$CACHE/eicar.txt" && -f "$ROOT/security/blocked/$checksum" ]]
echo 'Real ClamAV and official signatures accepted the clean fixture and blocked the harmless EICAR test before installation. No game or executable fixture was run.'
