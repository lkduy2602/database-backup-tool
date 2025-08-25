#!/bin/bash

set -e

# Database Backup Tool with Rclone Rate Limiting
# 
# Environment Variables for Rclone Optimization:
# - RCLONE_TPS_LIMIT: Transactions per second limit (default: 8)
# - RCLONE_CHUNK_SIZE: Chunk size for large files (default: 128M)
# - RCLONE_UPLOAD_CUTOFF: Upload cutoff for chunked uploads (default: 128M)
# - RCLONE_TRANSFERS: Number of concurrent transfers (default: 1)
#
# These settings help avoid Google Drive API rate limits when uploading large database backups.

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if backup is already running
check_running() {
    local pid_file="/tmp/db-backup.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "Backup already running (PID: $pid), skipping..."
            return 1
        else
            # Remove stale PID file
            rm -f "$pid_file"
        fi
    fi
    
    # Create PID file
    echo $$ > "$pid_file"
    return 0
}

# Check if rclone is ready
check_rclone_ready() {
    if [ ! -f /tmp/rclone_ready ]; then
        log "ERROR: Rclone is not ready. Please ensure container started properly."
        exit 1
    fi
    
    # Quick test to ensure rclone still works
    if ! rclone lsd "$RCLONE_REMOTE_PATH" > /dev/null 2>&1; then
        log "ERROR: Rclone connection failed. Please check configuration."
        exit 1
    fi
    
    log "✅ Rclone connection verified"
}

# Check required environment variables
check_env() {
    if [ -z "$DB_TYPE" ] || [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
        log "ERROR: Required database environment variables are not set"
        log "Please set: DB_TYPE, DB_HOST, DB_NAME"
        exit 1
    fi
    
    if [ -z "$RCLONE_REMOTE_PATH" ]; then
        log "ERROR: RCLONE_REMOTE_PATH is not set"
        exit 1
    fi
}

# Generate backup filename
generate_backup_name() {
    local db_type="$1"
    local db_name="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local date_only=$(date +%Y%m%d)
    local time_only=$(date +%H%M%S)
    
    # If custom template is provided, use it
    if [ -n "$BACKUP_NAME_TEMPLATE" ]; then
        local filename="$BACKUP_NAME_TEMPLATE"
        
        # Replace placeholders with actual values
        filename="${filename//\{db_type\}/$db_type}"
        filename="${filename//\{db_name\}/$db_name}"
        filename="${filename//\{timestamp\}/$timestamp}"
        filename="${filename//\{date\}/$date_only}"
        filename="${filename//\{time\}/$time_only}"
        filename="${filename//\{host\}/$DB_HOST}"
        filename="${filename//\{port\}/$DB_PORT}"
        
        echo "$filename"
        return
    fi
    
    # Default naming if no template provided
    local prefix="${BACKUP_NAME_PREFIX:-backup}"
    
    case "$db_type" in
        "postgres"|"postgresql")
            echo "${prefix}_postgres_${db_name}_${timestamp}.sql"
            ;;
        "mysql"|"mariadb")
            echo "${prefix}_mysql_${db_name}_${timestamp}.sql.gz"
            ;;
        # MongoDB support removed temporarily
        # "mongodb")
        #     echo "${prefix}_mongodb_${db_name}_${timestamp}.archive.gz"
        #     ;;
        "sqlite")
            echo "${prefix}_sqlite_${db_name}_${timestamp}.db.gz"
            ;;
        *)
            echo "${prefix}_${db_type}_${db_name}_${timestamp}.backup"
            ;;
    esac
}

# Cleanup PID file
cleanup() {
    rm -f /tmp/db-backup.pid
}

# Set trap for cleanup
trap cleanup EXIT

# Generate rclone options for rate limiting and optimization
get_rclone_options() {
    local options=""
    
    # Rate limiting to avoid Google Drive API limits
    if [ -n "$RCLONE_TPS_LIMIT" ]; then
        options="$options --tpslimit $RCLONE_TPS_LIMIT"
    else
        options="$options --tpslimit 8"  # Default safe limit
    fi
    
    # Chunk size for large files (default 128M)
    if [ -n "$RCLONE_CHUNK_SIZE" ]; then
        options="$options --drive-chunk-size $RCLONE_CHUNK_SIZE"
    else
        options="$options --drive-chunk-size 128M"
    fi
    
    # Upload cutoff for chunked uploads (default 128M)
    if [ -n "$RCLONE_UPLOAD_CUTOFF" ]; then
        options="$options --drive-upload-cutoff $RCLONE_UPLOAD_CUTOFF"
    else
        options="$options --drive-upload-cutoff 128M"
    fi
    
    # Additional optimization options
    if [ -n "$RCLONE_TRANSFERS" ]; then
        options="$options --transfers $RCLONE_TRANSFERS"
    else
        options="$options --transfers 1"  # Single transfer for backup
    fi
    
    # Progress reporting
    options="$options --progress"
    
    echo "$options"
}

