# 🗄️ Database Backup Tool

A lightweight, Docker-based database backup solution that automatically backs up your databases and uploads them to Google Drive using rclone. Supports PostgreSQL, MySQL, MongoDB, and SQLite with streaming backup to avoid disk space issues.

## ✨ Features

- 🚀 **Streaming Backup**: Direct database dump to Google Drive (no local disk usage)
- 🐳 **Docker-based**: Easy deployment and management
- ⏰ **Automated Scheduling**: Cron-based backup scheduling
- 🔐 **Multiple Auth Methods**: File mount or base64 encoded configs
- 📝 **Custom Naming**: Flexible backup filename templates
- 🗑️ **Auto Cleanup**: Configurable retention policies
- 📊 **Multi-DB Support**: PostgreSQL, MySQL, SQLite (MongoDB temporarily removed)
- 🛡️ **Security**: PID-based concurrency control, no plain text secrets

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/lkduy2602/database-backup-tool.git
cd database-backup
```

### 2. Setup Environment

```bash
# Copy environment template
cp env.example .env

# Edit with your database details
nano .env
```

### 3. Configure Rclone

```bash
# Create rclone config locally
rclone config create gdrive drive scope drive --non-interactive

# Choose your method in .env:
# Method 1: File mount (recommended)
# Method 2: Base64 encoded config
```

### 4. Run Backup

```bash
# Manual mode (single backup)
docker-compose up --build

# Automated mode (with cron)
AUTOMATED_BACKUP=true docker-compose up -d --build
```

## 📋 Prerequisites

- **Docker & Docker Compose** installed
- **Database access** (host, port, credentials)
- **Google Drive account** with rclone configured
- **Network access** to both database and Google Drive

## ⚙️ Configuration

### Environment Variables

| Variable                | Required | Description             | Example                                                     |
| ----------------------- | -------- | ----------------------- | ----------------------------------------------------------- |
| `DB_TYPE`               | ✅       | Database type           | `postgres`, `mysql`, `sqlite` (mongodb temporarily removed) |
| `DB_HOST`               | ✅       | Database host           | `localhost`, `192.168.1.100`                                |
| `DB_PORT`               | ✅       | Database port           | `5432`, `3306`, `27017`                                     |
| `DB_NAME`               | ✅       | Database name           | `myapp`, `production_db`                                    |
| `DB_USER`               | ✅       | Database username       | `postgres`, `root`, `admin`                                 |
| `DB_PASSWORD`           | ✅       | Database password       | `secret123`                                                 |
| `RCLONE_REMOTE_PATH`    | ✅       | Google Drive path       | `gdrive:backups/database`                                   |
| `RCLONE_CONFIG_FILE`    | 🔘       | Rclone config file path | `/etc/rclone.conf`                                          |
| `RCLONE_CONFIG_BASE64`  | 🔘       | Base64 encoded config   | `W2dkcml2ZV0K...`                                           |
| `AUTOMATED_BACKUP`      | ❌       | Enable cron scheduling  | `true`, `false`                                             |
| `CRON_SCHEDULE`         | ❌       | Cron schedule           | `0 2 * * *` (daily 2 AM)                                    |
| `BACKUP_RETENTION_DAYS` | ❌       | Days to keep backups    | `30`, `90`, `365`                                           |
| `TZ`                    | ❌       | Timezone                | `Asia/Ho_Chi_Minh`, `UTC`                                   |
| `RCLONE_TPS_LIMIT`      | ❌       | Rclone TPS limit        | `4`, `6`, `8` (default: `8`)                                |
| `RCLONE_CHUNK_SIZE`     | ❌       | Chunk size for uploads  | `64M`, `128M`, `256M` (default: `128M`)                     |
| `RCLONE_UPLOAD_CUTOFF`  | ❌       | Upload cutoff threshold | `64M`, `128M`, `256M` (default: `128M`)                     |
| `RCLONE_TRANSFERS`      | ❌       | Concurrent transfers    | `1`, `2`, `4` (default: `1`)                                |

### Rclone Configuration Methods

**Priority Order: Existing Config > File Mount > Base64 Encoded**

The tool now intelligently handles rclone configuration to preserve refreshed tokens:

1. **Existing Config (Highest Priority)**: If a valid rclone config exists in the container, it will be used instead of recreating from environment variables
2. **File Mount**: Mount external rclone.conf file
3. **Base64 Encoded**: Use base64 encoded config from environment variable

#### Method 1: File Mount (Recommended for Initial Setup)

```bash
# 1. Copy rclone.conf to project directory
cp ~/.config/rclone/rclone.conf ./rclone.conf

