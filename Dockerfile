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
        perl \
        pgbackrest;
    rm -rf /var/lib/apt/lists/*; 
    elif [ -d /etc/apk ]; then 
        apk update &&
        apk add --no-cache \
        ca-certificates \
        perl \
        pgbackrest;
        apk add --virtual .build-deps build-base llvm19 openssl tar clang19 cmake;
        mkdir /tmp/pg_cron && cd /tmp/pg_cron;
        wget -qO- https://github.com/citusdata/pg_cron/archive/refs/tags/v1.6.7.tar.gz | tar -xvzf - --strip-components 1 -C . && make install;
        cd / && rm -rf /tmp/pg_cron;
        apk del .build-deps;
        #perl uses nonstandard paths in alpine, ln the library somewhere common
        ln -s /usr/lib/perl5/core_perl/CORE/libperl.so /usr/lib/libperl.so;

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
