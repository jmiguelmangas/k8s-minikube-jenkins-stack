#!/bin/bash

# Monitor script for clinical history deployment
NAMESPACE="dataproducts"
DEPLOYMENT="infra-user-uat-incibe-neo-dataproducts-clinical-history"
LOG_FILE="$HOME/clinical-history-monitor.log"

echo "Starting monitoring for $DEPLOYMENT in namespace $NAMESPACE"
echo "Log file: $LOG_FILE"

# Function to log with timestamp
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get current revision
get_current_revision() {
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null
}

# Initial state
LAST_REVISION=$(get_current_revision)
log_with_timestamp "Initial revision: $LAST_REVISION"

# Monitor loop
while true; do
    CURRENT_REVISION=$(get_current_revision)
    
    if [ "$CURRENT_REVISION" != "$LAST_REVISION" ]; then
        log_with_timestamp "⚠️  ALERT: Deployment revision changed from $LAST_REVISION to $CURRENT_REVISION"
        
        # Get recent events
        log_with_timestamp "Recent events:"
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep -i "clinical\|restart\|scale" | tail -5 >> "$LOG_FILE"
        
        # Get deployment details
        log_with_timestamp "Current deployment status:"
        kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE" | grep -A5 -B5 "restartedAt\|Events:" >> "$LOG_FILE"
        
        # Send notification (customize as needed)
        echo "Deployment $DEPLOYMENT was modified. Check $LOG_FILE for details."
        
        LAST_REVISION=$CURRENT_REVISION
    fi
    
    sleep 30  # Check every 30 seconds
done

