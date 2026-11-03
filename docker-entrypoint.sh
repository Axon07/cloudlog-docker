#!/bin/bash
# Cloudlog container entrypoint
#  - seeds empty volumes with Cloudlog's default files
#  - refreshes config files from the new version on every start
#    (keeps your config.php / database.php) so migrations pick up
#    the new migration_version after an upgrade
#  - removes /install once Cloudlog is configured
#  - fixes ownership so Apache (www-data) can write
set -e

APP=/var/www/html
DEF=/opt/cloudlog-defaults
CFG="$APP/application/config"
PUID="${PUID:-33}"
PGID="${PGID:-33}"

echo "[cloudlog] version $(cat $APP/.cloudlog_version 2>/dev/null) ($(cat $APP/.cloudlog_commit 2>/dev/null))"

# 1. Config: refresh everything except the files the installer writes
mkdir -p "$CFG"
rsync -a --exclude 'config.php' --exclude 'database.php' "$DEF/application/config/" "$CFG/"

# 2. Data volumes: add any missing default files, never overwrite yours
for d in uploads backup images assets/qslcard; do
  mkdir -p "$APP/$d"
  rsync -a --ignore-existing "$DEF/$d/" "$APP/$d/"
done

# 3. Installer: only needed until config.php + database.php exist
if [ -f "$CFG/config.php" ] && [ -f "$CFG/database.php" ]; then
  if [ -d "$APP/install" ]; then
    echo "[cloudlog] configured - removing install directory"
    rm -rf "$APP/install"
  fi
else
  echo "[cloudlog] not configured yet - open the web UI to run the installer, then restart the container"
fi

# 4. Optional: set base_url from env on every start
if [ -n "$BASE_URL" ] && [ -f "$CFG/config.php" ]; then
  sed -i "s#^\(\$config\['base_url'\]\s*=\s*\).*#\1'${BASE_URL}';#" "$CFG/config.php"
fi

# 5. Ownership
for d in application/config application/logs application/cache uploads backup images assets/qslcard assets/json updates; do
  [ -e "$APP/$d" ] && chown -R "$PUID:$PGID" "$APP/$d"
done

exec "$@"
