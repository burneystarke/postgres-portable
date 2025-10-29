#!/bin/sh

su postgres -c "exit $(pgbackrest --stanza=$PGBACKREST_STANZA info | grep 'status: error' | wc -l)"
[ $? -ne 0 ] && echo "pgbackrest is not ready" && exit 1

su postgres -c 'pg_isready --dbname="${POSTGRES_DB}" --username="${POSTGRES_USER}" || [ $? -ne "0" ] && exit 1'
[ $? -ne 0 ] && echo "pg is not ready" && exit 1

CHKSUM_ERROR_COUNT=$(su postgres -c "psql --dbname=${POSTGRES_DB} --username=""${POSTGRES_USER}"" --tuples-only --no-align --command='SELECT COALESCE(SUM(checksum_failures), 0) FROM pg_stat_database'")

if [ "$CHKSUM_ERROR_COUNT" != '0' ]; then
  echo "checksum failure count is $CHKSUM_ERROR_COUNT";
  exit 1
fi
