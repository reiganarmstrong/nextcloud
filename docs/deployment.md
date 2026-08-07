# Deployment and operations

## 1. Host preflight

Run these from `/srv/nextcloud` in a normal host shell:

```sh
lspci -nnk | grep -A3 -i 'Arc A750'
ls -l /dev/dri
stat -c 'renderD128 gid=%g mode=%a' /dev/dri/renderD128
docker compose version
```

The Arc must have a kernel driver (`i915` or `xe`) and a render node. The
Compose container provides the userspace VA-API/ffmpeg stack; this repository
therefore does not install graphics packages on the host.

If `/dev/dri` is missing even though `lspci` reports `Kernel driver in use`,
inspect the current boot before changing anything:

```sh
sudo journalctl -b -k | grep -Ei 'i915|xe|drm|dg2|guc|huc'
sudo dmesg | grep -Ei 'i915|xe|drm|dg2|guc|huc'
```

Resolve driver or firmware errors using the Ubuntu-supported packages for the
running kernel. Do not loosen the device to mode `0666`; the Compose service
joins the render device's numeric group instead.

## 2. Local files

```sh
./scripts/prepare.sh
$EDITOR .env
./scripts/preflight.sh
```

Set `NEXTCLOUD_HOSTNAME`, `NEXTCLOUD_OVERWRITE_HOST`, and
`NEXTCLOUD_OVERWRITE_CLI_URL` to the node's full `*.ts.net` DNS name. Keep
`NEXTCLOUD_BIND_ADDRESS=127.0.0.1` so the cleartext backend cannot bypass
Tailscale Serve.

The data path is fixed after first installation. Do not change
`NEXTCLOUD_DATA_LOCATION` later without a planned migration.

## 3. Optional host lifecycle preparation

Follow [`../ansible/README.md`](../ansible/README.md). The role starts the
Compose project when applied and on future boots. Check mode is the right first
run.

## 4. Start and verify

```sh
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=100 app database redis
sudo tailscale serve --bg --https=443 http://127.0.0.1:8080
tailscale serve status
curl --fail https://pc.your-tailnet.ts.net/status.php
```

Then run `./scripts/configure-apps.sh`. The script downloads local-only app
models and configures Arc-backed Memories transcoding; it does not send media
to an AI provider. Verify:

```sh
docker compose logs --tail=100 go-vod
./scripts/occ.sh status
./scripts/occ.sh config:system:get memories.vod.connect
./scripts/occ.sh config:system:get memories.vod.vaapi
```

Use the Memories admin page's test before starting a large index. Recognize
supports the Ryzen through its normal x86/AVX CPU mode; Intel GPU acceleration
is not supported by Recognize, so leave its GPU option disabled.

## Updates

Read the Nextcloud release notes before changing `NEXTCLOUD_VERSION`. Remain on
one major and take patch releases normally:

```sh
docker compose pull
docker compose up -d
./scripts/occ.sh status
./scripts/occ.sh maintenance:repair
```

Never skip a Nextcloud major during an upgrade. PostgreSQL is pinned to major
17 so ordinary pulls cannot perform an implicit database-major upgrade.

## Graceful manual stop

```sh
docker compose stop
```

Do not use `docker compose down -v`; this stack uses bind mounts, but deleting
volumes by habit is still an unsafe operational pattern. The systemd shutdown
guard uses `stop`, not `down`, and respects each service's declared grace
period. The lifecycle service starts the stopped stack again on the next boot.

## Scope

There is intentionally no backup, restore, cloud, AWS, Terraform, failover, or
disaster-recovery implementation here. Decide on a separate local backup plan
before storing the only copy of important data.
