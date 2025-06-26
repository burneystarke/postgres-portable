#!/bin/bash
set -e

# Configure pgBackRest
STANZA=${PGBACKREST_STANZA:-database}

# Generate pgBackRest config
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
repo1-retention-full=${PGBACKREST_RETENTION:-1}
repo1-s3-uri-style=path
compress-type=zst
start-fast=y
process-max=4
archive-async=y
log-level-console=info
EOF

mkdir -p /tmp/pgbackrest/
chown -R postgres:postgres /etc/pgbackrest.conf /var/log/pgbackrest/ /tmp/pgbackrest/

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


# Start PostgreSQL normally
exec /usr/local/bin/docker-entrypoint.sh "$@"
