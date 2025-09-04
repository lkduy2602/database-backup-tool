#!/bin/bash

# Wrapper script for cron jobs to ensure rclone config is properly set up
set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔄 Backup wrapper starting..."

# Load environment variables from cron-env.sh if it exists
if [ -f "/app/cron-env.sh" ]; then
    log "📋 Loading environment variables from /app/cron-env.sh"
    source /app/cron-env.sh
    log "✅ Environment variables loaded"
else
    log "⚠️  No /app/cron-env.sh found, using system environment variables"
fi

# Check if rclone config exists and is valid
if [ ! -f "/root/.config/rclone/rclone.conf" ] || [ ! -s "/root/.config/rclone/rclone.conf" ]; then
    log "⚠️  Rclone config not found or empty, attempting to recreate..."
    
    # Try to recreate rclone config using the same logic as start.sh
    mkdir -p /root/.config/rclone
    
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
    
    log "✅ Rclone config recreated"
else
    log "✅ Rclone config exists and is valid"
fi

# Test rclone connection before proceeding
if [ -n "$RCLONE_REMOTE_PATH" ]; then
    log "🔍 Testing rclone connection to: $RCLONE_REMOTE_PATH"
    if rclone lsd "$RCLONE_REMOTE_PATH" > /dev/null 2>&1; then
        log "✅ Rclone connection verified"
    else
        log "❌ Rclone connection failed"
        log "🔍 Debug info:"
        log "  - RCLONE_REMOTE_PATH: $RCLONE_REMOTE_PATH"
        log "  - Config file exists: $([ -f "/root/.config/rclone/rclone.conf" ] && echo "Yes" || echo "No")"
        log "  - Config file size: $(ls -lh /root/.config/rclone/rclone.conf 2>/dev/null | awk '{print $5}' || echo "N/A")"
        log "  - Current working directory: $(pwd)"
        log "  - User: $(whoami)"
        log "  - Available environment variables:"
        log "    - DB_TYPE: ${DB_TYPE:-NOT_SET}"
        log "    - DB_HOST: ${DB_HOST:-NOT_SET}"
        log "    - DB_NAME: ${DB_NAME:-NOT_SET}"
        log "    - DB_USER: ${DB_USER:-NOT_SET}"
        log "    - DB_PASSWORD: $([ -n "$DB_PASSWORD" ] && echo "SET" || echo "NOT_SET")"
        log "    - RCLONE_CONFIG_FILE: ${RCLONE_CONFIG_FILE:-NOT_SET}"
        log "    - RCLONE_CONFIG_BASE64: $([ -n "$RCLONE_CONFIG_BASE64" ] && echo "SET" || echo "NOT_SET")"
        log "    - RCLONE_TPS_LIMIT: ${RCLONE_TPS_LIMIT:-NOT_SET}"
        log "    - RCLONE_CHUNK_SIZE: ${RCLONE_CHUNK_SIZE:-NOT_SET}"
        log "    - RCLONE_UPLOAD_CUTOFF: ${RCLONE_UPLOAD_CUTOFF:-NOT_SET}"
        log "    - RCLONE_TRANSFERS: ${RCLONE_TRANSFERS:-NOT_SET}"
        log "    - RCLONE_CHECKERS: ${RCLONE_CHECKERS:-NOT_SET}"
        log "    - RCLONE_MAX_TRANSFER: ${RCLONE_MAX_TRANSFER:-NOT_SET}"
        
        # Try to get more detailed rclone error
        log "🔍 Detailed rclone error:"
        rclone lsd "$RCLONE_REMOTE_PATH" 2>&1 | head -10 || true
        
        exit 1
    fi
else
    log "ERROR: RCLONE_REMOTE_PATH not set"
    log "🔍 Available environment variables:"
    log "  - DB_TYPE: ${DB_TYPE:-NOT_SET}"
    log "  - DB_HOST: ${DB_HOST:-NOT_SET}"
    log "  - DB_NAME: ${DB_NAME:-NOT_SET}"
    log "  - RCLONE_REMOTE_PATH: ${RCLONE_REMOTE_PATH:-NOT_SET}"
    exit 1
fi

# Now run the actual backup script
log "🚀 Starting backup process..."
exec /app/backup.sh "$@"
