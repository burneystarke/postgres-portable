# PostgreSQL + pgBackRest Docker Image

A production-ready PostgreSQL Docker image with automated backup capabilities using pgBackRest and S3-compatible storage. Features automatic restore from backups, scheduled backups via pg_cron, and support for multiple PostgreSQL versions.

## Features

- **Automated Backups**: Scheduled full and incremental backups using pgBackRest
- **S3 Integration**: Store backups on any S3-compatible storage (AWS S3, MinIO, R2, etc.)
- **Auto-Restore**: Automatically restore from existing backups on container startup
- **Multiple Versions**: Support for various PostgreSQL versions (12, 13, 14, 15, 16, etc.)
- **Built-in Scheduling**: Uses pg_cron extension for automated backup scheduling
- **Compression**: Efficient backup compression using Zstandard
- **Multi-Architecture**: Supports both AMD64 and ARM64 platforms

## Quick Start

1. **Copy the environment template:**
   ```bash
   cp env.template .env
   ```

2. **Configure your environment variables in `.env`:**
   ```bash
   # Required
   DB_PASSWORD=your_secure_password
   DB_USERNAME=myuser
   DB_DATABASE_NAME=myapp
   REPO1_S3_ENDPOINT=s3.amazonaws.com
   REPO1_S3_BUCKET=my-backup-bucket
   REPO1_S3_KEY=your-access-key
   REPO1_S3_KEY_SECRET=your-secret-key
   ```

3. **Run with Docker Compose:**
   ```yaml
   version: '3.8'
   services:
     postgres:
       image: ghcr.io/burneystarke/postgres-portable:16
       env_file: .env
       environment:
         POSTGRES_DB: ${DB_DATABASE_NAME}
         POSTGRES_USER: ${DB_USERNAME}
         POSTGRES_PASSWORD: ${DB_PASSWORD}
       ports:
         - "5432:5432"
       volumes:
         - postgres_data:/var/lib/postgresql/data
   
   volumes:
     postgres_data:
   ```

4. **Start the container:**
   ```bash
   docker-compose up -d
   ```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_PASSWORD` | PostgreSQL password | `mysecretpassword` |
| `DB_USERNAME` | PostgreSQL username | `myuser` |
| `DB_DATABASE_NAME` | Database name | `myapp` |
| `REPO1_S3_ENDPOINT` | S3 endpoint URL | `s3.amazonaws.com` |
| `REPO1_S3_BUCKET` | S3 bucket name | `my-backup-bucket` |
| `REPO1_S3_KEY` | S3 access key | `AKIAIOSFODNN7EXAMPLE` |
| `REPO1_S3_KEY_SECRET` | S3 secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PGBACKREST_STANZA` | `database` | pgBackRest stanza name |
| `PGBACKREST_FULLCRON` | `0 3 * * 0` | Full backup schedule (Sundays at 3 AM) |
| `PGBACKREST_INCRCRON` | `0 3 * * 1-6` | Incremental backup schedule (Mon-Sat at 3 AM) |
| `PGBACKREST_RETENTION` | `1` | Number of full backups to retain |
| `REPO1_PATH` | `/db` | Repository path in S3 bucket |

## Backup Strategy

The image implements a comprehensive backup strategy:

- **Full Backups**: Complete database backup (default: Sundays at 3 AM)
- **Incremental Backups**: Changed data since last backup (default: Monday-Saturday at 3 AM)
- **Automatic Scheduling**: Uses pg_cron extension for reliable scheduling
- **Retention Policy**: Configurable backup retention (default: 1 full backup cycle)

### Manual Backup Operations

```bash
# Create a full backup
docker exec container_name pgbackrest --stanza=database backup --type=full

# Create an incremental backup
docker exec container_name pgbackrest --stanza=database backup --type=incr

# List available backups
docker exec container_name pgbackrest --stanza=database info

# Restore from backup (container must be stopped)
docker run --rm -v postgres_data:/var/lib/postgresql/data \
  your-image pgbackrest --stanza=database restore
```

## S3-Compatible Storage Examples

### AWS S3
```bash
REPO1_S3_ENDPOINT=s3.amazonaws.com
REPO1_S3_BUCKET=my-postgres-backups
```

### MinIO
```bash
REPO1_S3_ENDPOINT=minio.example.com:9000
REPO1_S3_BUCKET=postgres-backups
```

### Cloudflare R2
```bash
REPO1_S3_ENDPOINT=account-id.r2.cloudflarestorage.com
REPO1_S3_BUCKET=postgres-backups
```

## Building Custom Images

The repository includes a GitHub Actions workflow for building images with different PostgreSQL versions:

### Available Tags
####Standard PostGres####
- `ghcr.io/burneystarke/postgres-portable:16` - PostgreSQL 16
- `ghcr.io/burneystarke/postgres-portable:15` - PostgreSQL 15
- `ghcr.io/burneystarke/postgres-portable:14` - PostgreSQL 14
- `ghcr.io/burneystarke/postgres-portable:12` - PostgreSQL 12
####Immich####
- `ghcr.io/burneystarke/postgres-portable:14-vectorchord0.4.3-pgvectors0.2.0` - Uses ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0 as the base image



### Manual Build

```bash
# Build for PostgreSQL 16
docker build --build-arg POSTGRES_VERSION=16 -t my-postgres:16 .

# Build with custom base image
docker build --build-arg POSTGRES_IMAGE=postgres:15-alpine -t my-postgres:15-alpine .
```

## Disaster Recovery

### Automatic Recovery on Startup

The container automatically attempts to restore from the latest backup if the data directory is empty:

1. Container starts with empty data directory
2. Attempts pgBackRest restore
3. If restore succeeds, starts PostgreSQL with restored data
4. If restore fails, proceeds with normal PostgreSQL initialization

### Manual Recovery Process

1. **Stop the container:**
   ```bash
   docker-compose down
   ```

2. **Remove the data volume:**
   ```bash
   docker volume rm your-project_postgres_data
   ```

3. **Start the container:**
   ```bash
   docker-compose up -d
   ```

The container will automatically restore from the latest backup.

## Monitoring and Logs

### Check Backup Status
```bash
# View backup information
docker exec container_name pgbackrest --stanza=database info

# Check scheduled jobs
docker exec container_name psql -U username -d postgres -c "SELECT * FROM cron.job;"
```

### View Logs
```bash
# Container logs
docker logs container_name

# pgBackRest logs
docker exec container_name cat /var/log/pgbackrest/database-backup.log
```

## Security Considerations

- Store S3 credentials securely (use Docker secrets in production)
- Use strong PostgreSQL passwords
- Restrict S3 bucket access to necessary permissions only
- Enable S3 server-side encryption for backups
- Regularly test backup restoration procedures

## Troubleshooting

### Common Issues

**Backup fails with S3 connection error:**
- Verify S3 credentials and endpoint URL
- Check network connectivity to S3 endpoint
- Ensure S3 bucket exists and is accessible

**Restore fails on startup:**
- Check if backups exist in the S3 bucket
- Verify pgBackRest configuration
- Review container logs for specific error messages

**Scheduled backups not running:**
- Confirm pg_cron extension is installed
- Check cron job configuration: `SELECT * FROM cron.job;`
- Verify PostgreSQL user has necessary permissions

### Getting Help

1. Check container logs: `docker logs container_name`
2. Review pgBackRest logs: `docker exec container_name cat /var/log/pgbackrest/database-backup.log`
3. Test pgBackRest configuration: `docker exec container_name pgbackrest --stanza=database check`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with different PostgreSQL versions
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
