#!/bin/bash

set -e

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check Google Drive API quota
check_quota() {
    log "🔍 Checking Google Drive API quota..."
    
    # Get project info from rclone config
    if [ -f "/root/.config/rclone/rclone.conf" ]; then
        log "📋 Rclone config found, checking project details..."
        
        # Extract project info (this is a simplified check)
        if grep -q "project_number" /root/.config/rclone/rclone.conf; then
            log "⚠️  Found project_number in config - this might be a service account"
        fi
        
        if grep -q "client_id" /root/.config/rclone/rclone.conf; then
            log "✅ Using OAuth2 authentication"
        fi
    fi
    
    log "📊 Current quota limits:"
    log "  - Queries per minute: 420,000 (default)"
    log "  - Queries per 100 seconds: 1,000,000 (default)"
    log "  - Queries per 100 seconds per user: 1,000 (default)"
    
    log ""
    log "💡 Recommendations to reduce API calls:"
    log "  1. Use very conservative rate limiting:"
    log "     - RCLONE_TPS_LIMIT=1-2"
    log "     - RCLONE_CHUNK_SIZE=16M-32M"
    log "  2. Increase delays between operations:"
    log "     - RCLONE_RETRIES_SLEEP=60s"
    log "  3. Use single transfer mode:"
    log "     - RCLONE_TRANSFERS=1"
    log "  4. Consider using different Google account/project"
    log "  5. Request quota increase from Google Cloud Console"
}

# Check current rclone settings
check_current_settings() {
    log ""
    log "🔧 Current rclone settings:"
    log "  - TPS_LIMIT: ${RCLONE_TPS_LIMIT:-2} (default)"
    log "  - CHUNK_SIZE: ${RCLONE_CHUNK_SIZE:-32M} (default)"
    log "  - UPLOAD_CUTOFF: ${RCLONE_UPLOAD_CUTOFF:-32M} (default)"
    log "  - TRANSFERS: ${RCLONE_TRANSFERS:-1} (default)"
    
    log ""
    log "📈 Estimated API calls per backup:"
    local chunk_size="${RCLONE_CHUNK_SIZE:-32M}"
    local chunk_size_mb=$(echo "$chunk_size" | sed 's/M//')
    
    # Rough estimation: file size / chunk size * overhead
    log "  - With 32M chunks: ~3-5 API calls per MB"
    log "  - Large files will generate many API calls"
    log "  - Consider reducing chunk size for very large databases"
}

# Show optimization commands
show_optimization() {
    log ""
    log "🚀 Quick optimization commands:"
    log ""
    log "# For very large databases (>1GB):"
    log "export RCLONE_TPS_LIMIT=1"
    log "export RCLONE_CHUNK_SIZE=16M"
    log "export RCLONE_UPLOAD_CUTOFF=16M"
    log "export RCLONE_TRANSFERS=1"
    log ""
    log "# For medium databases (100MB-1GB):"
    log "export RCLONE_TPS_LIMIT=2"
    log "export RCLONE_CHUNK_SIZE=32M"
    log "export RCLONE_UPLOAD_CUTOFF=32M"
    log "export RCLONE_TRANSFERS=1"
    log ""
    log "# For small databases (<100MB):"
    log "export RCLONE_TPS_LIMIT=3"
    log "export RCLONE_CHUNK_SIZE=64M"
    log "export RCLONE_UPLOAD_CUTOFF=64M"
    log "export RCLONE_TRANSFERS=1"
}

# Main function
main() {
    log "🔍 Google Drive API Quota Checker"
    log "=================================="
    
    check_quota
    check_current_settings
    show_optimization
    
    log ""
    log "📚 Additional resources:"
    log "  - Google Cloud Console: https://console.cloud.google.com/apis/credentials"
    log "  - Request quota increase: https://cloud.google.com/docs/quotas/help/request_increase"
    log "  - Drive API quotas: https://developers.google.com/drive/api/guides/limits"
}

# Run main function
main "$@"
