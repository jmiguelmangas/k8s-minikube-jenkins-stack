# 🚀 Jenkins CI/CD Setup Completo

## 📋 Resumen de la Configuración

### ✅ Componentes Instalados

1. **Jenkins Master**
   - Versión: 2.504.3 LTS
   - Namespace: `jenkins-ns`
   - Almacenamiento persistente: 10GB
   - Acceso: http://localhost:8081

2. **Plugins Instalados Automáticamente**
   - `workflow-aggregator` (Pipeline)
   - `kubernetes` (Kubernetes Cloud)
   - `git` (Git integration)
   - `github` (GitHub integration)
   - `blueocean` (Pipeline visual)
   - `docker-workflow` (Docker support)
   - `kubernetes-cli` (kubectl)
   - `configuration-as-code` (JCasC)
   - Y muchos más...

3. **Configuración de Seguridad**
   - Usuario: `admin`
   - Contraseña: `admin123`
   - Configurado via Jenkins Configuration as Code

### 🎯 Funcionalidades Configuradas

#### 🔧 Kubernetes Cloud
- **Configurado automáticamente** para usar el cluster local
- **Namespace**: `jenkins-ns`
- **Capacidad**: Hasta 100 containers simultáneos
- **Conexión**: Automática al API server de Kubernetes

#### 🛠️ Pipeline Capabilities
- **Kubernetes Agents**: Pods dinámicos como agents
- **Multi-container**: Maven, Docker, kubectl en el mismo pod
- **Shared Libraries**: Configuradas para reutilización de código

### 📁 Archivos de Configuración Creados

1. **`jenkins-pvc.yaml`** - Almacenamiento persistente
2. **`jenkins-rbac.yaml`** - Permisos y ServiceAccount
3. **`jenkins-deployment-updated.yaml`** - Deployment con plugins y JCasC
4. **`jenkins-service.yaml`** - Servicio NodePort
5. **`jenkins-plugins-configmap.yaml`** - Lista de plugins
6. **`jenkins-casc-configmap.yaml`** - Configuración automática
7. **`create-job-improved.sh`** - Script para crear pipelines

### 🌐 Acceso a Jenkins

#### Desde tu Mac:
```bash
# Port-forward ya activo
kubectl port-forward service/jenkins-service 8081:8080 -n jenkins-ns &

# Acceder en navegador
open http://localhost:8081
```

#### Credenciales:
- **Usuario**: `admin`
- **Contraseña**: `admin123`

### 🔄 Pipeline de Ejemplo Listo para Usar

```groovy
pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.1-openjdk-11
    command: [cat]
    tty: true
    volumeMounts:
    - mountPath: /root/.m2
      name: maven-cache
  - name: kubectl
    image: bitnami/kubectl:latest
    command: [cat]
    tty: true
  volumes:
  - name: maven-cache
    emptyDir: {}
"""
        }
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '🔍 Clonando código fuente...'
                // Tu código de Git aquí
            }
        }
        
        stage('Build') {
            steps {
                container('maven') {
                    echo '🔨 Compilando aplicación...'
                    sh 'mvn clean compile'
                }
            }
        }
        
        stage('Test') {
            steps {
                container('maven') {
                    echo '🧪 Ejecutando tests...'
                    sh 'mvn test'
                }
            }
        }
        
        stage('Package') {
            steps {
                container('maven') {
                    echo '📦 Empaquetando aplicación...'
                    sh 'mvn package'
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo '🚀 Desplegando en Kubernetes...'
                    sh '''
                        kubectl apply -f k8s-manifests/
                        kubectl set image deployment/mi-app mi-app=mi-app:${BUILD_NUMBER}
                        kubectl rollout status deployment/mi-app
                    '''
                }
            }
        }
    }
    
    post {
        success {
            echo '🎉 Pipeline ejecutado exitosamente!'
        }
        failure {
            echo '❌ Pipeline falló. Revisar logs.'
        }
    }
}
```

### 📝 Próximos Pasos para Usar Jenkins

1. **Acceder a Jenkins**: http://localhost:8081
2. **Crear New Item** → **Pipeline**
3. **Pegar el código del pipeline** de arriba
4. **Configurar Git repository** si tienes uno
5. **Ejecutar Build Now**

### 🔧 Comandos Útiles

```bash
# Ver estado de Jenkins
kubectl get all -n jenkins-ns

# Ver logs de Jenkins
kubectl logs -f deployment/jenkins-deployment -n jenkins-ns

# Acceder al pod de Jenkins
kubectl exec -it deployment/jenkins-deployment -n jenkins-ns -- bash

# Reiniciar Port-forward si se cae
pkill -f "kubectl port-forward"
kubectl port-forward service/jenkins-service 8081:8080 -n jenkins-ns &

# Ver jobs ejecutándose
kubectl get pods -n jenkins-ns
```

### 🎯 Características Avanzadas Disponibles

- ✅ **Blue Ocean UI** para pipelines visuales
- ✅ **Kubernetes Cloud** para agents dinámicos
- ✅ **Git/GitHub integration** 
- ✅ **Docker workflow** para construir imágenes
- ✅ **Shared Libraries** para código reutilizable
- ✅ **Credential Management** para secretos
- ✅ **Multi-branch pipelines**
- ✅ **Webhook triggers** para CI/CD automático

## 🎉 ¡Tu entorno de CI/CD está listo!

Jenkins está completamente configurado y listo para manejar tus pipelines de CI/CD con Kubernetes. Solo necesitas:

1. Acceder a la interfaz web
2. Crear tus pipelines
3. Configurar tus repositorios Git
4. ¡Empezar a deployar!
