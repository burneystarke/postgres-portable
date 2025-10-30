#!/bin/bash
# Create conf.d directory if missing and configure archiving
mkdir -p /var/lib/postgresql/data/conf.d
# Add include_dir if not present
if ! grep -q "include_dir = 'conf.d'" /var/lib/postgresql/data/postgresql.conf; then
    echo "include_dir = 'conf.d'" >> /var/lib/postgresql/data/postgresql.conf
fi

cat > /var/lib/postgresql/data/conf.d/pgbackrest.conf <<EOF
archive_mode = on
archive_command = 'pgbackrest --stanza=${STANZA} archive-push %p'
archive_timeout = ${POSTGRES_ARCHIVE_TIMEOUT}
EOF



if pgbackrest --stanza="$STANZA"  info | grep error > /dev/null 2>&1; then
	echo "pgbackrest stanza '$STANZA' not initialized. Creating..."
	pgbackrest --stanza="$STANZA" stanza-create
		echo "performing initial backup..."
		pgbackrest --stanza="$STANZA" backup
else
	echo "pgbackrest stanza '$STANZA' already initialized."
fi

pgp-update-pgcron.sh
