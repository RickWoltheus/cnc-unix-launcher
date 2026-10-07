#!/bin/bash
prepare_online() {
  local family=generals support
  if compatibility_profile "$PROFILE"; then fail "CnCNet installation and online setup are not supported for Wine profiles yet. Campaign/skirmish support is experimental."; fi
  if native_profile "$PROFILE"; then
    native_ready "$PROFILE" || fail 'Install and validate the selected native mod first.'
    support="$NATIVE_SUPPORT"; family=openra
  elif classic_profile "$PROFILE"; then
    classic_engine_ready "$PROFILE" && assets_ready "$GAME" "$PROFILE" || fail 'Prepare the engine and Steam assets before online setup.'
    support="$ROOT/openra-support"; family=openra
  else
    engine_ready "$ENGINE" && assets_ready "$GAME" "$PROFILE" || fail 'Prepare the engine and Steam assets before online setup.'
    if [[ "$PROFILE" != vanilla && "$PROFILE" != base ]]; then select_mod "$PROFILE"; mod_ready || fail 'Repair the selected mod before online setup.'; fi
  fi
  if [[ "${3:-join}" == host ]]; then
    [[ "$family" == openra ]] || fail 'Automatic router discovery is only configurable for OpenRA profiles.'
    printf 'AdvertiseOnline\tTrue\nDiscoverNatDevices\tTrue\n' > "$WORK/online-settings.tsv"
    merge_yaml_settings "$support/settings.yaml" Server "$WORK/online-settings.tsv"
    echo 'OpenRA hosting discovery enabled in local settings. The engine contacts the router only when it runs; firewall/router approval remains yours.'
  elif [[ "${3:-join}" != join ]]; then fail 'Choose join or host for online preparation.'; fi
  printf '%s\n' "$family local files checked" > "$ROOT/online-$PROFILE.ready"
  echo 'Local online setup prepared. Use Play, then the in-game multiplayer menu. Browser sign-in and real connectivity remain unverified.'
}
