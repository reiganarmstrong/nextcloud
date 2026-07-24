# Ansible host preparation

This small role is justified because Compose cannot control systemd's Docker
shutdown deadline or guarantee that this stack is stopped before Docker. It
does **not** install Docker, start Compose, alter Tailscale, or manage secrets.

The role:

- requires a Debian-family systemd host, Docker Compose, `compose.yaml`, and
  `/dev/dri/renderD128`;
- creates the ignored runtime directories;
- gives Docker 20 minutes to stop all host containers cleanly; and
- installs and arms a oneshot guard whose only shutdown action is
  `docker compose stop`. Starting the guard does not start any container.

Prepare local files:

```sh
cp ansible/inventory.example.yml ansible/inventory.yml
cp ansible/vars.example.yml ansible/vars.yml
```

Validate only:

```sh
cd ansible
ansible-playbook -i inventory.yml deploy.yml -e @vars.yml --syntax-check
ansible-playbook -i inventory.yml deploy.yml -e @vars.yml --check --diff
```

Apply later, only after reviewing the diff:

```sh
ansible-playbook -i inventory.yml deploy.yml -e @vars.yml
```

On another Ubuntu release, remove `ansible_become_exe` from the inventory if
`/usr/bin/sudo.ws` does not exist. No playbook was run while creating this
repository.
