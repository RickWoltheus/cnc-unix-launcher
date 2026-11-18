#!/bin/bash
verify() {
  [[ -f "$1" ]] || return 1
  [[ "$(checksum_file "$1")" == "$2" ]]
}
checksum_file() {
  if command -v shasum >/dev/null; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}
# Pins are rows of: id, version, archive (cache name), url, SHA-256, binary.
package_row() {
  local row unused
  row="$(awk -F '\t' -v id="$2" '$1==id {print; exit}' "$RESOURCES/manifests/$1")"
  [[ -n "$row" ]] || fail "Download pin $2 is missing from $1."
  IFS=$'\t' read -r unused PACKAGE_VERSION PACKAGE_ARCHIVE PACKAGE_URL PACKAGE_SHA PACKAGE_BINARY <<< "$row"
}
download_package() { package_row "$1" "$2"; download "$PACKAGE_ARCHIVE" "$PACKAGE_URL" "$PACKAGE_SHA"; }
# The publisher's URL first, then this project's mirror copy, named by SHA-256 so
# releases built before a file was mirrored still find it (docs/downloads.md).
download_mirror_base() {
  [[ -z "${GX_DOWNLOAD_MIRROR:-}" ]] || { printf '%s\n' "$GX_DOWNLOAD_MIRROR"; return; }
  printf 'https://github.com/%s/releases/download/download-mirror\n' "$(cut -f3 "$RESOURCES/manifests/product.tsv")"
}
download_sources() { printf '%s\n%s/%s-%s\n' "$1" "$(download_mirror_base)" "${2:0:12}" "${3##*/}"; }
# Returns 2 when the server answered that the file does not exist.
download_fetch() {
  local status code
  code="$(curl -fL --retry 3 --connect-timeout 20 --max-time 1800 -w '%{http_code}' -o "$2" "$1")" && return 0
  status=$?
  [[ "$status" == 22 && ( "$code" == 404 || "$code" == 410 ) ]] && return 2
  return 1
}
download() {
  local name="$1" url="$2" checksum="$3" target="$CACHE/$1" source result tried=0 missing=0 mismatched=0
  if verify "$target" "$checksum"; then security_scan_download "$target" "$checksum"; printf 'Using verified %s\n' "$name"; return; fi
  mkdir -p "$(dirname "$target")"
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    tried=$((tried+1))
    if [[ "$tried" == 1 ]]; then printf 'Downloading %s\n' "$name"; else printf 'Trying mirror for %s\n' "$name"; fi
    rm -f "$target.part"
    result=0; download_fetch "$source" "$target.part" || result=$?
    if [[ "$result" == 0 ]]; then
      if verify "$target.part" "$checksum"; then
        security_scan_download "$target.part" "$checksum"
        mv "$target.part" "$target"
        return
      fi
      mismatched=$((mismatched+1))
    elif [[ "$result" == 2 ]]; then missing=$((missing+1)); fi
  done < <(download_sources "$url" "$checksum" "$name")
  rm -f "$target.part"
  [[ "$mismatched" == 0 ]] || fail "Checksum mismatch for $name. Nothing was installed."
  [[ "$missing" != "$tried" ]] || fail "Download removed: $name is no longer published at its pinned address. Check for a launcher update. Nothing was installed."
  fail "Download failed for $name. Check your internet connection and retry. Nothing was installed."
}
