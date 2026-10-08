#!/bin/bash
verify() {
  [[ -f "$1" ]] || return 1
  [[ "$(checksum_file "$1")" == "$2" ]]
}
checksum_file() {
  if command -v shasum >/dev/null; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}
download() {
  local name="$1" url="$2" checksum="$3" target="$CACHE/$1"
  if verify "$target" "$checksum"; then security_scan_download "$target" "$checksum"; printf 'Using verified %s\n' "$name"; return; fi
  printf 'Downloading %s\n' "$name"
  mkdir -p "$(dirname "$target")"
  curl -fL --retry 3 --connect-timeout 20 --max-time 1800 -o "$target.part" "$url"
  verify "$target.part" "$checksum" || fail "Checksum mismatch for $name. Nothing was installed."
  security_scan_download "$target.part" "$checksum"
  mv "$target.part" "$target"
}
