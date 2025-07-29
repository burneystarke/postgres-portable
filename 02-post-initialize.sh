#!/bin/bash
# Set default cron schedules
(



	# Wait for server to be ready
	until pg_isready -U "${POSTGRES_USER}" -d postgres; do
	sleep 1
	done


	FULL_CRON=${PGBR_FULLCRON:-0 3 * * 0}
	INCR_CRON=${PGBR_INCRCRON:-0 3 * * 1-6}
	STANZA=${PGBACKREST_STANZA:-database}




	# Setup pg_cron extension

	psql -o /dev/null -U "$POSTGRES_USER" -d postgres <<-EOSQL
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
       psql -P expanded=auto -U "$POSTGRES_USER" -d postgres  -c 'SELECT jobname,schedule,command FROM cron.job'


	if pgbackrest --stanza="$STANZA"  info | grep error > /dev/null 2>&1; then
	    echo "pgbackrest stanza '$STANZA' not initialized. Creating..."
	    pgbackrest --stanza="$STANZA" stanza-create
            echo "performing initial backup..."
            pgbackrest --stanza="$STANZA" backup
	else
	    echo "pgbackrest stanza '$STANZA' already initialized."
	fi


) &

