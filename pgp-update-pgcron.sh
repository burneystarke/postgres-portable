#!/bin/bash
# Set default cron schedules
FULL_CRON=${PGBR_FULLCRON:-0 3 * * 0}
INCR_CRON=${PGBR_INCRCRON:-0 3 * * 1-6}
STANZA=${PGBACKREST_STANZA:-database}

#Generate pg_cron conf
cat > /var/lib/postgresql/data/conf.d/pgcron.conf <<EOF
shared_preload_libraries = 'pg_cron'
EOF

	# Setup pg_cron extension

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password --no-psqlrc --db-name "postgres" <<-EOSQL
-- Need to reload config to ensure the shared library is loaded.
SELECT pg_reload_conf();
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS plsh;

-- Create the exec_shell function FIRST
CREATE OR REPLACE FUNCTION exec_shell(command text)
	RETURNS text AS \$func\$
#!/bin/bash
eval "\$1"
\$func\$ LANGUAGE plsh;

-- Drop existing jobs if they exist
DELETE FROM cron.job WHERE jobname IN ('full-backup', 'incr-backup');

-- Schedule full backup
SELECT cron.schedule(
	'full-backup',
	'$FULL_CRON',
	\$\$SELECT exec_shell('pgbackrest --stanza=$STANZA backup --type=full')\$\$
);

-- Schedule incremental backup
SELECT cron.schedule(
	'incr-backup',
	'$INCR_CRON',
	\$\$SELECT exec_shell('pgbackrest --stanza=$STANZA backup --type=incr')\$\$
);
EOSQL
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password --no-psqlrc --db-name "postgres"  -c 'SELECT jobname,schedule,command FROM cron.job'

