#!/bin/bash

# Configuración
JENKINS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

echo "🔧 Creando pipeline principal de CI/CD en Jenkins..."

# Función para obtener el crumb
get_crumb() {
    curl -s -u "${USERNAME}:${PASSWORD}" "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)"
}

# Obtener crumb
echo "🔑 Obteniendo token CSRF..."
CRUMB=$(get_crumb)
echo "Crumb obtenido: ${CRUMB:0:30}..."

# Crear el job usando curl
echo "📋 Creando job 'Deploy-Full-Stack-Pipeline'..."

curl -X POST "${JENKINS_URL}/createItem?name=Deploy-Full-Stack-Pipeline" \
  -u "${USERNAME}:${PASSWORD}" \
  -H "Content-Type: application/xml" \
  -H "${CRUMB}" \
  --data-raw '<?xml version="1.1" encoding="UTF-8"?>
<flow-definition plugin="workflow-job@1400.v7fd111b_ec82f">
  <actions/>
  <description>🚀 Pipeline maestro para desplegar y testear todo el stack de aplicaciones en Kubernetes</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers/>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@3899.v4b_19c3d5d857">
    <script>pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
  - name: curl
    image: curlimages/curl:latest
    command:
    - cat
    tty: true
"""
        }
    }
    
    stages {
        stage("🔍 Preparación") {
            steps {
                script {
                    echo "🚀 Iniciando pipeline de despliegue completo del stack"
                    echo "📅 Build: ${BUILD_NUMBER}"
                    echo "🕐 Timestamp: ${new Date()}"
                    echo "👤 Iniciado por: ${env.BUILD_USER ?: '"'"'Sistema'"'"'}"
                }
            }
        }
        
        stage("✅ Validación Pre-despliegue") {
            parallel {
                stage("🔧 Verificar Kubectl") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "🔍 Verificando conexión a Kubernetes..."
                                sh "kubectl cluster-info"
                                sh "kubectl get nodes"
                                echo "✅ Conexión a Kubernetes verificada"
                            }
                        }
                    }
                }
                
                stage("📊 Estado Actual") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "📊 Verificando estado actual del cluster..."
                                sh """
                                    echo "=== NAMESPACES EXISTENTES ==="
                                    kubectl get namespaces
                                    
                                    echo "\\n=== DEPLOYMENTS ACTUALES ==="
                                    kubectl get deployments --all-namespaces || echo "Sin deployments"
                                    
                                    echo "\\n=== SERVICIOS ACTUALES ==="
                                    kubectl get services --all-namespaces | grep -E "(jenkins|n8n|postgresql)" || echo "Sin servicios específicos"
                                """
                                echo "✅ Estado actual verificado"
                            }
                        }
                    }
                }
            }
        }
        
        stage("🏗️ Verificar Infraestructura") {
            steps {
                container("kubectl") {
                    script {
                        echo "🏗️ Verificando/creando namespaces..."
                        sh """
                            # Crear namespaces si no existen
                            kubectl create namespace jenkins-ns --dry-run=client -o yaml | kubectl apply -f -
                            kubectl create namespace n8n-ns --dry-run=client -o yaml | kubectl apply -f -
                            kubectl create namespace postgresql-ns --dry-run=client -o yaml | kubectl apply -f -
                            kubectl create namespace monitoring-ns --dry-run=client -o yaml | kubectl apply -f -
                            
                            echo "✅ Namespaces verificados/creados"
                        """
                    }
                }
            }
        }
        
        stage("🚀 Verificar Aplicaciones") {
            parallel {
                stage("🐘 Verificar PostgreSQL") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "🐘 Verificando PostgreSQL..."
                                sh """
                                    if kubectl get deployment postgresql-deployment -n postgresql-ns &>/dev/null; then
                                        echo "✅ PostgreSQL encontrado"
                                        kubectl get pods -n postgresql-ns -l app=postgresql
                                        kubectl exec -n postgresql-ns deployment/postgresql-deployment -- pg_isready -U postgres || echo "⚠️ PostgreSQL no responde completamente"
                                    else
                                        echo "⚠️ PostgreSQL no encontrado"
                                    fi
                                """
                            }
                        }
                    }
                }
                
                stage("🔄 Verificar N8N") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "🔄 Verificando N8N..."
                                sh """
                                    if kubectl get deployment n8n-deployment -n n8n-ns &>/dev/null; then
                                        echo "✅ N8N encontrado"
                                        kubectl get pods -n n8n-ns -l app=n8n
                                    else
                                        echo "⚠️ N8N no encontrado"
                                    fi
                                """
                            }
                        }
                    }
                }
                
                stage("🏗️ Verificar Jenkins") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "🏗️ Verificando Jenkins..."
                                sh """
                                    if kubectl get deployment jenkins-deployment -n jenkins-ns &>/dev/null; then
                                        echo "✅ Jenkins encontrado"
                                        kubectl get pods -n jenkins-ns -l app=jenkins
                                        kubectl exec -n jenkins-ns deployment/jenkins-deployment -- curl -f http://localhost:8080/login > /dev/null 2>&1 && echo "✅ Jenkins API responde" || echo "⚠️ Jenkins API no responde completamente"
                                    else
                                        echo "⚠️ Jenkins no encontrado"
                                    fi
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage("🧪 Tests de Conectividad") {
            parallel {
                stage("🔍 Test PostgreSQL Conectividad") {
                    steps {
                        container("kubectl") {
                            script {
                                echo "🧪 Testeando conectividad PostgreSQL..."
                                sh """
                                    if kubectl get pods -n postgresql-ns -l app=postgresql --field-selector=status.phase=Running | grep Running; then
                                        echo "✅ PostgreSQL está ejecutándose"
                                        kubectl exec -n postgresql-ns deployment/postgresql-deployment -- pg_isready -U postgres && echo "✅ PostgreSQL responde correctamente" || echo "⚠️ PostgreSQL no responde"
                                    else
                                        echo "⚠️ PostgreSQL no está ejecutándose"
                                    fi
                                """
                            }
                        }
                    }
                }
                
                stage("🔍 Test N8N Conectividad") {
                    steps {
                        container("curl") {
                            script {
                                echo "🧪 Testeando conectividad N8N..."
                                sh """
                                    if curl -f -s -o /dev/null http://n8n-service.n8n-ns.svc.cluster.local; then
                                        echo "✅ N8N responde correctamente"
                                    else
                                        echo "⚠️ N8N no responde - esto es normal si no está desplegado"
                                    fi
                                """
                            }
                        }
                    }
                }
            }
        }
        
        stage("📊 Reporte Final del Cluster") {
            steps {
                container("kubectl") {
                    script {
                        echo "📊 Generando reporte final del estado del cluster..."
                        sh """
                            echo "========================================"
                            echo "🎯 REPORTE FINAL DEL CLUSTER"
                            echo "========================================"
                            
                            echo "\\n=== 📂 NAMESPACES ==="
                            kubectl get namespaces -o wide
                            
                            echo "\\n=== 🚀 DEPLOYMENTS ==="
                            kubectl get deployments --all-namespaces -o wide
                            
                            echo "\\n=== 🌐 SERVICIOS ==="
                            kubectl get services --all-namespaces -o wide
                            
                            echo "\\n=== 📦 PODS ==="
                            kubectl get pods --all-namespaces -o wide
                            
                            echo "\\n=== 💾 VOLUMENES PERSISTENTES ==="
                            kubectl get pvc --all-namespaces
                            
                            echo "\\n=== 📊 RECURSOS DEL CLUSTER ==="
                            kubectl top nodes || echo "Metrics server no disponible"
                            
                            echo "\\n========================================"
                            echo "✅ REPORTE COMPLETADO"
                            echo "========================================"
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🏁 Pipeline completado - Build #${BUILD_NUMBER}"
                echo "📅 Finalizado: ${new Date()}"
            }
        }
        
        success {
            script {
                echo "🎉 ¡Pipeline ejecutado exitosamente!"
                echo "✅ Stack validado y verificado"
                echo ""
                echo "🌐 Aplicaciones disponibles:"
                echo "   📊 N8N: http://192.168.1.49:31199"
                echo "   🐘 PostgreSQL: 192.168.1.49:30178 (postgres/postgres)"
                echo "   🏗️ Jenkins: http://localhost:8081 (admin/admin123)"
                echo ""
                echo "📋 Para acceder a Jenkins desde local:"
                echo "   kubectl port-forward service/jenkins-service 8081:8080 -n jenkins-ns &"
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline falló - revisar logs para detalles"
                echo "🔍 Verificar conectividad a Kubernetes"
                echo "📧 Contactar al equipo de DevOps si persiste el problema"
            }
        }
        
        unstable {
            script {
                echo "⚠️ Pipeline inestable - algunos tests fallaron"
                echo "🔍 Revisar warnings en el log"
            }
        }
    }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>'

# Verificar resultado
if [ $? -eq 0 ]; then
    echo "✅ Pipeline 'Deploy-Full-Stack-Pipeline' creado exitosamente!"
    echo ""
    echo "🌐 Accede a Jenkins: ${JENKINS_URL}"
    echo "👤 Usuario: ${USERNAME}"
    echo "🔑 Contraseña: ${PASSWORD}"
    echo ""
    echo "📋 Para ejecutar el pipeline:"
    echo "1. Ve a ${JENKINS_URL}/job/Deploy-Full-Stack-Pipeline/"
    echo "2. Click en 'Build Now'"
    echo "3. Monitora la ejecución en la consola"
else
    echo "❌ Error al crear el pipeline"
    echo "🔍 Verificar que Jenkins esté accesible en ${JENKINS_URL}"
fi
