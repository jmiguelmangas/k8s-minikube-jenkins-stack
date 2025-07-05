#!/bin/bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    error "kubectl no está instalado o no está en el PATH"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    error "No se puede conectar al cluster de Kubernetes"
    exit 1
fi

warn "🚨 ATENCIÓN: Esta operación eliminará TODOS los recursos del stack"
warn "🚨 Esto incluye: Jenkins, N8N, PostgreSQL y TODOS sus datos"
echo ""
info "Recursos que serán eliminados:"
echo "  - Namespace: jenkins-ns"
echo "  - Namespace: n8n-ns" 
echo "  - Namespace: postgresql-ns"
echo "  - Todos los pods, servicios, deployments y PVCs"
echo "  - TODOS LOS DATOS PERSISTENTES"
echo ""

read -p "¿Estás seguro que quieres continuar? (escribe 'DELETE' para confirmar): " confirmation

if [ "$confirmation" != "DELETE" ]; then
    info "Operación cancelada"
    exit 0
fi

log "🗑️ Iniciando limpieza completa del stack..."

# Función para eliminar namespace con timeout
delete_namespace() {
    local ns=$1
    log "🗑️ Eliminando namespace: $ns"
    
    if kubectl get namespace "$ns" &>/dev/null; then
        kubectl delete namespace "$ns" --timeout=60s
        
        # Esperar a que el namespace sea eliminado completamente
        log "⏳ Esperando a que $ns sea eliminado completamente..."
        while kubectl get namespace "$ns" &>/dev/null; do
            sleep 2
            echo -n "."
        done
        echo ""
        log "✅ Namespace $ns eliminado"
    else
        warn "Namespace $ns no existe"
    fi
}

# Eliminar aplicaciones en orden inverso
log "🏗️ Paso 1: Eliminando Jenkins..."
delete_namespace "jenkins-ns"

log "🔄 Paso 2: Eliminando N8N..."
delete_namespace "n8n-ns"

log "🐘 Paso 3: Eliminando PostgreSQL..."
delete_namespace "postgresql-ns"

log "📊 Paso 4: Eliminando namespace de monitoreo..."
delete_namespace "monitoring-ns"

# Limpiar PVs huérfanos si existen
log "🧹 Paso 5: Limpiando volúmenes persistentes huérfanos..."
orphaned_pvs=$(kubectl get pv --no-headers | grep "Released" | awk '{print $1}' || true)

if [ -n "$orphaned_pvs" ]; then
    warn "Encontrados PVs huérfanos: $orphaned_pvs"
    echo "$orphaned_pvs" | xargs -r kubectl delete pv
    log "✅ PVs huérfanos eliminados"
else
    info "No se encontraron PVs huérfanos"
fi

# Verificar limpieza
log "✅ Paso 6: Verificando limpieza..."

echo ""
info "=== VERIFICACIÓN POST-LIMPIEZA ==="

echo ""
info "Namespaces restantes:"
kubectl get namespaces | grep -E "(jenkins|n8n|postgresql|monitoring)" || echo "✅ No quedan namespaces del stack"

echo ""
info "Volúmenes persistentes restantes:"
kubectl get pv | grep -E "(jenkins|n8n|postgresql)" || echo "✅ No quedan PVs del stack"

echo ""
info "Pods restantes (debería estar vacío):"
kubectl get pods --all-namespaces | grep -E "(jenkins|n8n|postgresql)" || echo "✅ No quedan pods del stack"

echo ""
log "🎉 Limpieza completa terminada!"

echo ""
info "=== RESUMEN ==="
echo "  ✅ Jenkins eliminado completamente"
echo "  ✅ N8N eliminado completamente"
echo "  ✅ PostgreSQL eliminado completamente"
echo "  ✅ Datos persistentes eliminados"
echo "  ✅ Namespaces eliminados"
echo ""
log "🧹 Stack completamente limpio!"

echo ""
info "Para volver a desplegar el stack:"
echo "  cd k8s-deployments/ci-cd/scripts/"
echo "  ./deploy-all.sh"