# Backup PostgreSQL
backup_postgres() {
    log "Starting PostgreSQL backup for $DB_NAME on $DB_HOST:$DB_PORT..."
    
    local backup_name=$(generate_backup_name "postgres" "$DB_NAME")
    local rclone_opts=$(get_rclone_options)
    
    log "Using rclone options: $rclone_opts"
    
    # Pipeline: pg_dump -> rclone copy (streaming)
    PGPASSWORD="$DB_PASSWORD" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --no-password \
        --verbose \
        --clean \
        --no-owner \
        --no-privileges \
        --format=custom \
        --compress=9 \
        | rclone rcat $rclone_opts "$RCLONE_REMOTE_PATH/$backup_name"
    
    log "PostgreSQL backup completed: $backup_name"
}

# Backup MySQL
backup_mysql() {
    log "Starting MySQL backup for $DB_NAME on $DB_HOST:$DB_PORT..."
    
    local backup_name=$(generate_backup_name "mysql" "$DB_NAME")
    local rclone_opts=$(get_rclone_options)
    
    log "Using rclone options: $rclone_opts"
    
    # Pipeline: mysqldump -> gzip -> rclone copy (streaming)
    mysqldump \
        -h "$DB_HOST" \
        -P "$DB_PORT" \
        -u "$DB_USER" \
        -p"$DB_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --hex-blob \
        --opt \
        "$DB_NAME" \
        | gzip -9 \
        | rclone rcat $rclone_opts "$RCLONE_REMOTE_PATH/$backup_name"
    
    log "MySQL backup completed: $backup_name"
}

# MongoDB backup function removed temporarily
# backup_mongodb() {
#     log "Starting MongoDB backup for $DB_NAME on $DB_HOST:$DB_PORT..."
#     
#     local backup_name=$(generate_backup_name "mongodb" "$DB_NAME"
#     
#     # Pipeline: mongodump -> gzip -> rclone copy (streaming)
#     mongodump \
#         --host "$DB_HOST" \
#         --port "$DB_PORT" \
#         --username "$DB_USER" \
#         --password "$DB_PASSWORD" \
#         --db "$DB_NAME" \
#         --archive \
#         | gzip -9 \
#         | rclone rcat "$RCLONE_REMOTE_PATH/$backup_name"
#     
#     log "MongoDB backup completed: $backup_name"
# }

# Backup SQLite
backup_sqlite() {
    log "Starting SQLite backup for $DB_NAME..."
    
    local backup_name=$(generate_backup_name "sqlite" "$DB_NAME")
    local rclone_opts=$(get_rclone_options)
    
    log "Using rclone options: $rclone_opts"
    
    # Pipeline: sqlite3 dump -> gzip -> rclone copy (streaming)
    sqlite3 "$DB_NAME" .dump \
        | gzip -9 \
        | rclone rcat $rclone_opts "$RCLONE_REMOTE_PATH/$backup_name"
    
    log "SQLite backup completed: $backup_name"
}

# Main backup function
main_backup() {
    log "Starting database backup process..."
    
    case "$DB_TYPE" in
        "postgres"|"postgresql")
            backup_postgres
            ;;
        "mysql"|"mariadb")
            backup_mysql
            ;;
        # MongoDB support removed temporarily
        # "mongodb")
        #     backup_mongodb
        #     ;;
        "sqlite")
            backup_sqlite
            ;;
        *)
            log "ERROR: Unsupported database type: $DB_TYPE"
            log "Supported types: postgres, mysql, sqlite (mongodb temporarily removed)"
            exit 1
            ;;
    esac
    
    log "✅ Database backup completed successfully!"
}

# Cleanup old backups (optional)
cleanup_old_backups() {
    if [ -n "$BACKUP_RETENTION_DAYS" ]; then
        log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
        local rclone_opts=$(get_rclone_options)
        rclone delete $rclone_opts "$RCLONE_REMOTE_PATH" --min-age "${BACKUP_RETENTION_DAYS}d" --dry-run
    fi
}

# Main execution
main() {
    log "Database Backup Tool - Starting backup..."
    
    # Check if backup should run (prevent multiple instances)
    if ! check_running; then
        exit 0
    fi
    
    # Check environment variables
    check_env
    
    # Verify rclone is ready (setup by start.sh)
    check_rclone_ready
    
    # Log backup configuration
    log "Backup configuration:"
    log "  - Database: $DB_TYPE://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    log "  - Remote path: $RCLONE_REMOTE_PATH"
    if [ -n "$BACKUP_NAME_TEMPLATE" ]; then
        log "  - Custom template: $BACKUP_NAME_TEMPLATE"
    else
        log "  - Name prefix: ${BACKUP_NAME_PREFIX:-backup} (default)"
    fi
    log "  - Retention: ${BACKUP_RETENTION_DAYS:-unlimited} days"
    log "  - Rclone TPS limit: ${RCLONE_TPS_LIMIT:-8} (default)"
    log "  - Rclone chunk size: ${RCLONE_CHUNK_SIZE:-128M} (default)"
    log "  - Rclone upload cutoff: ${RCLONE_UPLOAD_CUTOFF:-128M} (default)"
    
    # Perform backup
    main_backup
    
    # Cleanup old backups if retention is set
    if [ -n "$BACKUP_RETENTION_DAYS" ]; then
        cleanup_old_backups
    fi
    
    log "All operations completed successfully!"
}

# Run main function
main "$@"
