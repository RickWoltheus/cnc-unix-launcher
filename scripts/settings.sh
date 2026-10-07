#!/bin/bash
merge_yaml_settings() {
  local destination="$1" section="$2" updates="$3" existing="$WORK/empty-settings"
  touch "$existing"
  if [[ -f "$destination" ]]; then
    existing="$destination"
    [[ -f "$destination.before-launcher" ]] || cp "$destination" "$destination.before-launcher"
  fi
  awk -v section="$section" '
    NR==FNR {split($0, pair, "\t"); values[pair[1]]=pair[2]; next}
    function pending() {for (key in values) if (!written[key]) {print "\t" key ": " values[key]; written[key]=1}}
    /^[^ \t]/ {if (inside) pending(); inside=($0 == section ":"); if (inside) found=1}
    inside && /^[ \t]+[^:]+:/ {
      key=$0; sub(/^[ \t]+/, "", key); sub(/:.*/, "", key)
      if (key in values) {print "\t" key ": " values[key]; written[key]=1; next}
    }
    {print}
    END {if (!found) print "\n" section ":"; pending()}
  ' "$updates" "$existing" > "$WORK/merged-settings.yaml"
  mkdir -p "$(dirname "$destination")"
  mv "$WORK/merged-settings.yaml" "$destination"
}

merge_ini_settings() {
  local destination="$1" section="$2" updates="$3" existing="$WORK/empty-ini"
  touch "$existing"
  if [[ -f "$destination" ]]; then
    existing="$destination"
    [[ -f "$destination.before-launcher" ]] || cp "$destination" "$destination.before-launcher"
  fi
  awk -v section="$section" '
    NR==FNR {split($0,pair,"\t"); values[tolower(pair[1])]=pair[2]; next}
    function pending() {for (key in values) if (!written[key]) {print key "=" values[key]; written[key]=1}}
    {sub(/\r$/, "")}
    /^\[/ {if (inside) pending(); header=$0; sub(/^\[/,"",header); sub(/\].*$/,"",header); inside=(tolower(header)==tolower(section)); if (inside) found=1}
    inside && /^[^;#[][^=]*=/ {
      key=$0; sub(/=.*/,"",key); gsub(/^[ \t]+|[ \t]+$/,"",key); key=tolower(key)
      if (key in values) {if (!written[key]) print key "=" values[key]; written[key]=1; next}
    }
    {print}
    END {if (!found) print "\n[" section "]"; pending()}
  ' "$updates" "$existing" > "$WORK/merged.ini"
  mkdir -p "$(dirname "$destination")"
  mv "$WORK/merged.ini" "$destination"
}
