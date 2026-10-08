#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
ROOT="$TEST_ROOT/Install With Spaces"; CACHE="$ROOT/downloads"
mkdir -p "$CACHE" "$ROOT/security/clamav-db"
fail() { echo "$*" >&2; exit 1; }
source "$REPO/scripts/downloads.sh"
source "$REPO/scripts/security.sh"
export GX_CLAMSCAN="$TEST_ROOT/scanner"
export GX_SCAN_DOWNLOADS=1
export GX_FAKE_SCAN_CALLS="$TEST_ROOT/calls"
cat > "$GX_CLAMSCAN" <<'SCANNER'
#!/bin/bash
case " $* " in
  *' --help '*) echo '--alert-exceeds-max' ; exit 0 ;;
  *' --version '*) echo 'ClamAV Fixture/1/test-signatures'; exit 0 ;;
esac
printf '%s\n' "$@" >> "$GX_FAKE_SCAN_CALLS"
case "${GX_FAKE_SCAN_STATE:-clean}" in
  clean) echo "$*: OK"; exit 0 ;;
  detected) echo 'fixture: Eicar-Test-Signature FOUND'; exit 1 ;;
  incomplete) echo 'fixture: Heuristics.Limits.Exceeded.MaxScanSize FOUND'; exit 1 ;;
  skipped) echo 'WARNING: fixture skipped'; exit 0 ;;
  error) echo 'engine failed'; exit 2 ;;
esac
SCANNER
chmod +x "$GX_CLAMSCAN"
printf synthetic > "$ROOT/security/clamav-db/main.cvd"
printf synthetic > "$ROOT/security/clamav-db/daily.cvd"
date +%s > "$ROOT/security/definitions-updated"
printf 'Synthetic reviewed download. No game data.' > "$TEST_ROOT/source"
checksum="$(checksum_file "$TEST_ROOT/source")"
download engine.zip "file://$TEST_ROOT/source" "$checksum"
[[ -f "$CACHE/engine.zip" ]]
grep -q -- '--alert-exceeds-max=yes' "$GX_FAKE_SCAN_CALLS"
grep -q -- '--official-db-only=yes' "$GX_FAKE_SCAN_CALLS"
grep -q -- '--max-filesize=2047M' "$GX_FAKE_SCAN_CALLS"
[[ "$(wc -l < "$ROOT/security/scans.tsv")" -eq 1 ]]
download engine.zip "file://$TEST_ROOT/source" "$checksum"
[[ "$(wc -l < "$ROOT/security/scans.tsv")" -eq 2 ]]
for state in incomplete skipped error; do
  export GX_FAKE_SCAN_STATE="$state"
  if (download "$state.zip" "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/$state.log" 2>&1; then exit 1; fi
  [[ ! -f "$CACHE/$state.zip" ]]
  grep -q 'SECURITY_' "$TEST_ROOT/$state.log"
done
export GX_FAKE_SCAN_STATE=detected
if (download infected.zip "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/detected.log" 2>&1; then exit 1; fi
[[ -f "$ROOT/security/blocked/$checksum" && ! -f "$CACHE/infected.zip" ]]
export GX_SCAN_DOWNLOADS=0
if (download engine.zip "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/blocked.log" 2>&1; then exit 1; fi
grep -q 'previous threat report' "$TEST_ROOT/blocked.log"
rm "$ROOT/security/blocked/$checksum"
export GX_SCAN_DOWNLOADS=1 GX_FAKE_SCAN_STATE=clean
printf '0\n' > "$ROOT/security/definitions-updated"
[[ "$(security_definitions_status)" == outdated ]]
if (download engine.zip "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/stale.log" 2>&1; then exit 1; fi
grep -q 'SECURITY_SETUP' "$TEST_ROOT/stale.log"
date +%s > "$ROOT/security/definitions-updated"
export GX_CLAMSCAN="$TEST_ROOT/missing"
if (download engine.zip "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/missing.log" 2>&1; then exit 1; fi
grep -q 'SECURITY_SETUP' "$TEST_ROOT/missing.log"
export GX_CLAMSCAN="$TEST_ROOT/scanner"
rm "$GX_FAKE_SCAN_CALLS"
printf tampered > "$TEST_ROOT/source"
if (download corrupted.zip "file://$TEST_ROOT/source" "$checksum") > "$TEST_ROOT/corrupt.log" 2>&1; then exit 1; fi
grep -q 'Checksum mismatch' "$TEST_ROOT/corrupt.log"
[[ ! -f "$GX_FAKE_SCAN_CALLS" ]]
echo 'Download scanning gates, cache rescans, blocked hashes, scanner errors/limits, signature freshness and hash-before-scan order passed. Synthetic files and fake scanner only.'
