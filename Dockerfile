# Use official PostgreSQL image as base
ARG POSTGRES_IMAGE=postgres:16
ARG ORIGINAL_ENTRYPOINT=docker-entrypoint.sh

FROM ${POSTGRES_IMAGE} AS base
#This is here to cachebust this layer for different base images, echos in run
ARG POSTGRES_IMAGE

# Install dependencies
RUN <<EOR
    echo "Base image ${POSTGRES_IMAGE}";
    set -eux;
    if [ -d /etc/apt ]; then 
    apt-get update && 
    apt-get install -y \
        ca-certificates \
        pgbackrest \
        busybox; 
    rm -rf /var/lib/apt/lists/*; 
    elif [ -d /etc/apk ]; then 
    apk update && 
    apk add --no-cache \
        ca-certificates \
        pgbackrest \
        busybox; 
    fi
EOR

FROM base
ARG ORIGINAL_ENTRYPOINT
ENV ENTRYCHAIN="${ORIGINAL_ENTRYPOINT}"
RUN ln -s $(which busybox) /usr/bin/crond
#Remove this if it exists so entrypoint can honor user volumes and only replace if default
RUN rm /etc/pgbackrest.conf -f
RUN mkdir -p /crontabs /tmp/pgbackrest/ /var/log/pgbackrest && chown -R postgres:postgres /tmp/pgbackrest/ /var/log/pgbackrest

# Copy configuration scripts
COPY postgres-portable-entrypoint.sh /usr/local/bin/
COPY 01-init-pgbackrest-stanza.sh /docker-entrypoint-initdb.d/

# Set permissions
RUN chmod +x /usr/local/bin/postgres-portable-entrypoint.sh \
    /docker-entrypoint-initdb.d/01-init-pgbackrest-stanza.sh

HEALTHCHECK --start-period=20s --interval=30s --retries=5 --timeout=30s CMD exit $(pgbackrest --stanza=$PGBACKREST_STANZA info | grep 'status: error' | wc -l)

#This entrypoint will chain the original/next entrypoint from the ENTRYCHAIN var
ENTRYPOINT ["/usr/local/bin/postgres-portable-entrypoint.sh"]
