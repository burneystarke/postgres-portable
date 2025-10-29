#!/bin/bash
set -e

# Configure pgBackRest
STANZA=${PGBACKREST_STANZA:-database}
FULL_CRON=${PGBR_FULLCRON:-0 3 * * 0}
INCR_CRON=${PGBR_INCRCRON:-0 3 * * 1-6}



#If there isn't already a pgbackrest.conf then configure one
if [ ! -e /etc/pgbackrest.conf ]; then
cat > /etc/pgbackrest.conf <<EOF
[${STANZA}]
pg1-path=/var/lib/postgresql/data
pg1-user=${POSTGRES_USER}
[global]
repo1-type=s3
repo1-path=${REPO1_PATH:-/db}
repo1-s3-bucket=${REPO1_S3_BUCKET}
repo1-s3-endpoint=${REPO1_S3_ENDPOINT}
repo1-s3-region=auto
repo1-s3-key=${REPO1_S3_KEY}
repo1-s3-key-secret=${REPO1_S3_KEY_SECRET}
repo1-retention-full=${PGBR_RETENTION:-1}
repo1-s3-uri-style=path
compress-type=zst
start-fast=y
process-max=4
archive-async=y
log-level-console=info
EOF
fi
chown postgres:postgres /etc/pgbackrest.conf

#Configure crontab
if [ ! -e /crontabs/postgres ]; then
cat > /crontabs/postgres <<EOC
$FULL_CRON pgbackrest --stanza=$STANZA backup --type=full
$INCR_CRON pgbackrest --stanza=$STANZA backup --type=incr
EOC
fi

# Check for empty data directory (excluding config files)
data_files=$(ls -A /var/lib/postgresql/data | wc -l)
if [ "$data_files" -eq 0 ]; then
    echo "Initializing database with pgBackRest restore..."
    # Attempt restore
    if pgbackrest restore --stanza=${STANZA} --log-level-console=info; then
        echo "Restore completed successfully"
    else
        echo "Restore failed, proceeding with normal startup"
    fi
fi
#Start crond
crond -b -c /crontabs/

# Chain entrypoint if ENV provided
if [ -f "$ENTRYCHAIN" ] || [ -f "$(command -v "$ENTRYCHAIN" 2>/dev/null)" ]; then
    exec "$ENTRYCHAIN" "$@"
else
    echo "No ENTRYCHAIN env set, or ENTRYCHAIN does not exist"
    exec "$@"
fi