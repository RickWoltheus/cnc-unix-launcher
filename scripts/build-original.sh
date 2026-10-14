#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/opt/homebrew/bin:$PATH"
ROOT="$REPO/.build/original"
CACHE="$ROOT/downloads"
RESOURCES="$REPO"
fail() { echo "$*" >&2; exit 1; }
source "$REPO/scripts/downloads.sh"
source "$REPO/scripts/security.sh"
case "$(uname -s)" in Darwin) PLATFORM=macos ;; Linux) PLATFORM=linux ;; *) fail 'Unsupported build platform.' ;; esac
ROOT="$ROOT/$PLATFORM"
source "$REPO/scripts/original.sh"
[[ "$PLATFORM" != linux || "$(uname -m)" == x86_64 ]] || fail 'Build the Linux runtime on x86_64.'
revision="$(awk -F '\t' '$1=="vanilla-conquer" {print $2}' "$REPO/manifests/original-sources.tsv")"
OUTPUT="$REPO/resources/original-runtime"
stamp="$(original_runtime_version)"
if [[ "$(cat "$OUTPUT/.version" 2>/dev/null || true)" == "$stamp" && -x "$OUTPUT/bin/vanillatd" && -x "$OUTPUT/bin/vanillara" ]]; then
  original_verify_runtime "$OUTPUT"
  [[ -s "$OUTPUT/sources/vanilla-conquer-source.tar.gz" && -s "$OUTPUT/sources/SDL2-source.tar.gz" && -s "$OUTPUT/Vanilla-Conquer-LICENSE.txt" && -s "$OUTPUT/SDL2-LICENSE.txt" ]] || fail 'Cached original runtime is missing corresponding source or licenses.'
  exit 0
fi
mkdir -p "$ROOT" "$ROOT/source" "$OUTPUT/bin" "$OUTPUT/lib" "$OUTPUT/sources"
while IFS=$'\t' read -r id version archive url hash; do
  download "$archive" "$url" "$hash"
  mkdir -p "$ROOT/source/$id"
  tar -xzf "$CACHE/$archive" --strip-components=1 -C "$ROOT/source/$id"
  cp "$CACHE/$archive" "$OUTPUT/sources/$archive"
done < "$REPO/manifests/original-sources.tsv"
cp "$REPO/manifests/original-sources.tsv" "$OUTPUT/sources/"
cp "$ROOT/source/vanilla-conquer/License.txt" "$OUTPUT/Vanilla-Conquer-LICENSE.txt"
cp "$ROOT/source/sdl2/LICENSE.txt" "$OUTPUT/SDL2-LICENSE.txt"
prefix="$ROOT/sdl-prefix"
options=()
mapped="-ffile-prefix-map=$ROOT=/usr/src/original-engine -fdebug-prefix-map=$ROOT=/usr/src/original-engine"
if [[ "$PLATFORM" == macos ]]; then options=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0); fi
cmake -S "$ROOT/source/sdl2" -B "$ROOT/sdl-build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_C_FLAGS="$mapped" -DCMAKE_SKIP_RPATH=ON -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF "${options[@]}"
cmake --build "$ROOT/sdl-build" --parallel 4
cmake --install "$ROOT/sdl-build"
# Source archives have no Git metadata; do not discover the launcher's parent repository.
cmake -S "$ROOT/source/vanilla-conquer" -B "$ROOT/engine-build" -DCMAKE_BUILD_TYPE=Release -DMAKE_BUNDLE=OFF -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_CXX_FLAGS="$mapped" -DCMAKE_C_FLAGS="$mapped" -DCMAKE_SKIP_RPATH=ON -DGIT_EXECUTABLE=/usr/bin/false -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "${options[@]}"
cmake --build "$ROOT/engine-build" --parallel 4
cp "$ROOT/engine-build/vanillatd" "$ROOT/engine-build/vanillara" "$OUTPUT/bin/"
cp "$REPO/scripts/build-original.sh" "$OUTPUT/sources/"
if [[ "$PLATFORM" == macos ]]; then
  strip -S "$OUTPUT/bin/vanillatd" "$OUTPUT/bin/vanillara"
else strip --strip-debug "$OUTPUT/bin/vanillatd" "$OUTPUT/bin/vanillara"; fi
if [[ "$PLATFORM" == macos ]]; then
  cp -L "$prefix/lib/libSDL2-2.0.0.dylib" "$OUTPUT/lib/"
  for binary in "$OUTPUT/bin/vanillatd" "$OUTPUT/bin/vanillara"; do
    dependency="$(otool -L "$binary" | awk '/libSDL2/ {print $1}')"
    grep -Fq "SDL2_LIBRARY:FILEPATH=$prefix/" "$ROOT/engine-build/CMakeCache.txt" || fail 'SDL2 was not linked from the pinned build.'
    [[ -n "$dependency" ]] || fail 'SDL2 dependency is missing from the built engine.'
    install_name_tool -change "$dependency" @loader_path/../lib/libSDL2-2.0.0.dylib "$binary"
    codesign --force --sign - "$binary"
  done
  install_name_tool -id @rpath/libSDL2-2.0.0.dylib "$OUTPUT/lib/libSDL2-2.0.0.dylib"
  codesign --force --sign - "$OUTPUT/lib/libSDL2-2.0.0.dylib"
else
  cp -L "$prefix/lib/libSDL2-2.0.so.0" "$OUTPUT/lib/"
fi
printf '%s\n' "$stamp" > "$OUTPUT/.version"
(cd "$OUTPUT"; find bin lib -type f | LC_ALL=C sort | while read -r file; do printf '%s\t%s\n' "$(checksum_file "$file")" "$file"; done) > "$OUTPUT/.hashes"
echo 'Pinned Vanilla Conquer runtime built; corresponding source and licenses included.'
