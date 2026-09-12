# nextcloud

`nextcloud:apache` with MariaDB (`mariadb.mariadb.svc.cluster.local`) and MinIO. Exposed via Tailscale.

Mostly for gopro videos.

## Prerequisites

- MariaDB at `mariadb.mariadb.svc.cluster.local
- MinIO with a `nextcloud` bucket (created automatically on first start if the access key has bucket-create permissions)

## Configuration

`credentials.env`:
- `MYSQL_ROOT_PASSWORD` — MariaDB root password (used only by the init container to create the nextcloud DB and user)
- `MYSQL_PASSWORD` — password for the `nextcloud` DB user (generated fresh, not the root password)
- `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` — Nextcloud admin account

`nextcloud-s3.config.php` to configure the Minio/S3 bucket:
- `key`
- `secret`
- `hostname`

`deployment.yaml`:
- `NEXTCLOUD_TRUSTED_DOMAINS` and
- `MYSQL_HOST`

## Deploy

    kubectl apply -k .

Nextcloud initialises on first start. The init container creates the `nextcloud` database and DB user in MariaDB (idempotent — safe on restarts). The main container then runs Nextcloud's setup, which reads `s3.config.php` from the config directory and uses MinIO as the primary object store from the start.

First start is slow (~2 minutes). Watch progress with:

    kubectl logs -n nextcloud deployment/nextcloud -f

## S3 primary storage works

`nextcloud-s3.config.php` is mounted directly into `/var/www/html/config/` as a subPath volume mount.

Nextcloud autoloads all `.php` files in that directory; when `objectstore` is present at install time, all user file data goes to S3 rather than the PVC. The PVC stores only the Nextcloud installation files, apps, and config — not user data (.

Any files uploaded before the S3 is mounted will go to the PVC, and Nextcloud won't fix that automatically. To verify:

    kubectl exec -n nextcloud deployment/nextcloud -- su -s /bin/sh www-data -c 'php occ config:system:get objectstore'

## Cron jobs

Nextcloud requires cron-jobs run from time-to-time. It defaults to AJAX mode, which seems to require lots of browser visits; not so good were I'm using this almost entirely as network filesystem.

`cron-rbac.yaml` and `cronjob.yaml` set up these background jobs, whic `kubectl exec deploy/nextcloud -- php occ background:cron`, using a scoped `ServiceAccount`/`Role` that can only `exec` into pods in the `nextcloud` namespace.

I tried a separate cron-job pod but that requires node affinities and perhaps other complexity that I wanted to ignore, so I decided to just shell in.

On first run it flips `backgroundjobs_mode` to `cron`; if the cron-job ever stops runnign this was probably switched back by something.

Settings -> Administration -> Basic settings in the Nextcloud UI shows the current mode and the last-run of the cronjob

## Backup and recovery

I was hoping for nothing in-cluster to be stateful, but that's where I put the MySQL :(

Nextcloud stores all metadata (users, shares, file trees, app config) in MariaDB, so without it the mess of file chunks on S3 are meaningless.

To recover from a MySQL backup with a fresh PVC, create the DB first: the init container will try to `CREATE DATABASE IF NOT EXISTS` (a no-op since the restored DB already exists). Nextcloud's entrypoint detects an existing installation and skips setup. S3 config is re-injected via the volume mount on every start, so no manual step is needed.

## Non-obvious behaviours

* **MySQL needs to be kept backed-up**

* **DB user creation**:  handled by the init container on every pod start. Nextcloud absolutely insists on owning this

* **Hostnames** `NEXTCLOUD_TRUSTED_DOMAINS` must include every hostname you access Nextcloud from, space-separated. If you add a new domain later: `kubectl exec -n nextcloud deployment/nextcloud -- su -s /bin/sh www-data -c 'php occ config:system:set trusted_domains 1 --value=new.hostname'`

* **subPath** mount and rsync On first start, Nextcloud's entrypoint rsyncs files from `/usr/src/nextcloud` to `/var/www/html`. The `s3.config.php` subPath mount at `/var/www/html/config/s3.config.php` survives this because Kubernetes subPath mounts are bind-mounted at the kernel level and cannot be unlinked by rsync. rsync may log a warning for this file; that is harmless.

* **Redis**: Not included. Nextcloud will use database-based file locking, which is slower but functional. Add Redis if you see locking errors under concurrent access.
