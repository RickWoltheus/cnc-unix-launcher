#!/bin/bash
compatibility_profile() { awk -F '\t' -v id="$1" '$1==id {found=1} END {exit !found}' "$RESOURCES/manifests/compatibility.tsv"; }
compatibility_metadata() { awk -F '\t' -v id="$1" -v column="$2" '$1==id {print $column}' "$RESOURCES/manifests/games.tsv"; }
compatibility_directory() { printf '%s/%s\n' "$ROOT" "$(compatibility_metadata "$1" 6)"; }
compatibility_select() {
  local row
  row="$(awk -F '\t' -v id="$1" '$1==id {print}' "$RESOURCES/manifests/compatibility.tsv")"
  [[ -n "$row" ]] || fail 'Unknown Wine game.'
  IFS=$'\t' read -r COMPAT_ID COMPAT_EXE COMPAT_INI COMPAT_ARCHIVES <<< "$row"
  COMPAT_GAME="$(compatibility_directory "$1")"
  COMPAT_PLAY="$ROOT/compatibility/$1/game"
  COMPAT_PREFIX="$ROOT/compatibility/$1/prefix"
}
compatibility_package() {
  local row
  row="$(awk -F '\t' -v id="$1" '$1==id {print}' "$RESOURCES/manifests/compatibility-packages.tsv")"
  IFS=$'\t' read -r unused COMPAT_VERSION COMPAT_ARCHIVE COMPAT_URL COMPAT_SHA COMPAT_BINARY <<< "$row"
}
compatibility_wine() { compatibility_package "$PLATFORM"; printf '%s/wine-runtime/%s\n' "$ROOT" "$COMPAT_BINARY"; }
compatibility_game_pids() {
  local profile="${1:-}" id exe rest path
  while IFS=$'\t' read -r id exe rest; do
    [[ -z "$profile" || "$profile" == "$id" ]] || continue
    path="$ROOT/compatibility/$id/game/$exe"
    ps -axo pid=,stat=,args= 2>/dev/null | awk -v path="$path" '
      $2 !~ /[ZE]/ {
        pid=$1; sub(/^[ \t]*[0-9]+[ \t]+[^ \t]+[ \t]+/, "")
        gsub(/\\/, "/"); command=tolower($0); path=tolower(path)
        sub(/^"/, "", command)
        unix=index(command,path)==1; windows=index(command,"z:" path)==1
        end=length(path)+(windows ? 2 : 0)+1
        if ((unix || windows) && (length(command)==end-1 || substr(command,end,1) ~ /[ \t"]/)) print pid
      }'
  done < "$RESOURCES/manifests/compatibility.tsv"
}
compatibility_session() {
  if [[ -n "$(compatibility_game_pids)" ]]; then echo running; return; fi
  local pid phase marker="$ROOT/.compatibility-running"
  [[ -f "$marker" ]] || { echo idle; return; }
  pid="$(head -n 1 "$marker")"; phase="$(sed -n '3p' "$marker")"
  if [[ "$pid" =~ ^[0-9]+$ && ( "$phase" == starting || "$phase" == stopping ) ]] && kill -0 "$pid" 2>/dev/null; then echo starting
  else echo idle; fi
}
compatibility_running() { [[ "$(compatibility_session)" != idle ]]; }
compatibility_clear_marker() {
  local marker="$ROOT/.compatibility-running"
  if [[ "$(head -n 1 "$marker" 2>/dev/null)" == "$$" ]]; then rm -f "$marker"; fi
}
compatibility_stop_helper() {
  local client="$1" attempt
  kill "$client" 2>/dev/null || true
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$client" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$client" 2>/dev/null && kill -KILL "$client" 2>/dev/null || true
  wait "$client" 2>/dev/null || true
}
compatibility_reset_prefix() {
  local profile="$1" server prefix waiter attempt result=0
  prefix="$ROOT/compatibility/$profile/prefix"
  server="$(dirname "$(compatibility_wine)")/wineserver"
  [[ -d "$prefix" && -x "$server" ]] || return 0
  [[ -z "$(compatibility_game_pids "$profile")" ]] || return 1
  WINEPREFIX="$prefix" "$server" -k || result=$?
  [[ "$result" == 0 || "$result" == 1 ]] || return 1
  WINEPREFIX="$prefix" "$server" -w & waiter=$!
  for attempt in $(seq 1 50); do
    kill -0 "$waiter" 2>/dev/null || {
      result=0; wait "$waiter" || result=$?
      [[ "$result" == 0 || "$result" == 1 ]]; return $?
    }
    sleep 0.1
  done
  compatibility_stop_helper "$waiter"
  echo 'This game’s Wine services did not finish cleanup. Retry after closing its windows.' >&2
  return 1
}
compatibility_wait_for_game() {
  local client="$1" profile="$2" seen=0 attempts=0 result=0
  while true; do
    if [[ -n "$(compatibility_game_pids "$profile")" ]]; then
      seen=1
      printf '%s\n%s\nplaying\n' "$$" "$profile" > "$ROOT/.compatibility-running"
    elif [[ "$seen" == 1 ]]; then
      # Wine's start.exe can outlive an exited game. Stop only our launch helper.
      if kill -0 "$client" 2>/dev/null; then
        compatibility_stop_helper "$client"
      else wait "$client" 2>/dev/null || result=$?; fi
      printf '%s\n%s\nstopping\n' "$$" "$profile" > "$ROOT/.compatibility-running"
      compatibility_reset_prefix "$profile" || result=1
      compatibility_clear_marker
      return "$result"
    elif ! kill -0 "$client" 2>/dev/null; then
      wait "$client" 2>/dev/null || result=$?
      compatibility_clear_marker
      return "$result"
    fi
    attempts=$((attempts+1))
    if [[ "$seen" == 0 && "$attempts" -ge 120 ]]; then
      compatibility_stop_helper "$client"
      compatibility_clear_marker
      echo 'Wine did not start a detectable game process. Check the profile log.' >&2
      return 1
    fi
    sleep 0.5
  done
}
compatibility_dependencies_ready() {
  [[ "$PLATFORM" != linux ]] || { command -v /usr/bin/wine >/dev/null && command -v ps >/dev/null; }
}
compatibility_engine_ready() {
  local binary
  compatibility_package "$PLATFORM"
  binary="$ROOT/wine-runtime/$COMPAT_BINARY"
  [[ -x "$binary" && -f "$ROOT/wine-runtime/.version" ]] || return 1
  [[ "$(cat "$ROOT/wine-runtime/.version")" == "$COMPAT_VERSION" ]] || return 1
  compatibility_package ddraw
  [[ -s "$ROOT/cnc-ddraw/ddraw.dll" && "$(cat "$ROOT/cnc-ddraw/.version" 2>/dev/null)" == "$COMPAT_VERSION" ]] || return 1
  compatibility_dependencies_ready
}
compatibility_assets_ready() {
  local id="$1" folder appid manifest file archive archives executable
  compatibility_select "$id"
  folder="$COMPAT_GAME"; appid="$(compatibility_metadata "$id" 5)"
  manifest="$folder/steamapps/appmanifest_$appid.acf"
  steam_manifest_ready "$folder" "$appid" || return 1
  executable="$(find_game_file "$folder" "$COMPAT_EXE")"
  [[ -s "$executable" && "$(head -c 2 "$executable")" == MZ ]] || return 1
  IFS=, read -r -a archives <<< "$COMPAT_ARCHIVES"
  for archive in "${archives[@]}"; do
    file="$(find_game_file "$folder" "$archive")"
    [[ -s "$file" && "$(wc -c < "$file")" -ge 10 ]] || return 1
  done
}
compatibility_install() {
  local binary
  compatibility_dependencies_ready || fail 'Wine system libraries are missing. Use Prepare Linux to install the dependencies in your local terminal.'
  compatibility_package "$PLATFORM"
  download "$COMPAT_ARCHIVE" "$COMPAT_URL" "$COMPAT_SHA"
  mkdir -p "$WORK/wine"
  tar -xJf "$CACHE/$COMPAT_ARCHIVE" -C "$WORK/wine"
  binary="$WORK/wine/$COMPAT_BINARY"
  [[ -x "$binary" ]] || fail 'The Wine archive is missing its executable.'
  if [[ "$PLATFORM" == macos ]]; then
    xattr -dr com.apple.quarantine "$WORK/wine" 2>/dev/null || true
    if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then "$binary" --version; fi
  else "$binary" --version; fi
  printf '%s\n' "$COMPAT_VERSION" > "$WORK/wine/.version"
  compatibility_package ddraw
  download "$COMPAT_ARCHIVE" "$COMPAT_URL" "$COMPAT_SHA"
  mkdir -p "$WORK/ddraw"
  unzip -q "$CACHE/$COMPAT_ARCHIVE" -d "$WORK/ddraw"
  [[ "$(head -c 2 "$WORK/ddraw/ddraw.dll")" == MZ ]] || fail 'cnc-ddraw is not a Windows DLL.'
  printf '%s\n' "$COMPAT_VERSION" > "$WORK/ddraw/.version"
  cp "$RESOURCES/manifests/compatibility-notice.txt" "$WORK/ddraw/LICENSE.txt"
  if [[ -d "$ROOT/wine-runtime" ]]; then mv "$ROOT/wine-runtime" "$WORK/previous-wine"; fi
  if ! mv "$WORK/wine" "$ROOT/wine-runtime"; then
    [[ ! -d "$WORK/previous-wine" ]] || mv "$WORK/previous-wine" "$ROOT/wine-runtime"
    fail 'Wine installation failed; previous runtime restored.'
  fi
  [[ ! -d "$ROOT/cnc-ddraw" ]] || mv "$ROOT/cnc-ddraw" "$WORK/previous-ddraw"
  if ! mv "$WORK/ddraw" "$ROOT/cnc-ddraw"; then
    [[ ! -d "$WORK/previous-ddraw" ]] || mv "$WORK/previous-ddraw" "$ROOT/cnc-ddraw"
    fail 'cnc-ddraw installation failed; previous files restored.'
  fi
  compatibility_engine_ready || fail 'The Wine runtime is incomplete.'
  echo 'Free Wine and cnc-ddraw installed. No game or Wine configuration window was opened.'
}
compatibility_prepare_game() {
  local id="$1" stamp appid original saved ini
  compatibility_select "$id"
  appid="$(compatibility_metadata "$id" 5)"
  stamp="$(cksum "$COMPAT_GAME/steamapps/appmanifest_$appid.acf" | awk '{print $1 ":" $2}')"
  if [[ "$(cat "$COMPAT_PLAY/.steam-version" 2>/dev/null)" != "$stamp" ]]; then
    copy_tree "$COMPAT_GAME" "$WORK/game"
    rm -rf "$WORK/game/steamapps"
    if [[ -d "$COMPAT_PLAY" ]]; then
      for saved in "$COMPAT_PLAY"/*; do
        [[ -f "$saved" ]] || continue
        case "$saved" in *.sav|*.SAV|*.ini|*.INI) copy_file "$saved" "$WORK/game/$(basename "$saved")" ;; esac
      done
      mv "$COMPAT_PLAY" "$WORK/previous-game"
    fi
    printf '%s\n' "$stamp" > "$WORK/game/.steam-version"
    if ! mv "$WORK/game" "$COMPAT_PLAY"; then
      [[ ! -d "$WORK/previous-game" ]] || mv "$WORK/previous-game" "$COMPAT_PLAY"
      fail 'Could not prepare the owned game copy; previous files restored.'
    fi
  fi
  original="$(find_game_file "$COMPAT_PLAY" ddraw.dll)"
  if [[ -n "$original" && ! -f "$COMPAT_PLAY/ddraw.dll.before-launcher" ]]; then copy_file "$original" "$COMPAT_PLAY/ddraw.dll.before-launcher"; fi
  [[ -z "$original" || "$original" == "$COMPAT_PLAY/ddraw.dll" ]] || rm "$original"
  copy_file "$ROOT/cnc-ddraw/ddraw.dll" "$COMPAT_PLAY/ddraw.dll"
  ini="$(find_game_file "$COMPAT_PLAY" ddraw.ini)"
  if [[ -n "$ini" && "$ini" != "$COMPAT_PLAY/ddraw.ini" ]]; then mv "$ini" "$COMPAT_PLAY/ddraw.ini"; fi
  [[ -f "$COMPAT_PLAY/ddraw.ini" ]] || copy_file "$ROOT/cnc-ddraw/ddraw.ini" "$COMPAT_PLAY/ddraw.ini"
}
compatibility_apply_defaults() {
  local profile="$1" ini stamp
  stamp="$ROOT/compatibility/$profile/.safe-settings-v1"
  [[ ! -f "$stamp" ]] || return 0
  compatibility_select "$profile"
  ini="$(find_game_file "$COMPAT_PLAY" "$COMPAT_INI")"
  [[ -n "$ini" ]] || ini="$COMPAT_PLAY/$COMPAT_INI"
  if [[ "$profile" == ra2 || "$profile" == yuri ]]; then
    printf 'GameSpeed\t2\n' > "$WORK/speed.tsv"
    merge_ini_settings "$ini" Options "$WORK/speed.tsv"
    merge_ini_settings "$ini" Skirmish "$WORK/speed.tsv"
    printf 'StretchMovies\tyes\n' > "$WORK/movie.tsv"
    merge_ini_settings "$ini" Video "$WORK/movie.tsv"
    if [[ "$PLATFORM" == macos ]]; then
      printf 'tshack\tfalse\nnoactivateapp\tfalse\nnonexclusive\ttrue\n' > "$WORK/menu.tsv"
      merge_ini_settings "$COMPAT_PLAY/ddraw.ini" "${COMPAT_EXE%.*}" "$WORK/menu.tsv"
    fi
  fi
  touch "$stamp"
}
compatibility_launch() {
  local full=false width=1280 height=720 binary argument profile="$PROFILE"
  compatibility_running && fail 'A Wine game is already running. Quit it before switching games.'
  pgrep -x '(GeneralsX(ZH)?|OpenRA|apphost-arm64)' >/dev/null 2>&1 && fail 'Quit the running game before switching games.'
  compatibility_engine_ready || fail 'Prepare the Wine runtime before playing.'
  compatibility_assets_ready "$profile" || fail 'Download and validate the selected Steam game first.'
  shift 2
  while [[ $# -gt 0 ]]; do
    argument="$1"; shift
    case "$argument" in
      -fullscreen) full=true ;;
      -win) full=false ;;
      -xres|-yres)
        [[ $# -gt 0 && "$1" =~ ^[0-9]+$ && "$1" -ge 640 && "$1" -le 16384 ]] || fail 'Invalid display dimensions.'
        if [[ "$argument" == -xres ]]; then width="$1"; else height="$1"; fi
        shift ;;
      *) fail "Unknown Wine launch option: $argument" ;;
    esac
  done
  mkdir -p "$ROOT/compatibility/$profile" "$ROOT/logs"
  LOCK="$ROOT/.install-lock"
  mkdir "$LOCK" || fail 'Another installation is running.'
  printf '%s\n' "$$" > "$LOCK/pid"
  printf 'launch:%s\n' "$profile" > "$LOCK/kind"
  WORK="$(mktemp -d "$ROOT/.staging.XXXXXX")"
  trap 'rm -rf "$WORK"; if [[ "$(head -n 1 "$LOCK/pid" 2>/dev/null)" == "$$" ]]; then rm -rf "$LOCK"; fi; compatibility_clear_marker' EXIT
  trap 'exit 130' INT TERM
  compatibility_prepare_game "$profile"
  compatibility_apply_defaults "$profile"
  printf 'windowed\ttrue\nfullscreen\t%s\nwidth\t%s\nheight\t%s\nmaintas\ttrue\nsavesettings\t0\n' "$full" "$width" "$height" > "$WORK/display.tsv"
  merge_ini_settings "$COMPAT_PLAY/ddraw.ini" ddraw "$WORK/display.tsv"
  merge_ini_settings "$COMPAT_PLAY/ddraw.ini" "${COMPAT_EXE%.*}" "$WORK/display.tsv"
  # macOS WineHQ has no OpenGL driver; GDI avoids an unavailable renderer.
  if [[ "$PLATFORM" == macos ]]; then
    printf 'renderer\tgdi\n' > "$WORK/renderer.tsv"
    merge_ini_settings "$COMPAT_PLAY/ddraw.ini" ddraw "$WORK/renderer.tsv"
    merge_ini_settings "$COMPAT_PLAY/ddraw.ini" "${COMPAT_EXE%.*}" "$WORK/renderer.tsv"
  fi
  binary="$(compatibility_wine)"
  export WINEPREFIX="$COMPAT_PREFIX" WINEARCH=win64 WINEDLLOVERRIDES='ddraw=n,b;winemenubuilder.exe=d;mscoree,mshtml=d' WINEDEBUG=-all
  printf '%s\n%s\nstarting\n' "$$" "$profile" > "$ROOT/.compatibility-running"
  rm -rf "$LOCK"
  cd "$COMPAT_PLAY"
  local executable
  executable="$(find_game_file "$COMPAT_PLAY" "$COMPAT_EXE")"
  if [[ -n "${GX_LAUNCH_WRAPPER:-}" ]]; then
    /bin/bash "$GX_LAUNCH_WRAPPER" "$executable" > "$ROOT/logs/$profile.log" 2>&1
  else
    compatibility_reset_prefix "$profile" || fail 'Could not clear this game’s old Wine session.'
    if [[ ! -f "$COMPAT_PREFIX/.initialized" ]]; then
      "$binary" wineboot -u > "$ROOT/logs/$profile.log" 2>&1 || fail 'Wine prefix setup failed. Check the profile log.'
      touch "$COMPAT_PREFIX/.initialized"
    fi
    "$binary" "$executable" >> "$ROOT/logs/$profile.log" 2>&1 &
    compatibility_wait_for_game "$!" "$profile"
  fi
  exit $?
}
