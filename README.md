# Kubernetes Minikube Jenkins Stack

A complete CI/CD platform built on Minikube with Jenkins, including automated deployment scripts and monitoring capabilities.

## 🚀 Overview

This project provides a comprehensive Kubernetes-based development environment featuring:

- **Jenkins CI/CD** with automatic plugin installation and configuration
- **Keycloak SSO** for centralized authentication and authorization
- **Kubernetes manifests** for multiple applications (N8N, PostgreSQL, Jenkins)
- **Automated deployment scripts** for easy stack management
- **Remote access configuration** for minikube clusters
- **Persistent storage** and proper RBAC configuration
- **OIDC integration** for all services with group-based access control

## 📋 Prerequisites

- **Minikube** installed and running
- **kubectl** configured to access your cluster
- **SSH access** to the minikube host (if running remotely)
- **Docker** for building custom images (optional)

## 🏗️ Architecture

```
k8s-minikube-jenkins-stack/
├── applications/           # Application-specific manifests
│   ├── jenkins/           # Jenkins deployment with tools
│   ├── n8n/              # N8N workflow automation
│   └── postgresql/        # PostgreSQL database
├── infrastructure/        # Base infrastructure
│   ├── namespaces/       # Namespace definitions
│   ├── rbac/             # RBAC configurations
│   └── storage/          # Storage classes and PVCs
├── manifests/             # Keycloak integration manifests
│   ├── keycloak-*.yaml   # Keycloak deployment and configuration
│   ├── *-keycloak.yaml   # Service integrations with Keycloak
│   └── *-keycloak-config.yaml # OIDC configurations
├── scripts/               # Automation scripts
│   ├── deploy-with-keycloak.sh    # Deploy with Keycloak integration
│   ├── configure-keycloak.sh      # Configure Keycloak clients
│   └── setup-port-forwards.sh     # Port forwarding for all services
├── monitoring/            # Monitoring stack (placeholder)
├── ci-cd/                # CI/CD pipeline definitions
│   ├── scripts/          # Deployment scripts
│   └── pipelines/        # Jenkins pipeline definitions
└── docs/                 # Documentation
    └── keycloak-setup.md # Keycloak integration guide
```

## 🚀 Quick Start

### 1. Deploy the Complete Stack

```bash
# Make the deployment script executable
chmod +x ci-cd/scripts/deploy-all.sh

# Deploy all components
./ci-cd/scripts/deploy-all.sh
```

### 1b. Deploy with Keycloak Integration (Recommended)

```bash
# Deploy complete stack with Keycloak SSO
chmod +x scripts/deploy-with-keycloak.sh
./scripts/deploy-with-keycloak.sh

# Configure Keycloak clients and users
chmod +x scripts/configure-keycloak.sh
./scripts/configure-keycloak.sh

# Setup port forwarding for all services
chmod +x scripts/setup-port-forwards.sh
./scripts/setup-port-forwards.sh
```

### 2. Access Services

#### With Keycloak Integration (SSO)

```bash
# Access services with centralized authentication:
# - Keycloak Admin Console: http://localhost:8090/admin/
# - Jenkins: http://localhost:8081 (with OIDC login)
# - N8N: http://localhost:5678 (with OAuth2 login)
# - pgAdmin: http://localhost:5050 (with OAuth2 login)
# - PostgreSQL: localhost:5432 (with Keycloak users)

# Default Keycloak credentials:
# Username: jmiguelmangas
# Password: leicakanon2025
```

#### Without Keycloak (Manual Port Forwarding)

```bash
# Get Jenkins pod name
kubectl get pods -n jenkins-ns

# Port forward to access Jenkins UI
kubectl port-forward -n jenkins-ns pod/jenkins-deployment-xxx 8081:8080

# Access Jenkins at http://localhost:8081
```

### 3. Configure Remote Access (Optional)

If your minikube is running on a remote server:

```bash
# Create SSH tunnel to API server
ssh -L 8443:localhost:8443 user@your-server

# Update kubeconfig to point to localhost:8443
kubectl config set-cluster minikube --server=https://localhost:8443
```

## 🔧 Components

### Jenkins Configuration
- **Custom image** with kubectl, curl, git, jq, and bash
- **Automatic plugin installation** via ConfigMap
- **Jenkins Configuration as Code** (JCasC)
- **Persistent storage** for Jenkins home
- **RBAC** for cluster access

### Applications
- **N8N**: Workflow automation platform
- **PostgreSQL**: Database for applications
- **Jenkins**: CI/CD automation server

