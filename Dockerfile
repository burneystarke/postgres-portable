# Use official PostgreSQL image as base
ARG POSTGRES_IMAGE=postgres:16
ARG ORIGINAL_ENTRYPOINT=docker-entrypoint.sh

FROM ${POSTGRES_IMAGE}
ARG ORIGINAL_ENTRYPOINT
ENV ENTRYCHAIN="${ORIGINAL_ENTRYPOINT}"

# Install dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        ca-certificates \
        pgbackrest \
        busybox; \
    rm -rf /var/lib/apt/lists/*
RUN ln -s $(which busybox) /usr/bin/crond
RUN mkdir -p /crontabs /tmp/pgbackrest/ /var/log/pgbackrest && chown -R postgres:postgres /tmp/pgbackrest/ /var/log/pgbackrest

# Copy configuration scripts
COPY entrypoint.sh /usr/local/bin/
COPY 01-init-pgbackrest-stanza.sh /docker-entrypoint-initdb.d/

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /docker-entrypoint-initdb.d/01-init-pgbackrest-stanza.sh


# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
