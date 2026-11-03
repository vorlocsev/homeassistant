#!/bin/sh
# Read-only Home Assistant entity audit. Does not export tokens, unique IDs, or states.
set -eu
REG="/config/.storage/core.entity_registry"
DEV="/config/.storage/core.device_registry"
AREA="/config/.storage/core.area_registry"
CFG="/config/.storage/core.config_entries"
OUTPUT="/config/aurora_entity_map.tsv"

for f in "$REG" "$DEV" "$AREA" "$CFG"; do
  if [ ! -r "$f" ]; then
    printf 'ERROR: Cannot read %s\n' "$f" >&2
    exit 1
  fi
done
if ! command -v jq >/dev/null 2>&1; then
  printf 'jq missing. Run: apk add --no-cache jq\n' >&2
  exit 1
fi

jq -r \
  --slurpfile dev "$DEV" \
  --slurpfile area "$AREA" \
  --slurpfile cfg "$CFG" '
  def clean: tostring | gsub("[\\t\\r\\n]"; " ");
  ($dev[0].data.devices | map({key: (.id | tostring), value: .}) | from_entries) as $devices |
  ($area[0].data.areas | map({key: (.id | tostring), value: .}) | from_entries) as $areas |
  ($cfg[0].data.entries | map({key: (.entry_id | tostring), value: .}) | from_entries) as $integrations |
  (["entity_id","platform","integration","integration_title","friendly_name","device","manufacturer","model","area","device_class","entity_category","disabled_by","hidden_by"] | @tsv),
  (.data.entities[] | . as $e |
    ($devices[$e.device_id // ""] // {}) as $d |
    ($areas[$e.area_id // $d.area_id // ""] // {}) as $a |
    ($integrations[$e.config_entry_id // ""] // {}) as $i |
    [
      $e.entity_id,
      ($e.platform // ""),
      ($i.domain // ""),
      ($i.title // ""),
      ($e.name // $e.original_name // ""),
      ($d.name_by_user // $d.name // ""),
      ($d.manufacturer // ""),
      ($d.model // ""),
      ($a.name // ""),
      ($e.device_class // $e.original_device_class // ""),
      ($e.entity_category // ""),
      ($e.disabled_by // ""),
      ($e.hidden_by // "")
    ] | map(clean) | @tsv)
' "$REG" > "$OUTPUT"

printf 'Saved: %s\n' "$OUTPUT"
printf 'Entity registry records: '
awk 'END {print NR-1}' "$OUTPUT"
printf '\nTop integrations:\n'
jq -r '.data.entities | group_by(.platform) | map([length, .[0].platform]) | sort_by(-.[0]) | .[:20][] | "\(.[0])  \(.[1])"' "$REG"
printf '\nTop domains:\n'
jq -r '.data.entities | map(.entity_id | split(".")[0]) | group_by(.) | map([length, .[0]]) | sort_by(-.[0]) | .[:20][] | "\(.[0])  \(.[1])"' "$REG"
printf '\nThis file contains entity and device names, but no credentials, unique IDs or state values. Review it before sharing.\n'