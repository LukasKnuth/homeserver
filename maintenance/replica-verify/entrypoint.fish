# Verifies the SQLite replication by restoring the newest version from the backup
# and running and SQLite integrity check on the result.
# Environment variables:
# - `APP_DB_PATH` set to the full path of the apps database. This is used to identify
#   which datbase to restore and must be the EXACT same as in the Litestream sidecar.
# - `HEALTHCHECKS_IO_URL` the `hc-ping.com` URL with a UUID to call once the verification
#   is completed and has succeeded/failed. The output will be posted there as well.

set -l local_db "/app/db.sqlite"

# Restore database from newest replica generation
# If succeeds, verify the integrity of the restored database
set -l log (litestream restore -o $local_db $APP_DB_PATH 2>&1; and sqlite3 $local_db "PRAGMA integrity_check" 2>&1)

# Report status and log to healthcheck.io
set -l url "$HEALTHCHECKS_IO_URL/$status"
curl -m 20 --retry 5 --data-raw "$(string split0 $log)" $url
