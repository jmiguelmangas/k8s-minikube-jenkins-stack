#!/bin/bash

# Script optimizado para exportar todos los recursos de EKS
set -e

echo "🚀 Iniciando exportación de recursos EKS..."

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl no encontrado"
    exit 1
fi

# Crear directorio con timestamp
BASE_DIR="eks-resources-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BASE_DIR"
echo "📁 Directorio creado: $BASE_DIR"

# Obtener namespaces
echo "🔍 Obteniendo namespaces..."
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')
echo "✅ Namespaces encontrados: $(echo $namespaces | wc -w)"

# Tipos de recursos a exportar
NAMESPACE_RESOURCES="deployments,services,configmaps,secrets,ingresses,statefulsets,daemonsets,jobs,cronjobs,pvc,serviceaccounts,roles,rolebindings,networkpolicies,hpa"
CLUSTER_RESOURCES="nodes,persistentvolumes,storageclasses,clusterroles,clusterrolebindings,customresourcedefinitions"

# Función para exportar recursos de un namespace
export_namespace() {
    local ns=$1
    local ns_dir="$BASE_DIR/$ns"
    
    echo "📦 Procesando namespace: $ns"
    mkdir -p "$ns_dir"
    
    # Deployments
    if kubectl get deployments -n "$ns" -o name 2>/dev/null | grep -q deployment; then
        mkdir -p "$ns_dir/deployments"
        kubectl get deployments -n "$ns" -o yaml > "$ns_dir/deployments/all-deployments.yaml" 2>/dev/null || true
        for deploy in $(kubectl get deployments -n "$ns" -o name 2>/dev/null); do
            name=$(echo $deploy | cut -d'/' -f2)
            kubectl get "$deploy" -n "$ns" -o yaml > "$ns_dir/deployments/$name.yaml" 2>/dev/null || true
        done
        echo "  ✅ Deployments exportados"
    fi
    
    # Services
    if kubectl get services -n "$ns" -o name 2>/dev/null | grep -q service; then
        mkdir -p "$ns_dir/services"
        kubectl get services -n "$ns" -o yaml > "$ns_dir/services/all-services.yaml" 2>/dev/null || true
        for svc in $(kubectl get services -n "$ns" -o name 2>/dev/null); do
            name=$(echo $svc | cut -d'/' -f2)
            kubectl get "$svc" -n "$ns" -o yaml > "$ns_dir/services/$name.yaml" 2>/dev/null || true
        done
        echo "  ✅ Services exportados"
    fi
    
    # ConfigMaps
    if kubectl get configmaps -n "$ns" -o name 2>/dev/null | grep -q configmap; then
        mkdir -p "$ns_dir/configmaps"
        kubectl get configmaps -n "$ns" -o yaml > "$ns_dir/configmaps/all-configmaps.yaml" 2>/dev/null || true
        for cm in $(kubectl get configmaps -n "$ns" -o name 2>/dev/null | head -20); do
            name=$(echo $cm | cut -d'/' -f2)
            kubectl get "$cm" -n "$ns" -o yaml > "$ns_dir/configmaps/$name.yaml" 2>/dev/null || true
        done
        echo "  ✅ ConfigMaps exportados"
    fi
    
    # Secrets (solo nombres por seguridad)
    if kubectl get secrets -n "$ns" -o name 2>/dev/null | grep -q secret; then
        mkdir -p "$ns_dir/secrets"
        kubectl get secrets -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > "$ns_dir/secrets/secret-names.txt" 2>/dev/null || true
        echo "  ✅ Nombres de secrets exportados"
    fi
    
    # Ingresses
    if kubectl get ingresses -n "$ns" -o name 2>/dev/null | grep -q ingress; then
        mkdir -p "$ns_dir/ingresses"
        kubectl get ingresses -n "$ns" -o yaml > "$ns_dir/ingresses/all-ingresses.yaml" 2>/dev/null || true
        echo "  ✅ Ingresses exportados"
    fi
    
    # StatefulSets
    if kubectl get statefulsets -n "$ns" -o name 2>/dev/null | grep -q statefulset; then
        mkdir -p "$ns_dir/statefulsets"
        kubectl get statefulsets -n "$ns" -o yaml > "$ns_dir/statefulsets/all-statefulsets.yaml" 2>/dev/null || true
        echo "  ✅ StatefulSets exportados"
    fi
    
    # DaemonSets
    if kubectl get daemonsets -n "$ns" -o name 2>/dev/null | grep -q daemonset; then
        mkdir -p "$ns_dir/daemonsets"
        kubectl get daemonsets -n "$ns" -o yaml > "$ns_dir/daemonsets/all-daemonsets.yaml" 2>/dev/null || true
        echo "  ✅ DaemonSets exportados"
    fi
    
    # Pods (solo un resumen)
    if kubectl get pods -n "$ns" -o name 2>/dev/null | grep -q pod; then
        mkdir -p "$ns_dir/pods"
        kubectl get pods -n "$ns" -o wide > "$ns_dir/pods/pod-list.txt" 2>/dev/null || true
        echo "  ✅ Lista de Pods exportada"
    fi
}

# Exportar cada namespace
for ns in $namespaces; do
    export_namespace "$ns"
done

# Exportar recursos a nivel de cluster
echo "🌐 Exportando recursos de cluster..."
cluster_dir="$BASE_DIR/_cluster-resources"
mkdir -p "$cluster_dir"

# Nodes
kubectl get nodes -o yaml > "$cluster_dir/nodes.yaml" 2>/dev/null || true
kubectl get nodes -o wide > "$cluster_dir/nodes-wide.txt" 2>/dev/null || true

# Storage Classes
kubectl get storageclasses -o yaml > "$cluster_dir/storageclasses.yaml" 2>/dev/null || true

# Persistent Volumes
kubectl get persistentvolumes -o yaml > "$cluster_dir/persistentvolumes.yaml" 2>/dev/null || true

# Cluster Roles
kubectl get clusterroles -o yaml > "$cluster_dir/clusterroles.yaml" 2>/dev/null || true

# Cluster Role Bindings
kubectl get clusterrolebindings -o yaml > "$cluster_dir/clusterrolebindings.yaml" 2>/dev/null || true

# Custom Resource Definitions
kubectl get customresourcedefinitions -o yaml > "$cluster_dir/crds.yaml" 2>/dev/null || true

echo "✅ Recursos de cluster exportados"

# Crear información del cluster
{
    echo "# Información del Cluster EKS"
    echo "# Generado: $(date)"
    echo ""
    echo "## Cluster Info:"
    kubectl cluster-info 2>/dev/null || true
    echo ""
    echo "## Versión:"
    kubectl version --short 2>/dev/null || true
    echo ""
    echo "## Namespaces:"
    kubectl get namespaces 2>/dev/null || true
} > "$BASE_DIR/cluster-info.txt"

# Crear índice
{
    echo "# Índice de archivos exportados - $(date)"
    echo ""
    find "$BASE_DIR" -name "*.yaml" -o -name "*.txt" | sort
} > "$BASE_DIR/index.txt"

# Estadísticas finales
yaml_count=$(find "$BASE_DIR" -name "*.yaml" | wc -l)
ns_count=$(echo "$namespaces" | wc -w)

echo ""
echo "✅ ¡Exportación completada!"
echo "📁 Directorio: $BASE_DIR"
echo "📊 Estadísticas:"
echo "   • Namespaces: $ns_count"
echo "   • Archivos YAML: $yaml_count"
echo "   • Ver índice: $BASE_DIR/index.txt"
echo ""
echo "🔍 Para explorar:"
echo "   cd $BASE_DIR"
echo "   cat index.txt"