### Infrastructure
- **Namespaces**: Logical separation of resources
- **RBAC**: Role-based access control
- **Storage**: Persistent volumes and claims

## 🔐 Keycloak Integration

### SSO Features
- **Centralized Authentication**: Single sign-on for all services
- **OIDC Integration**: OAuth2/OpenID Connect for Jenkins, N8N, PostgreSQL
- **Group-based Access Control**: Role management through Keycloak groups
- **Automated Configuration**: Scripts for client and user setup

### Keycloak Configuration
- **Realm**: `minikube-realm` with all service clients
- **Users**: Pre-configured admin user with group memberships
- **Groups**: `jenkins-admins`, `n8n-users`, `postgresql-users`
- **Clients**: Configured for each service with proper redirect URIs

### Service Integrations
- **Jenkins**: OIDC plugin with automatic user creation
- **N8N**: OAuth2 authentication with Keycloak provider
- **PostgreSQL**: pgAdmin OAuth2 integration
- **Keycloak**: Admin console for user/group management

### Access URLs (with port forwarding)
- **Keycloak Admin**: http://localhost:8090/admin/
- **Jenkins**: http://localhost:8081 (OIDC login)
- **N8N**: http://localhost:5678 (OAuth2 login)
- **pgAdmin**: http://localhost:5050 (OAuth2 login)

## 📋 Available Scripts

| Script | Description |
|--------|-------------|
| `ci-cd/scripts/deploy-all.sh` | Deploy complete stack (basic) |
| `ci-cd/scripts/cleanup.sh` | Clean up all resources |
| `ci-cd/scripts/create-main-pipeline.sh` | Create Jenkins pipeline via API |
| `scripts/deploy-with-keycloak.sh` | Deploy with Keycloak integration |
| `scripts/configure-keycloak.sh` | Configure Keycloak clients and users |
| `scripts/setup-port-forwards.sh` | Setup port forwarding for all services |

## 🔄 Jenkins Pipelines

### Main Deployment Pipeline
Located in `ci-cd/pipelines/`, this pipeline:
1. Deploys all Kubernetes manifests
2. Waits for pods to be ready
3. Runs connectivity tests
4. Provides deployment status

### Pipeline Scripts
- `pipeline-optimizado.groovy`: Advanced pipeline with error handling
- `pipeline-simple.groovy`: Basic deployment pipeline

## 🔍 Monitoring

The monitoring directory is prepared for future monitoring stack deployment (Prometheus, Grafana, etc.).

## 🛠️ Customization

### Adding New Applications
1. Create manifests in `applications/your-app/`
2. Update `deploy-all.sh` to include your app
3. Add to cleanup script if needed

### Modifying Jenkins
- Update `applications/jenkins/configmap-*.yaml` for plugins/config
- Modify `applications/jenkins/deployment.yaml` for container specs
- Use `applications/jenkins/rbac.yaml` for permissions

## 📚 Documentation

- `PROJECT-SUMMARY.md`: Complete project overview
- `jenkins-setup-summary.md`: Jenkins-specific setup details
- `applications/README.md`: Application-specific documentation
- `docs/keycloak-setup.md`: Keycloak integration and configuration guide
- `KEYCLOAK_INTEGRATION_STATUS.md`: Current integration status and roadmap

## 🔧 Troubleshooting

### Common Issues

1. **Jenkins pod not starting**: Check resource limits and node capacity
2. **SSH connection refused**: Verify SSH keys and server configuration
3. **kubectl permission denied**: Check RBAC configuration
4. **Pipeline hanging**: Ensure all tools are installed in Jenkins container
5. **Keycloak login fails**: Check client configuration and redirect URIs
6. **OIDC authentication issues**: Verify client secrets and realm configuration
7. **Port forwarding not working**: Check if pods are running and ports are correct

### Debugging Commands

```bash
# Check pod logs
kubectl logs -n jenkins-ns deployment/jenkins-deployment
kubectl logs -n keycloak-ns deployment/keycloak

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Verify connectivity
kubectl exec -it -n jenkins-ns deployment/jenkins-deployment -- kubectl get nodes

# Check Keycloak status
kubectl get pods -n keycloak-ns
kubectl get svc -n keycloak-ns

# Test Keycloak connectivity
curl -k http://localhost:8090/auth/realms/minikube-realm/.well-known/openid_configuration
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built for learning and development purposes
- Inspired by modern DevOps practices
- Configured for easy deployment and management

---

**Note**: This stack is designed for development and learning purposes. For production use, consider additional security hardening, monitoring, and backup strategies.
