#!/usr/bin/env bash
set -euo pipefail

repository_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_dir"

umask 077
mkdir -p secrets nextcloud data/postgres data/redis

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

for secret_name in postgres_password nextcloud_admin_password; do
  secret_path="secrets/${secret_name}"
  if [[ ! -f "$secret_path" ]]; then
    openssl rand -base64 48 > "$secret_path"
    echo "Generated $secret_path"
  fi
done

chmod 0600 .env secrets/postgres_password secrets/nextcloud_admin_password

if [[ -e /dev/dri/renderD128 ]]; then
  render_gid="$(stat -c '%g' /dev/dri/renderD128)"
  sed -i "s/^RENDER_GID=.*/RENDER_GID=${render_gid}/" .env
  echo "Configured render-device GID $render_gid"
else
  echo "WARNING: /dev/dri/renderD128 is absent; Arc transcoding cannot start." >&2
fi

echo "Prepared local files only. Compose has not been started."
