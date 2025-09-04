#!/bin/bash

# Wrapper script for cron jobs to ensure rclone config is properly set up
set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "🔄 Backup wrapper starting..."

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
        exit 1
    fi
else
    log "ERROR: RCLONE_REMOTE_PATH not set"
    exit 1
fi

# Now run the actual backup script
log "🚀 Starting backup process..."
exec /app/backup.sh "$@"
