# Local Nextcloud deployment

This repository defines a local-only Nextcloud deployment for an Ubuntu PC
with a Ryzen 5 5600X, 30 GiB of RAM, NVMe storage, and an Intel Arc A750. It is
intended to be safe to publish: runtime data, generated credentials, local
inventory, and Nextcloud's secret-bearing `config.php` are ignored.

No cloud resources, AWS services, remote backups, or disaster-recovery
automation are included. Nothing in this repository was applied to the host.

## Architecture

| Service | Role | Hardware use |
| --- | --- | --- |
| `app` | Nextcloud 33 with Apache and PHP | Ryzen, 2 GiB PHP ceiling, APCu/opcache |
| `cron` | Nextcloud background jobs | Ryzen; runs previews and optional Recognize work |
| `database` | PostgreSQL 17 with checksums and NVMe-oriented tuning | 1 GiB shared buffers, host page cache |
| `redis` | Distributed cache and transactional file locking | Persistent local cache |
| `go-vod` | Memories external video transcoder | Arc A750 through VA-API at `/dev/dri` |

The app listens only on `127.0.0.1:8080`; Tailscale Serve terminates TLS and
publishes it privately to the tailnet as `https://pc.<tailnet>.ts.net`. Do not
forward port 8080 on the router and do not enable Tailscale Funnel.

## Repository layout

| Path | Purpose | Tracked? |
| --- | --- | --- |
| `compose.yaml` | Complete local service topology | Yes |
| `.env.example` | Non-secret version, path, and tuning defaults | Yes |
| `.env` | Local deployment settings | No |
| `secrets/` | Generated password files; only examples are tracked | Real files: no |
| `nextcloud/` | Persistent Nextcloud HTML, apps, configuration, and user data | No |
| `data/` | PostgreSQL and Redis live state | No |
| `config/php/` | PHP and opcache tuning | Yes |
| `scripts/` | Preparation, preflight, app configuration, and OCC helpers | Yes |
| `ansible/` | Optional host shutdown preparation | Yes |
| `docs/` | Deployment and troubleshooting notes | Yes |

## Prepare without deploying

The preparation script only writes ignored files beneath this repository. It
does not contact Docker or alter the host:

```sh
./scripts/prepare.sh
$EDITOR .env
./scripts/preflight.sh
```

`preflight.sh` is read-only. It validates the render device, credential files,
render GID, and resolved Compose model; it does not pull images or create
containers.

This Codex environment could see the Arc A750 at PCI address `2b:00.0` using
the `i915` driver, but `/dev/dri` was not visible in the sandbox. Confirm that
`/dev/dri/renderD128` exists in the real host shell before deployment. The
stack intentionally refuses to start `go-vod` without it.

## Deploy later

No command in this section has been run while constructing the repository.

1. Optionally validate and apply the host role as described in
   [`ansible/README.md`](ansible/README.md).
2. Review the fully resolved model:

   ```sh
   docker compose config
   ```

3. Start the stack:

   ```sh
   docker compose pull
   docker compose up -d
   ```

4. Open the HTTPS URL shown by `tailscale serve status` from a tailnet device
   and sign in with the username
   in `.env` and password in `secrets/nextcloud_admin_password`.
5. Install and configure Memories, Preview Generator, and Recognize:

   ```sh
   ./scripts/configure-apps.sh
   ```

6. In **Settings → Administration → Memories**, test the external transcoder.
   In **Recognize**, select CPU mode and start with four cores, leaving two
   physical cores available for interactive Nextcloud and PostgreSQL work.

See [`docs/deployment.md`](docs/deployment.md) for verification and update
commands. The Compose arrangement follows the
[official Nextcloud image guidance](https://github.com/nextcloud/docker) and
the [Memories recommendation for an external Docker transcoder](https://memories.gallery/hw-transcoding/).

## Host lifecycle

All stateful and working services have explicit stop grace periods. The
optional Ansible role installs a systemd service that runs `docker compose up
--detach` after Docker starts and `docker compose stop` before Docker stops. It
also raises Docker's host-level timeout to 20 minutes. It does not restart
Docker, install drivers, or change Tailscale.

## Secret hygiene

- Never commit `.env`, `data/`, or real files in `secrets/`.
- The initial admin and database passwords use Docker secret files rather than
  plaintext Compose environment values.
- Redis has no published port and is isolated on an internal Docker network.
- Run `./tests/validate.sh` before publishing changes.

This repository was intentionally left uncommitted.
