# Use official PostgreSQL image as base
ARG POSTGRES_IMAGE=postgres:16
FROM ${POSTGRES_IMAGE}

# Install dependencies
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        ca-certificates \
        curl \
        pgbackrest \
        postgresql-$(pg_config --version | grep -oE '[0-9]+' | head -1)-cron; \
        postgresql-$(pg_config --version | grep -oE '[0-9]+' | head -1)-plsh; \
    rm -rf /var/lib/apt/lists/*

# Create configuration directory
RUN mkdir -p /etc/pgbackrest/conf.d

# Copy configuration scripts
COPY entrypoint.sh /usr/local/bin/
COPY 01-setup-extra.sh /docker-entrypoint-initdb.d/
COPY 02-post-initialize.sh /docker-entrypoint-initdb.d/

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh \
    /docker-entrypoint-initdb.d/01-setup-extra.sh \
    /docker-entrypoint-initdb.d/02-post-initialize.sh

RUN chown -R postgres:postgres /var/log/pgbackrest/

# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
