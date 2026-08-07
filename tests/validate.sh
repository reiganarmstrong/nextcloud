#!/usr/bin/env bash
set -euo pipefail

repository_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_dir"

ansible_temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$ansible_temp_dir"' EXIT
export ANSIBLE_LOCAL_TEMP="$ansible_temp_dir/local"
export ANSIBLE_REMOTE_TEMP="$ansible_temp_dir/remote"
mkdir -p "$ANSIBLE_LOCAL_TEMP" "$ANSIBLE_REMOTE_TEMP"

for script_path in scripts/*.sh tests/*.sh; do
  bash -n "$script_path"
done

POSTGRES_PASSWORD_FILE=./secrets/postgres_password.example \
NEXTCLOUD_ADMIN_PASSWORD_FILE=./secrets/nextcloud_admin_password.example \
  docker compose --env-file .env.example config --quiet

grep -Fq \
  'ExecStart=/usr/bin/docker compose --project-directory {{ nextcloud_host_compose_dir }} up --detach' \
  ansible/roles/nextcloud_host/templates/nextcloud-shutdown.service.j2
grep -Fq \
  'TimeoutStartSec={{ nextcloud_host_guard_timeout }}' \
  ansible/roles/nextcloud_host/templates/nextcloud-shutdown.service.j2
grep -Fq \
  'ExecStop=/usr/bin/docker compose --project-directory {{ nextcloud_host_compose_dir }} stop' \
  ansible/roles/nextcloud_host/templates/nextcloud-shutdown.service.j2

if command -v ansible-playbook >/dev/null 2>&1; then
  (
    cd ansible
    ansible-playbook -i inventory.example.yml deploy.yml \
      -e @vars.example.yml --syntax-check
  )
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh tests/*.sh
fi

echo "Static validation passed. Nothing was deployed."
