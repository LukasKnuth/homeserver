set -l db_name $argv[1]
set -l db_path "/app/db.sqlite"

# Restore database from newest replica generation
# If succeeds, verify the integrity of the restored database
set -l log (litestream restore -o $db_path $db_name 2>&1; and sqlite3 $db_path "PRAGMA integrity_check" 2>&1)

# Report status and log to healthcheck.io
set -l url "https://hc-ping.com/$HEALTHCHECKS_IO_UUID/$status"
curl -m 20 --retry 5 --data-raw "$(string split0 $log)" $url
