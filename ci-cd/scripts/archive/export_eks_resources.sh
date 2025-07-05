#!/bin/bash

# Script para exportar todos los recursos de EKS organizados por namespace y tipo
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando exportación de recursos EKS...${NC}"

# Verificar que kubectl esté disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl no encontrado. Por favor instálalo primero.${NC}"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ No se puede conectar al cluster EKS. Verifica tu configuración.${NC}"
    exit 1
fi

# Crear directorio base
BASE_DIR="eks-resources-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BASE_DIR"
echo -e "${GREEN}📁 Creado directorio: $BASE_DIR${NC}"

# Función para exportar recursos de un namespace
export_namespace_resources() {
    local namespace=$1
    local ns_dir="$BASE_DIR/$namespace"
    
    echo -e "${YELLOW}📦 Procesando namespace: $namespace${NC}"
    mkdir -p "$ns_dir"
    
    # Lista de tipos de recursos comunes
    local resource_types=(
        "deployments"
        "services" 
        "configmaps"
        "secrets"
        "ingresses"
        "statefulsets"
        "daemonsets"
        "jobs"
        "cronjobs"
        "persistentvolumeclaims"
        "serviceaccounts"
        "roles"
        "rolebindings"
        "networkpolicies"
        "horizontalpodautoscalers"
        "poddisruptionbudgets"
        "endpoints"
        "replicasets"
        "pods"
    )
    
    for resource_type in "${resource_types[@]}"; do
        # Verificar si el tipo de recurso existe en el cluster
        if kubectl api-resources --namespaced=true --verbs=list -o name | grep -q "^${resource_type}$" 2>/dev/null; then
            # Obtener recursos de este tipo en el namespace
            resources=$(kubectl get "$resource_type" -n "$namespace" -o name 2>/dev/null || true)
            
            if [[ -n "$resources" ]]; then
                resource_dir="$ns_dir/$resource_type"
                mkdir -p "$resource_dir"
                echo -e "  ${BLUE}📄 Exportando $resource_type...${NC}"
                
                # Exportar cada recurso individualmente
                while IFS= read -r resource; do
                    if [[ -n "$resource" ]]; then
                        resource_name=$(echo "$resource" | cut -d'/' -f2)
                        kubectl get "$resource" -n "$namespace" -o yaml > "$resource_dir/${resource_name}.yaml" 2>/dev/null || true
                    fi
                done <<< "$resources"
                
                # También crear un archivo con todos los recursos del tipo
                kubectl get "$resource_type" -n "$namespace" -o yaml > "$resource_dir/_all_${resource_type}.yaml" 2>/dev/null || true
            fi
        fi
    done
    
    # Crear un resumen del namespace
    {
        echo "# Resumen del namespace: $namespace"
        echo "# Generado el: $(date)"
        echo ""
        kubectl describe namespace "$namespace" 2>/dev/null || true
    } > "$ns_dir/_namespace_summary.txt"
}

# Obtener todos los namespaces
echo -e "${BLUE}🔍 Obteniendo lista de namespaces...${NC}"
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

if [[ -z "$namespaces" ]]; then
    echo -e "${RED}❌ No se pudieron obtener los namespaces${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Encontrados namespaces: $namespaces${NC}"

# Exportar recursos de cada namespace
for namespace in $namespaces; do
    export_namespace_resources "$namespace"
done

# Exportar recursos a nivel de cluster (no namespaceds)
echo -e "${YELLOW}🌐 Exportando recursos a nivel de cluster...${NC}"
cluster_dir="$BASE_DIR/_cluster-resources"
mkdir -p "$cluster_dir"

cluster_resource_types=(
    "nodes"
    "persistentvolumes"
    "storageclasses"
    "clusterroles"
    "clusterrolebindings"
    "customresourcedefinitions"
    "priorityclasses"
    "runtimeclasses"
    "volumesnapshotclasses"
    "ingressclasses"
)

for resource_type in "${cluster_resource_types[@]}"; do
    if kubectl api-resources --namespaced=false --verbs=list -o name | grep -q "^${resource_type}$" 2>/dev/null; then
        resources=$(kubectl get "$resource_type" -o name 2>/dev/null || true)
        
        if [[ -n "$resources" ]]; then
            resource_dir="$cluster_dir/$resource_type"
            mkdir -p "$resource_dir"
            echo -e "  ${BLUE}📄 Exportando $resource_type...${NC}"
            
            # Exportar cada recurso individualmente
            while IFS= read -r resource; do
                if [[ -n "$resource" ]]; then
                    resource_name=$(echo "$resource" | cut -d'/' -f2)
                    kubectl get "$resource" -o yaml > "$resource_dir/${resource_name}.yaml" 2>/dev/null || true
                fi
            done <<< "$resources"
            
            # También crear un archivo con todos los recursos del tipo
            kubectl get "$resource_type" -o yaml > "$resource_dir/_all_${resource_type}.yaml" 2>/dev/null || true
        fi
    fi
done

# Crear información general del cluster
{
    echo "# Información del Cluster EKS"
    echo "# Generado el: $(date)"
    echo ""
    echo "## Información del cluster:"
    kubectl cluster-info 2>/dev/null || true
    echo ""
    echo "## Versión de Kubernetes:"
    kubectl version --short 2>/dev/null || true
    echo ""
    echo "## Nodos del cluster:"
    kubectl get nodes -o wide 2>/dev/null || true
} > "$BASE_DIR/_cluster_info.txt"

# Crear un índice con el contenido exportado
{
    echo "# Índice de recursos exportados"
    echo "# Generado el: $(date)"
    echo ""
    find "$BASE_DIR" -name "*.yaml" -o -name "*.txt" | sort
} > "$BASE_DIR/_index.txt"

echo -e "${GREEN}✅ Exportación completada!${NC}"
echo -e "${GREEN}📁 Todos los recursos han sido guardados en: $BASE_DIR${NC}"
echo -e "${BLUE}📊 Para ver un resumen, consulta: $BASE_DIR/_index.txt${NC}"

# Mostrar estadísticas
total_files=$(find "$BASE_DIR" -name "*.yaml" | wc -l)
total_namespaces=$(echo "$namespaces" | wc -w)
echo -e "${GREEN}📈 Estadísticas:${NC}"
echo -e "  • Namespaces procesados: $total_namespaces"
echo -e "  • Archivos YAML generados: $total_files"
echo -e "  • Directorio: $BASE_DIR"

