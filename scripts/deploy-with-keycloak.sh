#!/bin/bash

# Deploy Kubernetes stack with Keycloak authentication
# This script deploys the entire stack with centralized authentication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    print_status "Waiting for deployment $deployment in namespace $namespace to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace
    if [ $? -eq 0 ]; then
        print_success "Deployment $deployment is ready"
    else
        print_error "Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for pod to be ready
wait_for_pod() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    print_status "Waiting for pod with label $label in namespace $namespace to be ready..."
    kubectl wait --for=condition=ready --timeout=${timeout}s pod -l $label -n $namespace
    if [ $? -eq 0 ]; then
        print_success "Pod with label $label is ready"
    else
        print_error "Pod with label $label failed to become ready within ${timeout}s"
        return 1
    fi
}

print_status "Starting deployment of Kubernetes stack with Keycloak authentication..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Deploy namespaces
print_status "Creating namespaces..."
kubectl apply -f manifests/keycloak-namespace.yaml
kubectl apply -f namespaces/jenkins-ns.yaml
kubectl apply -f namespaces/n8n-ns.yaml
kubectl apply -f namespaces/postgres-ns.yaml

# Deploy RBAC
print_status "Setting up RBAC..."
kubectl apply -f rbac/

# Deploy PostgreSQL for applications
print_status "Deploying PostgreSQL for applications..."
kubectl apply -f applications/postgres/
wait_for_deployment postgres postgres-deployment

# Deploy Keycloak PostgreSQL
print_status "Deploying Keycloak PostgreSQL..."
kubectl apply -f manifests/keycloak-postgres.yaml
wait_for_deployment keycloak keycloak-postgres 600

# Deploy Keycloak
print_status "Deploying Keycloak..."
kubectl apply -f manifests/keycloak-deployment.yaml
wait_for_deployment keycloak keycloak 600

# Wait for Keycloak to be fully ready
print_status "Waiting for Keycloak to be fully operational..."
sleep 30

# Deploy Keycloak OIDC configurations for Jenkins
print_status "Deploying Jenkins OIDC configuration..."
kubectl apply -f manifests/jenkins-keycloak-config.yaml

# Deploy Jenkins with Keycloak integration
print_status "Deploying Jenkins with Keycloak authentication..."
kubectl apply -f applications/jenkins/jenkins-pv.yaml
kubectl apply -f applications/jenkins/jenkins-pvc.yaml
kubectl apply -f applications/jenkins/jenkins-sa.yaml
kubectl apply -f manifests/jenkins-deployment-keycloak.yaml
kubectl apply -f applications/jenkins/jenkins-service.yaml

wait_for_deployment jenkins jenkins-deployment 600

# Deploy N8N
print_status "Deploying N8N..."
kubectl apply -f applications/n8n/
wait_for_deployment n8n n8n-deployment

print_success "All deployments completed!"

# Display access information
print_status "Getting service information..."
echo ""
echo "=================== SERVICE ACCESS INFORMATION ==================="
echo ""

# Keycloak access
KEYCLOAK_PORT=$(kubectl get svc keycloak -n keycloak -o jsonpath='{.spec.ports[0].port}')
print_status "Keycloak Admin Console:"
echo "  URL: http://localhost:8090 (after port-forward)"
echo "  Admin Username: admin"
echo "  Admin Password: admin123"
echo "  Port-forward command: kubectl port-forward svc/keycloak 8090:8080 -n keycloak"
echo ""

# Jenkins access
JENKINS_PORT=$(kubectl get svc jenkins-service -n jenkins -o jsonpath='{.spec.ports[0].port}')
print_status "Jenkins:"
echo "  URL: http://localhost:8081 (after port-forward)"
echo "  Authentication: Via Keycloak OIDC"
echo "  Emergency Admin: admin/admin123 (escape hatch)"
echo "  Port-forward command: kubectl port-forward svc/jenkins-service 8081:8080 -n jenkins"
echo ""

# N8N access
N8N_PORT=$(kubectl get svc n8n-service -n n8n -o jsonpath='{.spec.ports[0].port}')
print_status "N8N:"
echo "  URL: http://localhost:5678 (after port-forward)"
echo "  Port-forward command: kubectl port-forward svc/n8n-service 5678:80 -n n8n"
echo ""

# PostgreSQL access
POSTGRES_PORT=$(kubectl get svc postgres-service -n postgres -o jsonpath='{.spec.ports[0].port}')
print_status "PostgreSQL:"
echo "  Host: localhost:5432 (after port-forward)"
echo "  Username: postgres"
echo "  Password: postgres123"
echo "  Port-forward command: kubectl port-forward svc/postgres-service 5432:5432 -n postgres"
echo ""

print_warning "IMPORTANT: Keycloak Configuration Required"
echo "Before using Jenkins with OIDC authentication, you need to configure Keycloak:"
echo ""
echo "1. Access Keycloak Admin Console at http://localhost:8090"
echo "2. Create a new realm called 'k8s-stack'"
echo "3. Create OIDC client 'jenkins' with:"
echo "   - Client ID: jenkins"
echo "   - Client Secret: jenkins-secret"
echo "   - Valid Redirect URIs: http://jenkins.local:8080/securityRealm/finishLogin"
echo "   - Web Origins: http://jenkins.local:8080"
echo "4. Create users and groups (jenkins-admins, jenkins-developers, jenkins-viewers)"
echo ""

print_success "Deployment completed! Remember to configure Keycloak before using the services."

# Optional: Start port-forwarding
read -p "Do you want to start port-forwarding for all services? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Starting port-forwarding for all services..."
    
    # Start port-forwarding in background
    kubectl port-forward svc/keycloak 8090:8080 -n keycloak &
    KEYCLOAK_PF_PID=$!
    
    kubectl port-forward svc/jenkins-service 8081:8080 -n jenkins &
    JENKINS_PF_PID=$!
    
    kubectl port-forward svc/n8n-service 5678:80 -n n8n &
    N8N_PF_PID=$!
    
    kubectl port-forward svc/postgres-service 5432:5432 -n postgres &
    POSTGRES_PF_PID=$!
    
    echo ""
    print_success "Port-forwarding started for all services!"
    echo "Press Ctrl+C to stop all port-forwarding"
    
    # Wait for interrupt
    trap 'kill $KEYCLOAK_PF_PID $JENKINS_PF_PID $N8N_PF_PID $POSTGRES_PF_PID; exit' INT
    wait
fi