# 2. Uncomment and add volume mount in docker-compose.yml
volumes:
  - ./rclone.conf:/etc/rclone.conf:ro

# 3. Set in .env
RCLONE_CONFIG_FILE=/etc/rclone.conf
```

**Note**: After initial setup, you can comment out this volume mount to preserve the config inside the container.

#### Method 2: Base64 Encoded (Good for Secrets)

```bash
# 1. Encode your config
cat rclone.conf | base64 -w 0

# 2. Copy output to .env
RCLONE_CONFIG_BASE64=W2dkcml2ZV0K...
```

#### Method 3: Persistent Config (Best for Production)

```bash
# Create a named volume for rclone config
docker volume create rclone-config

# Mount in docker-compose.yml
volumes:
  - rclone-config:/root/.config/rclone

# This way config persists between container restarts
# and tokens are preserved
```

### Rate Limiting & Optimization

The tool includes built-in rate limiting to avoid Google Drive API limits when uploading large database backups.

#### Rate Limiting Variables

| Variable               | Default | Description                   | Recommended Values                        |
| ---------------------- | ------- | ----------------------------- | ----------------------------------------- |
| `RCLONE_TPS_LIMIT`     | `8`     | Transactions per second limit | `4-6` (large files), `8-10` (small files) |
| `RCLONE_CHUNK_SIZE`    | `128M`  | Chunk size for uploads        | `64M-256M`                                |
| `RCLONE_UPLOAD_CUTOFF` | `128M`  | Upload cutoff threshold       | Same as `RCLONE_CHUNK_SIZE`               |
| `RCLONE_TRANSFERS`     | `1`     | Concurrent transfers          | `1` (recommended for backups)             |

#### Configuration Examples

**For Large Databases (>500MB):**

```bash
RCLONE_TPS_LIMIT=4
RCLONE_CHUNK_SIZE=64M
RCLONE_UPLOAD_CUTOFF=64M
RCLONE_TRANSFERS=1
```

**For Small Databases (<100MB):**

```bash
RCLONE_TPS_LIMIT=8
RCLONE_CHUNK_SIZE=256M
RCLONE_UPLOAD_CUTOFF=256M
RCLONE_TRANSFERS=1
```

**For Very Large Databases (>1GB):**

```bash
RCLONE_TPS_LIMIT=4
RCLONE_CHUNK_SIZE=64M
RCLONE_UPLOAD_CUTOFF=64M
RCLONE_TRANSFERS=1
```

### Backup Naming

#### Custom Template (Highest Priority)

```bash
# Available placeholders: {db_type}, {db_name}, {timestamp}, {date}, {time}, {host}, {port}
BACKUP_NAME_TEMPLATE={db_name}_{db_type}_{date}_{time}.backup
# Result: novels_platform_postgres_20250823_143022.backup
```

#### Simple Prefix (Fallback)

```bash
BACKUP_NAME_PREFIX=myapp
# Result: myapp_postgres_novels_platform_20250823_143022.sql
```

## 🐳 Docker Commands

### Basic Operations

```bash
# Build image
docker-compose build

# Start in manual mode
docker-compose up --build

# Start in automated mode
AUTOMATED_BACKUP=true docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop service
docker-compose down
```

### Advanced Operations

```bash
# Manual backup (bypass cron)
docker-compose run --rm db-backup

# Enter container for debugging
docker-compose exec db-backup bash

# Test rclone connection
docker-compose exec db-backup rclone lsd gdrive:

# Check backup status
docker-compose exec db-backup ps aux | grep pg_dump
```

## 📅 Cron Scheduling

### Common Schedules

```bash
# Daily at 2:00 AM
CRON_SCHEDULE=0 2 * * *

# Twice daily (2 AM and 2 PM)
CRON_SCHEDULE=0 2,14 * * *

# Every 6 hours
CRON_SCHEDULE=0 */6 * * *

