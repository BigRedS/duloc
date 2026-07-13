# nextcloud

`nextcloud:apache` with MariaDB (`mariadb.mariadb.svc.cluster.local`) and MinIO as S3 primary object storage. Exposed via Tailscale. Managed with Kustomize.

## Prerequisites

- MariaDB running and reachable (default assumed at `mariadb.mariadb.svc.cluster.local`)
- MinIO with a `nextcloud` bucket (created automatically on first start if the access key has bucket-create permissions)
- Tailscale operator installed if you want the Tailscale service exposure

## Configuration

Two files are gitignored and must be created from their `.example` counterparts before deploying:

**`credentials.env`** — copy from `credentials.env.example` and fill in:
- `MYSQL_ROOT_PASSWORD` — MariaDB root password (used only by the init container to create the nextcloud DB and user)
- `MYSQL_PASSWORD` — password for the `nextcloud` DB user (generated fresh, not the root password)
- `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` — Nextcloud admin account

**`nextcloud-s3.config.php`** — copy from `nextcloud-s3.config.php.example` and fill in your MinIO/S3 `key`, `secret`, and `hostname`. The `bucket` name can be changed here too; ensure the bucket exists in MinIO or the access key has permission to create it.

In `deployment.yaml`, update `NEXTCLOUD_TRUSTED_DOMAINS` and `MYSQL_HOST` (marked with comments). In `service.yaml`, update the Tailscale hostname annotation.

## Deploy

```
cp credentials.env.example credentials.env
cp nextcloud-s3.config.php.example nextcloud-s3.config.php
# edit both files, then:
kubectl apply -k .
```

Nextcloud initialises on first start. The init container creates the `nextcloud` database and DB user in MariaDB (idempotent — safe on restarts). The main container then runs Nextcloud's setup, which reads `s3.config.php` from the config directory and uses MinIO as the primary object store from the start.

First start is slow (~2 minutes). Watch progress with:

```
kubectl logs -n nextcloud deployment/nextcloud -f
```

## How S3 primary storage works

`nextcloud-s3.config.php` is mounted directly into `/var/www/html/config/` as a Kubernetes subPath volume mount. Nextcloud auto-loads all `.php` files in that directory. When `objectstore` is present at install time, all user file data goes to S3 rather than the PVC. The PVC stores only the Nextcloud installation files, apps, and config — not user data.

**Do not add user files or configure external storage before verifying that `occ config:system:get objectstore` returns your S3 bucket.** If the S3 config is missing on first start, user data will land on the PVC and migration is painful.

To verify after first start:
```
kubectl exec -n nextcloud deployment/nextcloud -- su -s /bin/sh www-data -c 'php occ config:system:get objectstore'
```

## Backup and recovery

**MySQL is the critical backup.** Nextcloud stores all metadata (users, shares, file trees, app config) in MariaDB. S3 holds only content blocks — without the database, the S3 data is effectively orphaned.

To recover from a MySQL backup with a fresh PVC: the init container will try to `CREATE DATABASE IF NOT EXISTS` (a no-op since the restored DB already exists). Nextcloud's entrypoint detects an existing installation and skips setup. S3 config is re-injected via the volume mount on every start, so no manual step is needed.

## Non-obvious behaviours

**DB user creation** is handled by the init container on every pod start using `CREATE USER IF NOT EXISTS` and `GRANT ALL PRIVILEGES` — idempotent, safe to re-run.

**`MYSQL_ROOT_PASSWORD`** in `credentials.env` is used only by the init container. Nextcloud itself only uses `MYSQL_PASSWORD` (the `nextcloud` DB user's password). They should be different.

**`NEXTCLOUD_TRUSTED_DOMAINS`** must include every hostname you access Nextcloud from, space-separated. If you add a new domain later: `kubectl exec -n nextcloud deployment/nextcloud -- su -s /bin/sh www-data -c 'php occ config:system:set trusted_domains 1 --value=new.hostname'`

**subPath mount and rsync**: On first start, Nextcloud's entrypoint rsyncs files from `/usr/src/nextcloud` to `/var/www/html`. The `s3.config.php` subPath mount at `/var/www/html/config/s3.config.php` survives this because Kubernetes subPath mounts are bind-mounted at the kernel level and cannot be unlinked by rsync. rsync may log a warning for this file; that is harmless.

**Redis**: Not included. Nextcloud will use database-based file locking, which is slower but functional. Add Redis if you see locking errors under concurrent access.
