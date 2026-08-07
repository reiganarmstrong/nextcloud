# Design notes

## Why the community image instead of AIO

Nextcloud AIO is the easiest supported installation for many users, but its
master-container model owns subordinate containers dynamically. The community
image is a better fit for this repository's goal: the database, cache, cron,
hardware transcoder, paths, versions, networks, and stop behavior are all
visible in one reviewable Compose model.

## Hardware allocation

- The Arc A750 is passed only to `go-vod`. Memories recommends an external
  transcoder in Docker, which includes current ffmpeg and VA-API userspace
  drivers without modifying the host.
- PHP has a 2 GiB per-process ceiling and app/cron temporary storage uses
  bounded RAM-backed filesystems. Recognize can use the Ryzen's AVX-capable CPU.
- Recognize should begin at four cores. Its documented Intel GPU support is
  absent, and reserving two physical cores keeps interactive requests smooth.
- PostgreSQL gets 1 GiB shared buffers and a 4 GiB effective-cache estimate.
  Linux can use the rest of the 30 GiB host memory as page cache.
- Database cost and checkpoint defaults favor the local NVMe disk.

No hard CPU quota is set. A quota would prevent burst use of the 5600X and
cannot account for other workloads such as the existing Immich deployment.

## Network boundary

Only the app publishes a host port. PostgreSQL, Redis, and `go-vod` use an
internal Docker network and cannot be reached directly from the LAN. The app
also joins a frontend network so it can reach the Nextcloud app store and
connectivity checks.

The cleartext HTTP backend binds only to loopback. Tailscale Serve is the
tailnet-only reverse proxy and TLS endpoint; Nextcloud's trusted-domain,
trusted-proxy, and overwrite settings describe the resulting HTTPS URL. If the
service is ever exposed beyond the tailnet, use a separately reviewed public
reverse proxy rather than Tailscale Funnel.

## Host lifecycle

The systemd service starts after Docker and runs `docker compose up --detach`,
so a stack explicitly stopped during the previous shutdown is restored at
boot. When Docker or the host stops, reverse ordering stops the service first.
Its `ExecStop` asks Compose to stop the stack, Compose observes service grace
periods, and only then does Docker stop. Docker's own 20-minute systemd
deadline remains longer than the service and every individual service deadline.
