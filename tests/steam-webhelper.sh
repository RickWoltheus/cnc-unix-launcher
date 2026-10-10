#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
ROOT="$TEST_ROOT/root"; RESOURCES="$REPO"
source "$REPO/scripts/downloads.sh"
source "$REPO/scripts/steam-webhelper.sh"
fail() { printf '%s\n' "$*" >&2; exit 1; }
security_scan_download() { printf '%s\n' "$2" >> "$TEST_ROOT/scans"; }
steam="$TEST_ROOT/Steam With Spaces"; cef="$steam/bin/cef/cef.win64"
mkdir -p "$cef"
fixture() { python3 "$REPO/tests/fixtures/steam-browser.py" "$1" "$2"; }

fixture "$cef/steamwebhelper.exe" 'original-fixture-A'
original_hash="$(checksum_file "$cef/steamwebhelper.exe")"
steam_webhelper_install "$steam"
verify "$cef/steamwebhelper.cnc-original.exe" "$original_hash"
expected="$(cat "$REPO/manifests/steam-webhelper.sha256")"
verify "$cef/steamwebhelper.exe" "$expected"
mkdir -p "$steam/bin/cef/cef.win7"
python3 - "$steam/bin/cef/cef.win7/steamwebhelper.exe" <<'PY'
import struct, sys
from pathlib import Path
body=bytearray(512)
body[:2]=b'MZ'
struct.pack_into('<I',body,0x3c,0x80)
body[0x80:0x84]=b'PE\0\0'
struct.pack_into('<HHIIIHH',body,0x84,0x14c,0,0,0,0,224,0x102)
struct.pack_into('<H',body,0x98,0x10b)
Path(sys.argv[1]).write_bytes(body)
PY
legacy_hash="$(checksum_file "$steam/bin/cef/cef.win7/steamwebhelper.exe")"
steam_webhelper_install "$steam"
verify "$steam/bin/cef/cef.win7/steamwebhelper.exe" "$legacy_hash"
[[ ! -e "$steam/bin/cef/cef.win7/steamwebhelper.cnc-original.exe" ]]
steam_webhelper_install "$steam"
verify "$cef/steamwebhelper.cnc-original.exe" "$original_hash"
fixture "$cef/steamwebhelper.exe" 'updated-fixture-B'
updated_hash="$(checksum_file "$cef/steamwebhelper.exe")"
steam_webhelper_install "$steam"
verify "$cef/steamwebhelper.cnc-original.exe" "$updated_hash"
verify "$cef/steamwebhelper.exe" "$expected"
rm "$cef/steamwebhelper.cnc-original.exe"
if (steam_webhelper_install "$steam") > "$TEST_ROOT/missing.log" 2>&1; then fail 'Missing original accepted.'; fi
grep -q 'backup is missing' "$TEST_ROOT/missing.log"
mkdir -p "$TEST_ROOT/bundled/resources/steam-webhelper" "$TEST_ROOT/bundled/manifests"
printf 'tampered helper' > "$TEST_ROOT/bundled/resources/steam-webhelper/steamwebhelper.exe"
cp "$REPO/manifests/steam-webhelper.sha256" "$TEST_ROOT/bundled/manifests/"
RESOURCES="$TEST_ROOT/bundled"
if (steam_webhelper_install "$steam") > "$TEST_ROOT/tamper.log" 2>&1; then fail 'Tampered bundle accepted.'; fi
grep -q 'checksum mismatch' "$TEST_ROOT/tamper.log"
[[ "$(wc -l < "$TEST_ROOT/scans")" -eq 5 ]]
printf 'Steam helper checksum gate, original preservation, repeated repair and update handling passed. Synthetic PE fixtures; no Steam or games ran.\n'
