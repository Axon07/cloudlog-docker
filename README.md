# cloudlog-docker

Unofficial, automatically updated Docker image for [Cloudlog](https://github.com/magicbug/Cloudlog), the web-based amateur radio logging app by magicbug.

The old `2m0sql/cloudlog` image hasn't been updated in years. This one is built straight from the official source and rebuilt automatically whenever a new Cloudlog release is published.

```
ghcr.io/axon07/cloudlog:latest      # newest Cloudlog release (recommended)
ghcr.io/axon07/cloudlog:<version>   # a specific release
ghcr.io/axon07/cloudlog:dev         # newest commit on Cloudlog's master branch
```

A GitHub Action checks upstream every 4 hours and builds automatically when there's a new release or master commit.

Images are built for `linux/amd64` and `linux/arm64`.

## What this image does differently

- **Upgrades actually apply.** On every start, the config folder is refreshed from the new version (including `migration.php`), while your `config.php` and `database.php` are kept. Old images left the stale config in the volume, so database migrations never ran.
- **Empty volumes just work.** Missing default files are seeded into mounted folders, so mounting an empty config folder doesn't break the app.
- **Permissions are fixed on start.** Writable folders are chowned to `www-data` (override with `PUID`/`PGID`).
- **The installer gets out of the way.** Once Cloudlog is configured, `/install` is removed on the next start.
- **PHP 8.2**, with the extensions Cloudlog needs and higher upload/memory limits for large ADIF imports.

## Quick start (docker compose)

```yaml
services:
  cloudlog-db:
    image: mariadb:11
    environment:
      MARIADB_ROOT_PASSWORD: change-me
      MARIADB_DATABASE: cloudlog
      MARIADB_USER: cloudlog
      MARIADB_PASSWORD: change-me-too
    volumes:
      - ./db:/var/lib/mysql
    restart: unless-stopped

  cloudlog:
    image: ghcr.io/axon07/cloudlog:latest
    depends_on: [cloudlog-db]
    ports:
      - "8086:80"
    environment:
      TZ: Etc/UTC   # set to your own timezone
      # BASE_URL: https://log.example.com/
    volumes:
      - ./config:/var/www/html/application/config
      - ./uploads:/var/www/html/uploads
      - ./backup:/var/www/html/backup
      - ./qslcard:/var/www/html/assets/qslcard
      - ./images:/var/www/html/images
    restart: unless-stopped
```

1. Open `http://<host>:8086/` and run the installer. Use `cloudlog-db` as the database host.
2. Restart the Cloudlog container once so the installer folder is removed.

## Unraid

A template is in [`unraid/cloudlog.xml`](unraid/cloudlog.xml). Copy it to `/boot/config/plugins/dockerMan/templates-user/my-Cloudlog.xml`, then go to **Docker → Add Container** and pick **Cloudlog** from the template list.

## Volumes

| Container path | Purpose |
|---|---|
| `/var/www/html/application/config` | `config.php`, `database.php` (other files are refreshed from the image) |
| `/var/www/html/uploads` | ADIF imports, uploads |
| `/var/www/html/backup` | Backup exports |
| `/var/www/html/assets/qslcard` | QSL card images |
| `/var/www/html/images` | eQSL card images |

## Environment

| Variable | Default | Purpose |
|---|---|---|
| `BASE_URL` | – | If set, written into `config.php` on every start |
| `TZ` | – | Container timezone |
| `PUID` / `PGID` | `33` | Owner of writable folders |

## Upgrading

**Back up your database first.** Then pull the new image and recreate the container. After it starts, log in as an admin and check **Admin → Debug** to confirm the version and that migrations are up to date.

## Building it yourself

```
docker build --build-arg CLOUDLOG_REF=master -t cloudlog .
```

`CLOUDLOG_REF` accepts any Cloudlog tag or branch.

The GitHub Action in `.github/workflows/build.yml` checks upstream every 4 hours and only builds when the release or master commit is new. You can also run it manually from the Actions tab, with **force** ticked to rebuild. It also keeps itself alive, because GitHub pauses scheduled workflows on repos with no activity for 60 days.

## License

The files in this repository (Dockerfile, entrypoint, workflow, Unraid template) are MIT licensed. See [LICENSE](LICENSE).

Cloudlog itself is licensed separately by its authors. See [magicbug/Cloudlog](https://github.com/magicbug/Cloudlog/blob/master/LICENSE).

## Credits

Cloudlog is developed by magicbug and contributors. This repo only packages it. Consider [supporting Cloudlog](https://github.com/sponsors/magicbug).

Support for this image goes through this repo's issues, not the Cloudlog project.
