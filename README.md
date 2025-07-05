# Kubernetes Minikube Jenkins Stack

A complete CI/CD platform built on Minikube with Jenkins, including automated deployment scripts and monitoring capabilities.

## 🚀 Overview

This project provides a comprehensive Kubernetes-based development environment featuring:

- **Jenkins CI/CD** with automatic plugin installation and configuration
- **Kubernetes manifests** for multiple applications (N8N, PostgreSQL, Jenkins)
- **Automated deployment scripts** for easy stack management
- **Remote access configuration** for minikube clusters
- **Persistent storage** and proper RBAC configuration

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
├── monitoring/            # Monitoring stack (placeholder)
├── ci-cd/                # CI/CD pipeline definitions
│   ├── scripts/          # Deployment scripts
│   └── pipelines/        # Jenkins pipeline definitions
└── docs/                 # Documentation
```

## 🚀 Quick Start

### 1. Deploy the Complete Stack

```bash
# Make the deployment script executable
chmod +x ci-cd/scripts/deploy-all.sh

# Deploy all components
./ci-cd/scripts/deploy-all.sh
```

### 2. Access Jenkins

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

## 📋 Available Scripts

| Script | Description |
|--------|-------------|
| `deploy-all.sh` | Deploy complete stack |
| `cleanup.sh` | Clean up all resources |
| `create-main-pipeline.sh` | Create Jenkins pipeline via API |

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

## 🔧 Troubleshooting

### Common Issues

1. **Jenkins pod not starting**: Check resource limits and node capacity
2. **SSH connection refused**: Verify SSH keys and server configuration
3. **kubectl permission denied**: Check RBAC configuration
4. **Pipeline hanging**: Ensure all tools are installed in Jenkins container

### Debugging Commands

```bash
# Check pod logs
kubectl logs -n jenkins-ns deployment/jenkins-deployment

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Verify connectivity
kubectl exec -it -n jenkins-ns deployment/jenkins-deployment -- kubectl get nodes
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
