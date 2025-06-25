#!/bin/bash


STANZA=${PGBACKREST_STANZA:-database}


# Create conf.d directory if missing
mkdir -p /var/lib/postgresql/data/conf.d

# Generate PostgreSQL archive config
cat > /var/lib/postgresql/data/conf.d/pgbackrest.conf <<EOF
archive_mode = on
archive_command = 'pgbackrest --stanza=${STANZA} archive-push %p'
EOF

#Generate pg_cron conf
cat > /var/lib/postgresql/data/conf.d/pgcron.conf <<EOF
shared_preload_libraries = 'pg_cron'
EOF


# Add include_dir if not present
if ! grep -q "include_dir = 'conf.d'" /var/lib/postgresql/data/postgresql.conf; then
    echo "include_dir = 'conf.d'" >> /var/lib/postgresql/data/postgresql.conf
fi
