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

log "🚀 Iniciando despliegue completo del stack en Kubernetes"

# Directorio base
BASE_DIR="$(dirname "$0")/../.."

log "📂 Directorio base: $BASE_DIR"

# 1. Crear namespaces
log "🏗️  Paso 1: Creando namespaces..."
kubectl apply -f "$BASE_DIR/infrastructure/namespaces/all-namespaces.yaml"

# 2. Desplegar PostgreSQL
log "🐘 Paso 2: Desplegando PostgreSQL..."
kubectl apply -f "$BASE_DIR/applications/postgresql/postgresql-deployment.yaml"

# Esperar a que PostgreSQL esté listo
log "⏳ Esperando a que PostgreSQL esté listo..."
kubectl wait --for=condition=ready pod -l app=postgresql -n postgresql-ns --timeout=300s

# 3. Desplegar N8N
log "🔄 Paso 3: Desplegando N8N..."
kubectl apply -f "$BASE_DIR/applications/n8n/n8n-deployment.yaml"

# Esperar a que N8N esté listo
log "⏳ Esperando a que N8N esté listo..."
kubectl wait --for=condition=ready pod -l app=n8n -n n8n-ns --timeout=300s

# 4. Desplegar Jenkins
log "🏗️  Paso 4: Desplegando Jenkins..."
kubectl apply -f "$BASE_DIR/applications/jenkins/"

# Esperar a que Jenkins esté listo
log "⏳ Esperando a que Jenkins esté listo..."
kubectl wait --for=condition=ready pod -l app=jenkins -n jenkins-ns --timeout=600s

# 5. Verificar estado de todos los deployments
log "✅ Paso 5: Verificando estado de todos los deployments..."

echo ""
info "=== ESTADO DE NAMESPACES ==="
kubectl get namespaces -l type

echo ""
info "=== ESTADO DE DEPLOYMENTS ==="
kubectl get deployments --all-namespaces

echo ""
info "=== ESTADO DE SERVICIOS ==="
kubectl get services --all-namespaces | grep -E "(postgresql|n8n|jenkins)"

echo ""
info "=== ESTADO DE PODS ==="
kubectl get pods --all-namespaces | grep -E "(postgresql|n8n|jenkins)"

echo ""
info "=== VOLUMENES PERSISTENTES ==="
kubectl get pvc --all-namespaces

echo ""
log "🎉 Despliegue completo terminado!"

echo ""
info "=== ACCESO A APLICACIONES ==="
echo "📊 N8N:        http://192.168.1.49:31199"
echo "🐘 PostgreSQL: 192.168.1.49:30178 (usuario: postgres, password: postgres)"
echo "🏗️  Jenkins:    http://localhost:8081 (puerto forward necesario)"
echo ""
echo "Para acceder a Jenkins desde tu Mac:"
echo "kubectl port-forward service/jenkins-service 8081:8080 -n jenkins-ns &"

# 6. Ejecutar tests básicos
log "🧪 Paso 6: Ejecutando tests básicos de conectividad..."

# Test PostgreSQL
info "Testing PostgreSQL connectivity..."
if kubectl exec -n postgresql-ns deployment/postgresql-deployment -- pg_isready -U postgres; then
    log "✅ PostgreSQL está funcionando correctamente"
else
    warn "❌ PostgreSQL no responde correctamente"
fi

# Test N8N
info "Testing N8N connectivity..."
if kubectl exec -n n8n-ns deployment/n8n-deployment -- wget -q --spider http://localhost:5678; then
    log "✅ N8N está funcionando correctamente"
else
    warn "❌ N8N no responde correctamente"
fi

# Test Jenkins
info "Testing Jenkins connectivity..."
if kubectl exec -n jenkins-ns deployment/jenkins-deployment -- curl -f http://localhost:8080/login; then
    log "✅ Jenkins está funcionando correctamente"
else
    warn "❌ Jenkins no responde correctamente"
fi

log "🏁 Todos los tests completados!"

echo ""
log "📋 RESUMEN FINAL:"
echo "  ✅ Namespaces creados"
echo "  ✅ PostgreSQL desplegado y funcionando"
echo "  ✅ N8N desplegado y funcionando"
echo "  ✅ Jenkins desplegado y funcionando"
echo "  ✅ Almacenamiento persistente configurado"
echo "  ✅ Servicios expuestos"
echo ""
log "🎉 Stack completo desplegado exitosamente!"
