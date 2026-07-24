#!/usr/bin/env bash
set -euo pipefail

repository_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_dir"

occ=(docker compose exec --user www-data app php occ)
installed_apps="$("${occ[@]}" app:list --output=json)"

for app_name in memories previewgenerator recognize; do
  if grep -q "\"${app_name}\"" <<<"$installed_apps"; then
    "${occ[@]}" app:enable "$app_name"
  else
    "${occ[@]}" app:install "$app_name"
  fi
done

"${occ[@]}" background:cron
"${occ[@]}" config:system:set maintenance_window_start --type=integer --value=2
"${occ[@]}" config:system:set default_phone_region --value=US

# Use the external Arc-backed VA-API transcoder. These settings remain editable
# through Settings > Administration > Memories after this initial setup.
"${occ[@]}" config:system:set memories.vod.disable --type=boolean --value=false
"${occ[@]}" config:system:set memories.vod.external --type=boolean --value=true
"${occ[@]}" config:system:set memories.vod.connect --value=go-vod:47788
"${occ[@]}" config:system:set memories.vod.vaapi --type=boolean --value=true
"${occ[@]}" config:system:set memories.vod.qf --type=integer --value=24

"${occ[@]}" recognize:download-models

echo "Apps configured. In the Recognize admin page, select CPU mode and four cores."
echo "Test the transcoder in Settings > Administration > Memories before indexing."
