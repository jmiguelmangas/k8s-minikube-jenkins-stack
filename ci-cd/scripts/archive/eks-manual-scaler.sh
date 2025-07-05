#!/bin/bash

# EKS Manual Scaler Utility
# Usage: ./eks-manual-scaler.sh [up|down|status]

set -e

NAMESPACES="airflow alerts-module dataproducts demo-marketplace development-marketplace jenkins jupyterlab-dask neo-audit-module neo-backend neo-backend-ai neoris-hcr-connector neoris-hcr-spark"

function show_status() {
    echo "=== EKS Services Status ==="
    echo "Timestamp: $(date)"
    echo ""
    
    for ns in $NAMESPACES; do
        echo "Namespace: $ns"
        kubectl get deployments -n $ns -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas" 2>/dev/null || echo "  No deployments found"
        echo ""
    done
}

function scale_down() {
    echo "=== Scaling Down Services ==="
    echo "Timestamp: $(date)"
    echo ""
    
    # Create ConfigMap to store original replica counts if it doesn't exist
    kubectl create configmap eks-replica-backup --from-literal=dummy=value -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    
    for ns in $NAMESPACES; do
        echo "Processing namespace: $ns"
        
        deployments=$(kubectl get deployments -n $ns -o name 2>/dev/null || true)
        
        for deployment in $deployments; do
            if [ ! -z "$deployment" ]; then
                current_replicas=$(kubectl get $deployment -n $ns -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                
                if [ "$current_replicas" -gt 0 ]; then
                    deployment_name=$(echo $deployment | sed 's/deployment\.apps\///g')
                    
                    # Store original replica count
                    kubectl patch configmap eks-replica-backup -n kube-system --type merge -p "{\"data\":{\"${ns}-${deployment_name}\":\"${current_replicas}\"}}"
                    
                    # Scale down to 0
                    kubectl scale $deployment -n $ns --replicas=0
                    echo "  Scaled down $deployment from $current_replicas to 0"
                else
                    echo "  $deployment already at 0 replicas"
                fi
            fi
        done
        echo ""
    done
    
    echo "Scale down completed!"
}

function scale_up() {
    echo "=== Scaling Up Services ==="
    echo "Timestamp: $(date)"
    echo ""
    
    # Check if backup ConfigMap exists
    if ! kubectl get configmap eks-replica-backup -n kube-system >/dev/null 2>&1; then
        echo "Error: No backup ConfigMap found. Cannot restore replica counts."
        exit 1
    fi
    
    for ns in $NAMESPACES; do
        echo "Processing namespace: $ns"
        
        deployments=$(kubectl get deployments -n $ns -o name 2>/dev/null || true)
        
        for deployment in $deployments; do
            if [ ! -z "$deployment" ]; then
                deployment_name=$(echo $deployment | sed 's/deployment\.apps\///g')
                backup_key="${ns}-${deployment_name}"
                
                # Get original replica count from backup
                original_replicas=$(kubectl get configmap eks-replica-backup -n kube-system -o jsonpath="{.data.${backup_key}}" 2>/dev/null || echo "")
                
                if [ ! -z "$original_replicas" ] && [ "$original_replicas" -gt 0 ]; then
                    current_replicas=$(kubectl get $deployment -n $ns -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                    
                    if [ "$current_replicas" -eq 0 ]; then
                        kubectl scale $deployment -n $ns --replicas=$original_replicas
                        echo "  Scaled up $deployment from 0 to $original_replicas"
                    else
                        echo "  $deployment already has $current_replicas replicas"
                    fi
                else
                    echo "  No backup found for $deployment or original was 0"
                fi
            fi
        done
        echo ""
    done
    
    echo "Scale up completed!"
}

function show_help() {
    echo "EKS Manual Scaler Utility"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  up      Scale up all services to their original replica counts"
    echo "  down    Scale down all services to 0 replicas"
    echo "  status  Show current status of all services"
    echo "  help    Show this help message"
    echo ""
    echo "Managed namespaces:"
    for ns in $NAMESPACES; do
        echo "  - $ns"
    done
}

# Main script logic
case "${1:-help}" in
    "up")
        scale_up
        ;;
    "down")
        scale_down
        ;;
    "status")
        show_status
        ;;
    "help"|*)
        show_help
        ;;
esac
