#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to start port forwarding
start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local service_port=$4
    local description=$5
    
    print_status "Starting port forward for $description..."
    kubectl port-forward svc/$service $local_port:$service_port -n $namespace > /dev/null 2>&1 &
    local pid=$!
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        print_success "$description available at http://localhost:$local_port"
        echo $pid
    else
        print_warning "Failed to start port forward for $description"
        echo "0"
    fi
}

echo "🚀 Setting up port forwarding for all services..."
echo ""

# Store PIDs for cleanup
PIDS=()

# Keycloak
KEYCLOAK_PID=$(start_port_forward "keycloak" "keycloak" "8090" "8080" "Keycloak Admin Console")
if [ "$KEYCLOAK_PID" != "0" ]; then
    PIDS+=($KEYCLOAK_PID)
fi

# Jenkins
JENKINS_PID=$(start_port_forward "jenkins-service" "jenkins" "8081" "8080" "Jenkins CI/CD")
if [ "$JENKINS_PID" != "0" ]; then
    PIDS+=($JENKINS_PID)
fi

# N8N
N8N_PID=$(start_port_forward "n8n" "n8n" "5678" "5678" "N8N Workflow Automation")
if [ "$N8N_PID" != "0" ]; then
    PIDS+=($N8N_PID)
fi

# PostgreSQL
POSTGRES_PID=$(start_port_forward "postgresql" "postgresql" "5432" "5432" "PostgreSQL Database")
if [ "$POSTGRES_PID" != "0" ]; then
    PIDS+=($POSTGRES_PID)
fi

# pgAdmin
PGADMIN_PID=$(start_port_forward "pgadmin" "postgresql" "8082" "80" "pgAdmin Database Admin")
if [ "$PGADMIN_PID" != "0" ]; then
    PIDS+=($PGADMIN_PID)
fi

echo ""
echo "🔗 ACCESS INFORMATION"
echo "=========================="
echo ""
echo "🔐 Keycloak Admin Console:"
echo "   URL: http://localhost:8090/admin/"
echo "   Admin: admin / admin123"
echo ""
echo "🔧 Jenkins CI/CD:"
echo "   URL: http://localhost:8081"
echo "   Auth: Keycloak OIDC (user: jmiguelmangas / leicakanon2025)"
echo "   Emergency: admin / leicakanon2025 (escape hatch)"
echo ""
echo "⚡ N8N Workflow Automation:"
echo "   URL: http://localhost:5678"
echo "   Auth: Keycloak OIDC (user: jmiguelmangas / leicakanon2025)"
echo ""
echo "🗄️  PostgreSQL Database:"
echo "   Host: localhost:5432"
echo "   User: postgres / postgres-password"
echo ""
echo "📊 pgAdmin Database Admin:"
echo "   URL: http://localhost:8082"
echo "   Auth: Keycloak OIDC (user: jmiguelmangas / leicakanon2025)"
echo "   Emergency: admin@example.com / pgadmin-password"
echo ""
echo "👥 User Groups in Keycloak:"
echo "   - jenkins-admins: Full Jenkins access"
echo "   - jenkins-developers: Jenkins build access"
echo "   - jenkins-viewers: Jenkins read-only access"
echo "   - n8n-admins: Full N8N access"
echo "   - postgres-admins: PostgreSQL/pgAdmin access"
echo ""
print_warning "Press Ctrl+C to stop all port forwarding"

# Function to cleanup on exit
cleanup() {
    echo ""
    print_status "Stopping all port forwarding..."
    for pid in "${PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            kill $pid
        fi
    done
    print_success "All port forwarding stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup INT

# Wait for interrupt
if [ ${#PIDS[@]} -gt 0 ]; then
    wait
else
    print_warning "No port forwarding was started successfully"
fi
