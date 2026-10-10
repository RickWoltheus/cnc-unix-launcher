#!/bin/bash
steam_webhelper_install() {
  local steam="$1" helper="$RESOURCES/resources/steam-webhelper/steamwebhelper.exe" expected directory target original stamp previous
  expected="$(cat "$RESOURCES/manifests/steam-webhelper.sha256")"
  verify "$helper" "$expected" || fail 'Bundled Steam compatibility helper checksum mismatch.'
  security_scan_download "$helper" "$expected"
  [[ -d "$steam/bin/cef" ]] || return 2
  local found=0
  while IFS= read -r -d '' target; do
    if ! file "$target" | /usr/bin/grep -q 'PE32+'; then
      file "$target" | /usr/bin/grep -q 'PE32 executable' && continue
      fail 'Steam browser executable is incomplete. Let Steam finish updating.'
    fi
    found=1; directory="$(dirname "$target")"; original="$directory/steamwebhelper.cnc-original.exe"; stamp="$directory/.cnc-webhelper.sha256"
    previous="$(cat "$stamp" 2>/dev/null || true)"
    if verify "$target" "$expected" || { [[ "$previous" =~ ^[0-9a-f]{64}$ ]] && verify "$target" "$previous"; }; then
      [[ -s "$original" && "$(head -c 2 "$original")" == MZ ]] || fail 'Steam helper backup is missing. Repair the Steam client before retrying.'
      if verify "$original" "$expected" || { [[ "$previous" =~ ^[0-9a-f]{64}$ ]] && verify "$original" "$previous"; }; then
        fail 'Steam helper backup is not the original Valve executable.'
      fi
    else
      [[ "$(head -c 2 "$target")" == MZ ]] || fail 'Steam browser executable is incomplete. Let Steam finish updating.'
      file "$target" | /usr/bin/grep -q 'PE32+' || fail 'This Steam compatibility helper requires a 64-bit Steam browser.'
      cp "$target" "$original.new"
      mv "$original.new" "$original"
    fi
    cp "$helper" "$target.new"
    mv "$target.new" "$target"
    printf '%s\n' "$expected" > "$stamp"
  done < <(find "$steam/bin/cef" -maxdepth 2 -type f -name steamwebhelper.exe -print0)
  [[ "$found" == 1 ]] || return 2
}
