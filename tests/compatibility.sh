#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cnc-wine-check.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export GX_INSTALL_ROOT="$TEST_ROOT/Install With Spaces"
export GX_LAUNCH_WRAPPER="$TEST_ROOT/dummy.sh"
mkdir -p "$GX_INSTALL_ROOT/downloads"
export GX_FLATPAK=/bin/true
platform=macos; [[ "$(uname -s)" != Linux ]] || platform=linux
archive="$(awk -F '\t' -v id="$platform" '$1==id {print $3}' "$REPO/manifests/compatibility-packages.tsv")"
cp "$1" "$GX_INSTALL_ROOT/downloads/$archive"
cp "$2" "$GX_INSTALL_ROOT/downloads/cnc-ddraw-7.1.0.0.zip"
cat > "$GX_LAUNCH_WRAPPER" <<'FIXTURE'
#!/bin/bash
printf 'exe=%s\nprefix=%s\noverrides=%s\ncwd=%s\n' "$1" "$WINEPREFIX" "$WINEDLLOVERRIDES" "$PWD"
FIXTURE
run() { /bin/bash "$REPO/scripts/backend.sh" "$@"; }
run engine ra2
run status | grep 'ra2_engine=ready' >/dev/null
for profile in ra2 yuri ts; do
  directory="$(awk -F '\t' -v id="$profile" '$1==id {print $6}' "$REPO/manifests/games.tsv")"
  appid="$(awk -F '\t' -v id="$profile" '$1==id {print $5}' "$REPO/manifests/games.tsv")"
  game="$GX_INSTALL_ROOT/$directory"
  mkdir -p "$game/steamapps"
  printf '"StateFlags" "4"\n"buildid" "fixture-1"\n' > "$game/steamapps/appmanifest_$appid.acf"
  row="$(awk -F '\t' -v id="$profile" '$1==id {print}' "$REPO/manifests/compatibility.tsv")"
  IFS=$'\t' read -r id exe ini archives <<< "$row"
  printf 'MZsynthetic executable fixture; never executed' > "$game/$exe"
  IFS=, read -r -a files <<< "$archives"
  for name in "${files[@]}"; do printf 'synthetic MIX data; never supplied to engine' > "$game/$name"; done
  printf '[Video]\nScreenWidth=800\n[Player]\nName=Fixture Player\n' > "$game/$ini"
  run status | grep "${profile}_assets=ready" >/dev/null
  run launch "$profile" -win -xres 1280 -yres 720
  play="$GX_INSTALL_ROOT/compatibility/$profile/game"
  if [[ "$profile" == ra2 || "$profile" == yuri ]]; then
    grep -q 'GameSpeed=2' "$play/$ini"
    grep -q 'StretchMovies=yes' "$play/$ini"
    [[ -f "$play/$ini.before-launcher" ]]
    if [[ "$platform" == macos ]]; then
      grep -q 'tshack=false' "$play/ddraw.ini"
      awk -v section="${exe%.*}" '$0=="[" section "]" {inside=1;next} /^\[/ {inside=0} inside && $0=="fixchilds=0" {found=1} END {exit !found}' "$play/ddraw.ini"
    fi
  fi
  grep -q 'windowed=true' "$play/ddraw.ini"
  grep -q 'fullscreen=false' "$play/ddraw.ini"
  grep -q 'width=1280' "$play/ddraw.ini"
  grep -q 'ddraw=n,b' "$GX_INSTALL_ROOT/logs/$profile.log"
  grep -q "prefix=$GX_INSTALL_ROOT/compatibility/$profile/prefix" "$GX_INSTALL_ROOT/logs/$profile.log"
  [[ ! -d "$GX_INSTALL_ROOT/compatibility/$profile/prefix" ]]
  printf 'fixture saved progress' > "$play/mission.sav"
  printf '[Player]\nName=Preserved Player\n' > "$play/$ini"
  printf '"StateFlags" "4"\n"buildid" "fixture-2"\n' > "$game/steamapps/appmanifest_$appid.acf"
  run launch "$profile" -fullscreen -xres 1920 -yres 1080
  grep -q 'Preserved Player' "$play/$ini"
  grep -q 'saved progress' "$play/mission.sav"
  grep -q 'fullscreen=true' "$play/ddraw.ini"
  [[ -f "$play/ddraw.ini.before-launcher" ]]
  if run online-prepare "$profile" > "$TEST_ROOT/online.log" 2>&1; then exit 1; fi
  grep -q 'not supported' "$TEST_ROOT/online.log"
  printf 'broken executable' > "$game/$exe"
  run status | grep "${profile}_assets=missing" >/dev/null
  if run launch "$profile" -win > "$TEST_ROOT/error.log" 2>&1; then exit 1; fi
  grep -q 'Download and validate' "$TEST_ROOT/error.log"
  printf 'MZsynthetic executable fixture; never executed' > "$game/$exe"
done
# A fake Steam client checks routing without credentials or downloads.
steam="$GX_INSTALL_ROOT/steamcmd/MacOS/steamcmd.sh"
[[ "$platform" != linux ]] || steam="$GX_INSTALL_ROOT/steamcmd/steamcmd.sh"
mkdir -p "$(dirname "$steam")"
cat > "$steam" <<'FIXTURE'
#!/bin/bash
printf '%s\n' "$@" > "$GX_INSTALL_ROOT/steam-arguments.txt"
printf "Success! App '%s' fully installed.\n" 'fixture'
FIXTURE
chmod +x "$steam"
for profile in ra2 yuri ts; do
  printf 'fixture-account\n' | run steam-login "$profile"
  appid="$(awk -F '\t' -v id="$profile" '$1==id {print $5}' "$REPO/manifests/games.tsv")"
  grep -qx "$appid" "$GX_INSTALL_ROOT/steam-arguments.txt"
  grep -qx windows "$GX_INSTALL_ROOT/steam-arguments.txt"
  [[ "$(cat "$GX_INSTALL_ROOT/steam-$profile.status")" == complete ]]
done
printf '%s\nra2\nstarting\n' "$$" > "$GX_INSTALL_ROOT/.compatibility-running"
if run engine base > "$TEST_ROOT/running.log" 2>&1; then exit 1; fi
grep -q 'Quit the game' "$TEST_ROOT/running.log"
echo 'Wine installation, Steam routing, isolated profiles, display merge, progress preservation and blocked launch checks passed. No game or sign-in was started.'
