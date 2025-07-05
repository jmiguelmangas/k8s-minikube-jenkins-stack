#!/bin/bash

# Backup script for clinical history deployment
NAMESPACE="dataproducts"
DEPLOYMENT="infra-user-uat-incibe-neo-dataproducts-clinical-history"
BACKUP_DIR="$HOME/k8s-backups/clinical-history"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup of $DEPLOYMENT..."

# Backup deployment
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/deployment-$TIMESTAMP.yaml"

# Backup service (if exists)
kubectl get service -n "$NAMESPACE" -l app="$DEPLOYMENT" -o yaml > "$BACKUP_DIR/service-$TIMESTAMP.yaml" 2>/dev/null

# Backup configmaps (if any)
kubectl get configmap -n "$NAMESPACE" -o yaml | grep -A999 -B5 "clinical" > "$BACKUP_DIR/configmaps-$TIMESTAMP.yaml" 2>/dev/null

# Backup secrets (names only for security)
kubectl get secrets -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' > "$BACKUP_DIR/secret-names-$TIMESTAMP.txt" 2>/dev/null

echo "Backup completed:"
echo "  Directory: $BACKUP_DIR"
echo "  Files created:"
ls -la "$BACKUP_DIR"/*$TIMESTAMP*

# Keep only last 10 backups
find "$BACKUP_DIR" -name "*.yaml" -o -name "*.txt" | sort | head -n -30 | xargs rm -f 2>/dev/null

echo "Backup script completed successfully!"

