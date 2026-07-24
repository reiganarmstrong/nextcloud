#!/usr/bin/env bash
set -euo pipefail

repository_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_dir"

failures=0

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    failures=$((failures + 1))
  fi
}

require_command docker
require_command openssl

if [[ ! -e /dev/dri/renderD128 ]]; then
  echo "ERROR: /dev/dri/renderD128 is unavailable; check the Intel i915/xe driver." >&2
  failures=$((failures + 1))
fi

for required_file in .env secrets/postgres_password secrets/nextcloud_admin_password; do
  if [[ ! -f "$required_file" ]]; then
    echo "ERROR: missing $required_file (run scripts/prepare.sh)." >&2
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  exit 1
fi

configured_gid="$(sed -n 's/^RENDER_GID=//p' .env)"
actual_gid="$(stat -c '%g' /dev/dri/renderD128)"
if [[ "$configured_gid" != "$actual_gid" ]]; then
  echo "ERROR: RENDER_GID=$configured_gid, but renderD128 uses GID $actual_gid." >&2
  exit 1
fi

docker compose config --quiet
echo "Preflight passed. No containers were created or changed."