# Weekdays only at 2 AM
CRON_SCHEDULE=0 2 * * 1-5

# Every 30 minutes (for testing)
CRON_SCHEDULE=*/30 * * * *
```

### Timezone Configuration

```bash
# Set timezone for cron scheduling
TZ=Asia/Ho_Chi_Minh
TZ=America/New_York
TZ=Europe/London
TZ=UTC
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Rclone Connection Failed

```bash
# Check rclone config
docker-compose exec db-backup rclone config show

# Test connection
docker-compose exec db-backup rclone lsd gdrive:

# Verify permissions
docker-compose exec db-backup ls -la /root/.config/rclone/
```

#### 2. Google Drive Rate Limit Errors

```bash
# Check current rate limiting settings
docker-compose exec db-backup env | grep RCLONE_

# Reduce rate limiting for large files
# Add to .env:
RCLONE_TPS_LIMIT=4
RCLONE_CHUNK_SIZE=64M
RCLONE_UPLOAD_CUTOFF=64M

# Monitor Google Drive API quota
# Visit: https://console.cloud.google.com/apis/credentials
```

#### 3. Database Connection Failed

```bash
# Check environment variables
docker-compose exec db-backup env | grep DB_

# Test database connection
docker-compose exec db-backup pg_isready -h $DB_HOST -p $DB_PORT
```

#### 4. Cron Not Working

```bash
# Check cron service
docker-compose exec db-backup service cron status

# View cron logs
docker-compose exec db-backup tail -f /app/logs/cron.log

# Verify environment variables in cron
docker-compose exec db-backup crontab -l
```

#### 5. Backup Already Running

```bash
# Check PID file
docker-compose exec db-backup cat /tmp/db-backup.pid

# Kill existing process (if needed)
docker-compose exec db-backup pkill -f backup.sh
```

### Debug Commands

```bash
# Check container logs
docker-compose logs -f db-backup

# Enter container interactively
docker-compose exec -it db-backup bash

# Test backup manually
docker-compose run --rm db-backup

# Check disk usage
docker-compose exec db-backup df -h

# Monitor processes
docker-compose exec db-backup top
```

## 📊 Monitoring & Logs

### Log Locations

- **Container logs**: `docker-compose logs -f`
- **Cron logs**: `/app/logs/cron.log` (inside container)
- **Backup logs**: Real-time in container output

### Log Format

```
[2025-08-23 16:44:02] Database Backup Tool - Starting backup...
[2025-08-23 16:44:02] ✅ Rclone connection verified
[2025-08-23 16:44:02] Starting PostgreSQL backup for novels_platform...
[2025-08-23 16:44:05] PostgreSQL backup completed: novels_platform_postgres.backup
```

## 🛡️ Security Best Practices

### 1. Credentials Management

- ✅ Use Docker secrets for production
- ✅ Rotate database passwords regularly
- ✅ Use service accounts (not personal accounts)
- ✅ Limit database user permissions

### 2. Network Security

- ✅ Restrict database access to backup container only
- ✅ Use VPN or private networks when possible
- ✅ Monitor backup access logs

### 3. File Permissions

- ✅ Set proper file permissions on .env
- ✅ Use read-only volume mounts
- ✅ Regular security audits

## 📈 Performance Optimization

### 1. Backup Scheduling

- Schedule during low-traffic hours
- Monitor backup duration
- Adjust frequency based on data change rate

### 2. Resource Management

- Use streaming backup (default)
- Monitor container resource usage
- Set appropriate retention policies

### 3. Network Optimization

- Consider bandwidth limitations
- Use appropriate backup frequency
- Monitor upload speeds

### 4. Rate Limiting for Large Files

- **Large databases (>500MB)**: Use conservative settings
  - `RCLONE_TPS_LIMIT=4-6`
  - `RCLONE_CHUNK_SIZE=64M-128M`
- **Small databases (<100MB)**: Can use more aggressive settings
  - `RCLONE_TPS_LIMIT=8-10`
  - `RCLONE_CHUNK_SIZE=128M-256M`
- **Monitor Google Drive API quota** in Google Cloud Console
- **Reduce settings** if you frequently hit rate limits

## 🔄 Backup Retention

### Automatic Cleanup

