#!/bin/bash

# Recovery script for clinical history deployment
NAMESPACE="dataproducts"
DEPLOYMENT="infra-user-uat-incibe-neo-dataproducts-clinical-history"
BACKUP_DIR="$HOME/k8s-backups/clinical-history"

if [ $# -eq 0 ]; then
    echo "Usage: $0 [backup-timestamp|latest]"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/deployment-*.yaml 2>/dev/null | awk '{print $9}' | sed 's/.*deployment-//' | sed 's/.yaml//' || echo "No backups found"
    exit 1
fi

if [ "$1" == "latest" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/deployment-*.yaml 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        echo "No backup files found in $BACKUP_DIR"
        exit 1
    fi
    TIMESTAMP=$(basename "$BACKUP_FILE" | sed 's/deployment-//' | sed 's/.yaml//')
else
    TIMESTAMP="$1"
    BACKUP_FILE="$BACKUP_DIR/deployment-$TIMESTAMP.yaml"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Restoring clinical history deployment from backup: $TIMESTAMP"
echo "Backup file: $BACKUP_FILE"

# Show current state
echo ""
echo "Current deployment state:"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o wide 2>/dev/null || echo "Deployment not found"

echo ""
read -p "Do you want to proceed with the restore? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Apply the backup
echo "Applying backup..."
kubectl apply -f "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Restore completed successfully!"
    echo ""
    echo "New deployment state:"
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o wide
    
    echo ""
    echo "Waiting for deployment to be ready..."
    kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=300s
else
    echo "❌ Restore failed. Check the backup file and try again."
    exit 1
fi

