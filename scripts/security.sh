#!/bin/bash
security_tool() {
  local name="$1" override="" candidate
  if [[ "$name" == clamscan ]]; then override="${GX_CLAMSCAN:-}"
  else override="${GX_FRESHCLAM:-}"; fi
  if [[ -n "$override" ]]; then [[ -x "$override" ]] && printf '%s\n' "$override"; return; fi
  for candidate in "/opt/homebrew/bin/$name" "/usr/local/clamav/bin/$name" "/usr/bin/$name" "/usr/local/bin/$name"; do
    if [[ -x "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
  done
  return 1
}
security_definitions_status() {
  local database="$ROOT/security/clamav-db" updated now
  [[ -s "$database/main.cvd" || -s "$database/main.cld" ]] && [[ -s "$database/daily.cvd" || -s "$database/daily.cld" ]] || { echo missing; return; }
  updated="$(cat "$ROOT/security/definitions-updated" 2>/dev/null || true)"; now="$(date +%s)"
  if [[ "$updated" =~ ^[0-9]+$ && "$updated" -le "$now" && $((now-updated)) -lt 604800 ]]; then echo ready
  else echo outdated; fi
}
security_record() {
  local file="$1" checksum="$2" version="$3" outcome="$4"
  mkdir -p "$ROOT/security"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(basename "$file")" "$checksum" "$version" "$outcome" >> "$ROOT/security/scans.tsv"
}
security_scan_download() {
  local file="$1" checksum="$2" scanner version result=0 report outcome bytes
  [[ ! -f "$ROOT/security/blocked/$checksum" ]] || fail 'SECURITY_DETECTION: This file has a previous threat report. Review the local security reports before installing it.'
  [[ "${GX_SCAN_DOWNLOADS:-0}" == 1 ]] || return 0
  scanner="$(security_tool clamscan)" || fail 'SECURITY_SETUP: Install ClamAV through Security & downloads before enabling scanning.'
  [[ "$(security_definitions_status)" == ready ]] || fail 'SECURITY_SETUP: Update virus definitions through Security & downloads. Definitions must have been checked within seven days.'
  "$scanner" --help 2>/dev/null | grep -F -- '--alert-exceeds-max' >/dev/null || fail 'SECURITY_SETUP: Update ClamAV; this scanner cannot report incomplete archive scans safely.'
  version="$("$scanner" --database="$ROOT/security/clamav-db" --version 2>/dev/null | tr '\n\t' '  ')"
  [[ "$version" == ClamAV*/* ]] || fail 'SECURITY_SETUP: ClamAV could not identify its loaded virus definitions.'
  bytes="$(wc -c < "$file")"
  if [[ "$bytes" -gt 2146435072 ]]; then
    security_record "$file" "$checksum" "$version" incomplete
    fail 'SECURITY_INCOMPLETE: This file exceeds the supported scan size. It was not installed with scanning enabled.'
  fi
  mkdir -p "$ROOT/security/reports"
  report="$ROOT/security/reports/$checksum.log"
  echo "Scanning $(basename "$file") locally with ClamAV…"
  "$scanner" --database="$ROOT/security/clamav-db" --official-db-only=yes --disable-cache \
    --alert-exceeds-max=yes --alert-encrypted=yes --max-filesize=2047M --max-scansize=4095M \
    -- "$file" > "$report" 2>&1 || result=$?
  outcome=error
  if [[ "$result" == 1 ]] && grep ' FOUND' "$report" | grep -vE 'Heuristics\.(Limits\.Exceeded|Encrypted)' >/dev/null; then outcome=detected
  elif grep -qiE 'Heuristics\.(Limits\.Exceeded|Encrypted)|skipped|excluded|WARNING:|ERROR:' "$report"; then outcome=incomplete
  elif [[ "$result" == 0 ]]; then outcome=no-known-threats; fi
  security_record "$file" "$checksum" "$version" "$outcome"
  case "$outcome" in
    no-known-threats) echo 'No known threats detected within scanner limits. This is not a safety guarantee.' ;;
    detected)
      mkdir -p "$ROOT/security/blocked"; cp "$report" "$ROOT/security/blocked/$checksum"
      fail 'SECURITY_DETECTION: ClamAV reported a threat. Installation is blocked; review the local report. No files were uploaded or executed.' ;;
    incomplete) fail 'SECURITY_INCOMPLETE: The scan was incomplete or hit a scanner limit. Installation is blocked while scanning is enabled; review the local report.' ;;
    *) fail 'SECURITY_SCAN_ERROR: ClamAV failed to complete the scan. Installation is blocked while scanning is enabled; review the local report.' ;;
  esac
}
security_update() {
  local updater database="$ROOT/security/clamav-db"
  updater="$(security_tool freshclam)" || fail 'SECURITY_SETUP: Install ClamAV first using Security & downloads.'
  mkdir -p "$database"
  printf 'DatabaseMirror database.clamav.net\nDNSDatabaseInfo current.cvd.clamav.net\n' > "$WORK/freshclam.conf"
  "$updater" --config-file="$WORK/freshclam.conf" --datadir="$database" --stdout || fail 'SECURITY_SETUP: Virus definition update failed. Check the local terminal and retry later.'
  [[ -s "$database/main.cvd" || -s "$database/main.cld" ]] && [[ -s "$database/daily.cvd" || -s "$database/daily.cld" ]] || fail 'SECURITY_SETUP: Virus definitions are incomplete.'
  date +%s > "$ROOT/security/definitions-updated"
  echo 'Official virus definitions updated. Return to Security & downloads.'
}
security_install_tools() {
  if [[ "$PLATFORM" == macos ]]; then
    if [[ -x /opt/homebrew/bin/brew ]]; then /opt/homebrew/bin/brew install clamav
    else
      echo 'Install ClamAV’s official macOS package from the page opening now, then return to the launcher.'
      open 'https://www.clamav.net/downloads'
    fi
  else
    source /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
      *ubuntu*|*debian*|*linuxmint*|*pop*) sudo apt-get update; sudo apt-get install -y clamav clamav-freshclam ;;
      *) fail 'Install clamscan and freshclam through your Linux distribution’s package manager, then return to the launcher.' ;;
    esac
  fi
}
security_scan_cache() {
  local file checksum count=0
  security_tool clamscan >/dev/null || fail 'SECURITY_SETUP: Install ClamAV first using Security & downloads.'
  export GX_SCAN_DOWNLOADS=1
  while IFS= read -r -d '' file; do
    [[ "$file" != *.part ]] || continue
    checksum="$(checksum_file "$file")"
    security_scan_download "$file" "$checksum"
    count=$((count+1))
  done < <(find "$CACHE" -type f -print0)
  echo "Checked $count cached download files. Reports are in the installation folder’s security directory."
}