```bash
# Keep backups for 30 days
BACKUP_RETENTION_DAYS=30

# Keep backups for 90 days
BACKUP_RETENTION_DAYS=90

# Disable retention (keep forever)
# BACKUP_RETENTION_DAYS=
```

### Manual Cleanup

```bash
# Clean old backups manually
docker-compose run --rm db-backup --cleanup

# Check what will be deleted
docker-compose exec db-backup rclone delete gdrive:backups --min-age 30d --dry-run
```

## 🧪 Testing

### Test Database Connection

```bash
# PostgreSQL
docker-compose exec db-backup pg_isready -h $DB_HOST -p $DB_PORT

# MySQL
docker-compose exec db-backup mysqladmin ping -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASSWORD

# MongoDB
docker-compose exec db-backup mongosh --host $DB_HOST --port $DB_PORT --username $DB_USER --password $DB_PASSWORD
```

### Test Rclone Connection

```bash
# List remote directories
docker-compose exec db-backup rclone lsd gdrive:

# Test upload (small file)
echo "test" | docker-compose exec -T db-backup rclone rcat gdrive:test.txt

# Cleanup test file
docker-compose exec db-backup rclone delete gdrive:test.txt
```

## 📚 Examples

### Example 1: Production PostgreSQL

```bash
# .env configuration
DB_TYPE=postgres
DB_HOST=prod-db.example.com
DB_PORT=5432
DB_NAME=production
DB_USER=backup_user
DB_PASSWORD=secure_password
RCLONE_CONFIG_FILE=/etc/rclone.conf
RCLONE_REMOTE_PATH=gdrive:production/backups
BACKUP_NAME_TEMPLATE=prod_{host}_{db_name}_{date}_{time}.sql
AUTOMATED_BACKUP=true
CRON_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=90
TZ=UTC
# Rate limiting for large production database
RCLONE_TPS_LIMIT=6
RCLONE_CHUNK_SIZE=128M
RCLONE_UPLOAD_CUTOFF=128M
RCLONE_TRANSFERS=1

# docker-compose.yml volumes (choose one):
# Option A: Initial setup with file mount
volumes:
  - ./rclone.conf:/etc/rclone.conf:ro

# Option B: Persistent config (recommended for production)
volumes:
  - rclone-config:/root/.config/rclone
```

### Example 2: Development MySQL

```bash
# .env configuration
DB_TYPE=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=dev_app
DB_USER=root
DB_PASSWORD=dev_password
RCLONE_CONFIG_BASE64=W2dkcml2ZV0K...
RCLONE_REMOTE_PATH=gdrive:development/backups
BACKUP_NAME_PREFIX=dev
AUTOMATED_BACKUP=false
# Conservative rate limiting for development
RCLONE_TPS_LIMIT=8
RCLONE_CHUNK_SIZE=64M
RCLONE_UPLOAD_CUTOFF=64M
RCLONE_TRANSFERS=1
```

### Example 3: Large Database with Conservative Settings

```bash
# .env configuration for very large databases (>1GB)
DB_TYPE=postgres
DB_HOST=large-db.example.com
DB_PORT=5432
DB_NAME=large_database
DB_USER=backup_user
DB_PASSWORD=secure_password
RCLONE_CONFIG_FILE=/etc/rclone.conf
RCLONE_REMOTE_PATH=gdrive:large_backups
BACKUP_NAME_TEMPLATE=large_{db_name}_{date}_{time}.backup
AUTOMATED_BACKUP=true
CRON_SCHEDULE=0 1 * * *
BACKUP_RETENTION_DAYS=30
TZ=UTC
# Very conservative rate limiting for large databases
RCLONE_TPS_LIMIT=4
RCLONE_CHUNK_SIZE=64M
RCLONE_UPLOAD_CUTOFF=64M
RCLONE_TRANSFERS=1
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help

- Check the [troubleshooting section](#troubleshooting)
- Review [common issues](#common-issues)
- Check container logs: `docker-compose logs -f`

### Reporting Issues

- Use GitHub Issues
- Include relevant logs and configuration
- Describe your environment and steps to reproduce

### Feature Requests

- Open a GitHub Issue
- Describe the desired functionality
- Explain the use case

---

**Made with ❤️ for reliable database backups**
