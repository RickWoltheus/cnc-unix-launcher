#!/bin/bash
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
source "$REPO/scripts/settings.sh"
printf '[Options]\ngamespeed=2\nGameSpeed=3\nMusicVolume=0.8\n[Video]\nStretchMovies=no\n' > "$WORK/game.ini"
printf 'GameSpeed\t2\n' > "$WORK/update.tsv"
merge_ini_settings "$WORK/game.ini" Options "$WORK/update.tsv"
grep -qx 'GameSpeed=2' "$WORK/game.ini" || { echo 'FAIL: canonical game INI key casing lost.' >&2; exit 1; }
[[ "$(grep -ic '^gamespeed=' "$WORK/game.ini")" == 1 ]]
grep -qx 'MusicVolume=0.8' "$WORK/game.ini"
printf 'StretchMovies\tyes\n' > "$WORK/update.tsv"
merge_ini_settings "$WORK/game.ini" Video "$WORK/update.tsv"
grep -qx 'StretchMovies=yes' "$WORK/game.ini"
grep -qx 'GameSpeed=3' "$WORK/game.ini.before-launcher"
echo 'INI case preservation, duplicate replacement and backups passed.'
