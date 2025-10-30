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
        postgresql-$(pg_config --version | grep -oE '[0-9]+' | head -1)-cron \
        pgbackrest;
    rm -rf /var/lib/apt/lists/*; 
    elif [ -d /etc/apk ]; then 
        apk update &&
        apk add --no-cache \
        ca-certificates \
        tar;
        pkglibdir=$(pg_config --pkglibdir);
        sharedir=$(pg_config --sharedir);
        #gnutar needed for transform
        #the postgresql pgcron extension puts the extension in the default verison of pg_cron for the distro. This uses tar transforms to put it in the correct place.
        apk fetch -s postgresql-pg_cron | \
            tar -v -xzf - \
            --exclude=".*" \
            --transform="s|.*/lib/postgresql[0-9]*|${pkglibdir:1}|g" \
            --transform="s|.*/share/postgresql[0-9]*|${sharedir:1}|g" \
            -C /;
        #pgbackrest includes whatever version of postgres is default, we don't need that. Also exclude logrotate bundle.
        apk fetch -s pgbackrest | tar -xzf - --exclude="*logrotate*" -C /; 
    fi
EOR

FROM base
ARG ORIGINAL_ENTRYPOINT
ENV ENTRYCHAIN="${ORIGINAL_ENTRYPOINT}"
#Remove this if it exists so entrypoint can honor user volumes and only replace if default
RUN rm /etc/pgbackrest.conf -f
RUN mkdir -p /tmp/pgbackrest/ /var/log/pgbackrest && chown -R postgres:postgres /tmp/pgbackrest/ /var/log/pgbackrest

# Copy configuration scripts
COPY pgp-entrypoint.sh pgp-healthcheck.sh pgp-update-pgcron.sh /usr/local/bin/
COPY pgp-init.sh /docker-entrypoint-initdb.d/

# Set permissions
RUN chmod +x /usr/local/bin/pgp-*.sh \
    /docker-entrypoint-initdb.d/pgp-init.sh 

HEALTHCHECK --interval=5m --start-interval=5s --start-period=5m CMD /usr/local/bin/pgp-healthcheck.sh

#This entrypoint will chain the original/next entrypoint from the ENTRYCHAIN var
ENTRYPOINT ["/usr/local/bin/pgp-entrypoint.sh"]
