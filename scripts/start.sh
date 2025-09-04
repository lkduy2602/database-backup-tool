#!/bin/bash

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Setup rclone config once with multiple methods
# Priority: Existing config > File mount > Base64 env var
setup_rclone_once() {
    log "Setting up rclone configuration..."
    mkdir -p /root/.config/rclone
    
    # Check if rclone config already exists and is valid
    if [ -f "/root/.config/rclone/rclone.conf" ] && [ -s "/root/.config/rclone/rclone.conf" ]; then
        log "Found existing rclone config, testing connection..."
        if rclone lsd "$RCLONE_REMOTE_PATH" > /dev/null 2>&1; then
            log "✅ Using existing rclone config - connection successful"
            touch /tmp/rclone_ready
            log "Rclone setup completed using existing config"
            return 0
        else
            log "⚠️  Existing config found but connection failed, will recreate..."
        fi
    fi
    
    # No valid existing config, create new one
    if [ -n "$RCLONE_CONFIG_FILE" ] && [ -f "$RCLONE_CONFIG_FILE" ]; then
        log "Using rclone config file: $RCLONE_CONFIG_FILE"
        cp "$RCLONE_CONFIG_FILE" /root/.config/rclone/rclone.conf
    elif [ -n "$RCLONE_CONFIG_BASE64" ]; then
        log "Using rclone config from base64 encoded environment variable"
        echo "$RCLONE_CONFIG_BASE64" | base64 -d > /root/.config/rclone/rclone.conf
    else
        log "ERROR: No rclone configuration provided"
        log "Please set one of: RCLONE_CONFIG_FILE or RCLONE_CONFIG_BASE64"
        exit 1
    fi
    
    log "Testing rclone connection..."
    if ! rclone lsd "$RCLONE_REMOTE_PATH" > /dev/null 2>&1; then
        log "ERROR: Failed to connect to remote storage: $RCLONE_REMOTE_PATH"
        exit 1
    fi
    
    log "✅ Rclone connection successful"
    touch /tmp/rclone_ready
    log "Rclone setup completed and ready for use"
}

# Setup cron job for automated mode
setup_cron() {
    log "Setting up automated backup with cron..."
    
    # Default schedule: 2:00 AM daily
    local cron_schedule="${CRON_SCHEDULE:-0 2 * * *}"
    
    log "Cron schedule: $cron_schedule"
    
    # Create environment file for cron job
    cat > /app/cron-env.sh << EOF
#!/bin/bash
# Environment variables for cron job
export DB_TYPE="$DB_TYPE"
export DB_HOST="$DB_HOST"
export DB_PORT="$DB_PORT"
export DB_NAME="$DB_NAME"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export RCLONE_REMOTE_PATH="$RCLONE_REMOTE_PATH"
export RCLONE_CONFIG_FILE="$RCLONE_CONFIG_FILE"
export RCLONE_CONFIG_BASE64="$RCLONE_CONFIG_BASE64"
export BACKUP_NAME_TEMPLATE="$BACKUP_NAME_TEMPLATE"
export BACKUP_NAME_PREFIX="$BACKUP_NAME_PREFIX"
export BACKUP_RETENTION_DAYS="$BACKUP_RETENTION_DAYS"
export TZ="$TZ"
export RCLONE_TPS_LIMIT="$RCLONE_TPS_LIMIT"
export RCLONE_CHUNK_SIZE="$RCLONE_CHUNK_SIZE"
export RCLONE_UPLOAD_CUTOFF="$RCLONE_UPLOAD_CUTOFF"
export RCLONE_TRANSFERS="$RCLONE_TRANSFERS"
export RCLONE_CHECKERS="$RCLONE_CHECKERS"
export RCLONE_MAX_TRANSFER="$RCLONE_MAX_TRANSFER"
EOF
    
    # Make environment file executable
    chmod +x /app/cron-env.sh
    
    # Create cron job with simple command
    cat > /tmp/crontab << EOF
# Cron job with environment file
$cron_schedule /app/cron-env.sh && /app/backup-wrapper.sh >> /app/logs/cron.log 2>&1
EOF
    
    # Add cron job
    crontab /tmp/crontab
    rm /tmp/crontab
    
    # Create cron.log file
    touch /app/logs/cron.log
    
    log "Cron job installed successfully"
    
    # Start cron service in background (Debian)
    cron -f &
    
    # Keep container running and monitor cron.log
    log "Cron service started. Monitoring logs..."
    tail -f /app/logs/cron.log
}

# Main function
main() {
    log "Database Backup Tool - Starting..."
    
    # Check required environment variables
    if [ -z "$DB_TYPE" ] || [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
        log "ERROR: Required database environment variables are not set"
        log "Please set: DB_TYPE, DB_HOST, DB_NAME"
        exit 1
    fi
    
    if [ -z "$RCLONE_REMOTE_PATH" ]; then
        log "ERROR: RCLONE_REMOTE_PATH is not set"
        exit 1
    fi
    
    # Log configuration
    log "Database configuration: $DB_TYPE://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    log "Rclone rate limiting: TPS=${RCLONE_TPS_LIMIT:-1}, Chunk=${RCLONE_CHUNK_SIZE:-16M}, Cutoff=${RCLONE_UPLOAD_CUTOFF:-16M}, Transfers=${RCLONE_TRANSFERS:-1}, Checkers=${RCLONE_CHECKERS:-2}, MaxTransfer=${RCLONE_MAX_TRANSFER:-700G}"
    
    # Setup rclone once at startup
    setup_rclone_once
    
    # Check if we should run in automated mode
    if [ "$AUTOMATED_BACKUP" = "true" ] || [ "$AUTOMATED_BACKUP" = "1" ] || [ -n "$CRON_SCHEDULE" ]; then
        log "Starting in AUTOMATED mode with cron"
        setup_cron
    else
        log "Starting in MANUAL mode - single backup execution"
        exec /app/backup.sh "$@"
    fi
}

# Run main function
main "$@"
