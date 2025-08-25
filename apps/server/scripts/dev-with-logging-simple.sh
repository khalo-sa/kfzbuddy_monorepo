#!/bin/bash

# Simple dev server with logging script
# This script starts the dev server and maintains a rolling log with last X lines

LOG_FILE="server.log"
MAX_LINES=1000  # Keep only the last 1000 lines
TRIM_INTERVAL=100  # Trim every 100 lines to avoid performance issues

# Function to trim log file to last X lines
trim_log() {
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$line_count" -gt "$MAX_LINES" ]; then
            echo "🔄 Log file has $line_count lines, trimming to last $MAX_LINES lines..."
            tail -n "$MAX_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        fi
    fi
}

# Function to cleanup old log files
cleanup_old_logs() {
    # Keep only the last 3 log files
    local old_logs=("${LOG_FILE}.old"*)
    if [ ${#old_logs[@]} -gt 3 ]; then
        echo "🧹 Cleaning up old log files..."
        ls -t "${LOG_FILE}.old"* | tail -n +4 | xargs rm -f
    fi
}

# Initial setup
echo "🚀 Starting dev server with logging..."
echo "📝 Logs will be saved to: $LOG_FILE"
echo "📏 Max lines kept: $MAX_LINES"
echo "🔄 Rolling log: enabled (trims every $TRIM_INTERVAL lines)"
echo "---"

# Trim log if needed and cleanup old logs
trim_log
cleanup_old_logs

# Counter for trimming
line_counter=0

# Start the dev server with logging
# This approach shows output in console AND writes to log file
pnpm dev 2>&1 | while IFS= read -r line; do
    echo "$line" | tee -a "$LOG_FILE"
    
    # Increment counter and trim periodically
    ((line_counter++))
    if [ $((line_counter % TRIM_INTERVAL)) -eq 0 ]; then
        trim_log
    fi
done
