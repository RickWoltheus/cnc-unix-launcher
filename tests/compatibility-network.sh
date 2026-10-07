#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_ROOT="$(mktemp -d)"
trap 'rm -rf "$CACHE_ROOT"' EXIT
platform=linux; [[ "$(uname -s)" != Darwin ]] || platform=macos
for id in "$platform" ddraw; do
  row="$(awk -F '\t' -v id="$id" '$1==id {print}' "$REPO/manifests/compatibility-packages.tsv")"
  IFS=$'\t' read -r unused version archive url checksum binary <<< "$row"
  curl -fL --retry 3 "$url" -o "$CACHE_ROOT/$id"
done
bash "$REPO/tests/compatibility.sh" "$CACHE_ROOT/$platform" "$CACHE_ROOT/ddraw"
