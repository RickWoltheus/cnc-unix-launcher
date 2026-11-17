#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
server=''
trap '[[ -z "$server" ]] || kill "$server" 2>/dev/null; rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/site/upstream" "$TEST_ROOT/site/mirror" "$TEST_ROOT/resources/manifests" "$TEST_ROOT/cache"
printf 'pinned runtime' > "$TEST_ROOT/site/mirror/runtime.tar"
printf 'replaced upstream' > "$TEST_ROOT/site/upstream/replaced.tar"
cp "$TEST_ROOT/site/mirror/runtime.tar" "$TEST_ROOT/site/upstream/present.tar"
python3 -I -c '
import functools, http.server, sys
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
handler.func.log_message = lambda *args: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
open(sys.argv[2], "w").write(str(server.server_address[1]))
server.serve_forever()' "$TEST_ROOT/site" "$TEST_ROOT/port" &
server=$!
for attempt in $(seq 1 50); do [[ -s "$TEST_ROOT/port" ]] && break; sleep 0.1; done
base="http://127.0.0.1:$(cat "$TEST_ROOT/port")"

RESOURCES="$TEST_ROOT/resources" CACHE="$TEST_ROOT/cache"
export GX_DOWNLOAD_MIRROR="$base/mirror"
fail() { printf '%s\n' "$*" >&2; exit 1; }
security_scan_download() { printf '%s\n' "$1" >> "$TEST_ROOT/scanned"; }
source "$REPO/scripts/downloads.sh"
sha="$(checksum_file "$TEST_ROOT/site/mirror/runtime.tar")"
attempt() { (download "$1" "$2" "$3") > "$TEST_ROOT/out" 2>&1; }

attempt present.tar "$base/upstream/present.tar" "$sha"
cmp "$TEST_ROOT/cache/present.tar" "$TEST_ROOT/site/mirror/runtime.tar"
grep -q "/cache/present.tar.part$" "$TEST_ROOT/scanned"

if attempt removed.tar "$base/upstream/missing.tar" "$sha"; then echo 'A removed download without a mirror was accepted.'; exit 1; fi
grep -q '^Download removed: removed.tar is no longer published' "$TEST_ROOT/out"
if attempt offline.tar "http://127.0.0.1:9/runtime.tar" "$sha"; then echo 'An unreachable server was accepted.'; exit 1; fi
grep -q '^Download failed for offline.tar' "$TEST_ROOT/out"
(unset GX_DOWNLOAD_MIRROR; printf 'P\t1\towner/project\n' > "$TEST_ROOT/resources/manifests/product.tsv"
 [[ "$(download_sources https://example.invalid/a "$sha" mod/file.big | tail -n 1)" == "https://github.com/owner/project/releases/download/download-mirror/${sha:0:12}-file.big" ]])
if attempt replaced.tar "$base/upstream/replaced.tar" "$sha"; then echo 'A replaced upstream file was accepted.'; exit 1; fi
grep -q '^Checksum mismatch for replaced.tar' "$TEST_ROOT/out"
[[ ! -e "$TEST_ROOT/cache/replaced.tar" && ! -e "$TEST_ROOT/cache/replaced.tar.part" ]]

for name in removed.tar replaced.tar pinned.tar; do cp "$TEST_ROOT/site/mirror/runtime.tar" "$TEST_ROOT/site/mirror/${sha:0:12}-$name"; done
attempt removed.tar "$base/upstream/missing.tar" "$sha"
grep -q '^Trying mirror for removed.tar' "$TEST_ROOT/out"
cmp "$TEST_ROOT/cache/removed.tar" "$TEST_ROOT/site/mirror/runtime.tar"
attempt replaced.tar "$base/upstream/replaced.tar" "$sha"
cmp "$TEST_ROOT/cache/replaced.tar" "$TEST_ROOT/site/mirror/runtime.tar"

printf 'pinned\tv1\tpinned.tar\t%s\t%s\tbin\n' "$base/upstream/missing.tar" "$sha" > "$TEST_ROOT/resources/manifests/test-packages.tsv"
(download_package test-packages.tsv pinned; [[ "$PACKAGE_VERSION" == v1 && "$PACKAGE_BINARY" == bin ]]) > /dev/null 2>&1
cmp "$TEST_ROOT/cache/pinned.tar" "$TEST_ROOT/site/mirror/runtime.tar"
if (download_package test-packages.tsv unknown) > /dev/null 2>&1; then echo 'An unknown pin was accepted.'; exit 1; fi

python3 -I "$REPO/scripts/pins.py" lint
python3 -I "$REPO/tests/pins-tool.py" 2> "$TEST_ROOT/pins-tool.log" || { cat "$TEST_ROOT/pins-tool.log"; exit 1; }
printf 'Pinned downloads verify SHA-256 from the publisher or a mirror and report removed files separately from network failures. Local server only.\n'
