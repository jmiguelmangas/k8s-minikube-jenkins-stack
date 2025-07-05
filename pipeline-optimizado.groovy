pipeline {
    agent any
    
    stages {
        stage('🔍 Preparación') {
            steps {
                script {
                    echo "🚀 Iniciando pipeline de verificación del stack"
                    echo "📅 Build: ${BUILD_NUMBER}"
                    echo "🕐 Timestamp: ${new Date()}"
                    echo "👤 Iniciado por: ${env.BUILD_USER ?: 'Sistema'}"
                }
            }
        }
        
        stage('✅ Verificar Herramientas') {
            steps {
                script {
                    echo "🔧 Verificando herramientas disponibles..."
                    
                    // Verificar kubectl
                    try {
                        sh 'kubectl version --client=true'
                        echo "✅ kubectl está disponible"
                    } catch (Exception e) {
                        echo "❌ kubectl no disponible: ${e.message}"
                        echo "📋 Información del sistema:"
                        sh 'which kubectl || echo "kubectl no encontrado en PATH"'
                        sh 'ls -la /usr/local/bin/ || echo "No se puede listar /usr/local/bin"'
                        sh 'echo "PATH: $PATH"'
                        currentBuild.result = 'UNSTABLE'
                    }
                    
                    // Verificar curl
                    try {
                        sh 'curl --version'
                        echo "✅ curl está disponible"
                    } catch (Exception e) {
                        echo "❌ curl no disponible: ${e.message}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
        
        stage('🔧 Conectividad Kubernetes') {
            steps {
                script {
                    echo "🔍 Verificando conexión a Kubernetes..."
                    
                    try {
                        sh 'kubectl get nodes'
                        echo "✅ Conexión a Kubernetes exitosa"
                    } catch (Exception e) {
                        echo "❌ Error conectando a Kubernetes: ${e.message}"
                        
                        // Información de debug
                        echo "🔍 Información de debug:"
                        sh 'env | grep -i kube || echo "No hay variables KUBE"'
                        sh 'ls -la ~/.kube/ || echo "No hay directorio .kube"'
                        sh 'cat /var/run/secrets/kubernetes.io/serviceaccount/token | head -c 50 || echo "No hay token"'
                        sh 'whoami && id'
                        
                        currentBuild.result = 'FAILURE'
                        error("No se puede conectar a Kubernetes")
                    }
                }
            }
        }
        
        stage('📊 Estado del Cluster') {
            steps {
                script {
                    echo "📊 Generando reporte del estado del cluster..."
                    
                    try {
                        echo "=== 📂 NAMESPACES ==="
                        sh 'kubectl get namespaces'
                        
                        echo "\\n=== 🚀 DEPLOYMENTS ==="
                        sh 'kubectl get deployments --all-namespaces'
                        
                        echo "\\n=== 🌐 SERVICIOS ==="
                        sh 'kubectl get services --all-namespaces'
                        
                        echo "\\n=== 📦 PODS ==="
                        sh 'kubectl get pods --all-namespaces'
                        
                        echo "\\n=== 💾 VOLUMENES PERSISTENTES ==="
                        sh 'kubectl get pvc --all-namespaces'
                        
                        echo "\\n=== 🔍 EVENTOS RECIENTES ==="
                        sh 'kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -20'
                        
                        echo "✅ Reporte generado exitosamente"
                        
                    } catch (Exception e) {
                        echo "❌ Error generando reporte: ${e.message}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
        
        stage('🧪 Test Aplicaciones') {
            parallel {
                stage('🐘 Test PostgreSQL') {
                    steps {
                        script {
                            echo "🧪 Testeando PostgreSQL..."
                            try {
                                sh '''
                                    if kubectl get deployment postgresql-deployment -n postgresql-ns &>/dev/null; then
                                        echo "✅ PostgreSQL deployment encontrado"
                                        kubectl get pods -n postgresql-ns -l app=postgresql
                                        
                                        # Verificar si hay pods running
                                        RUNNING_PODS=$(kubectl get pods -n postgresql-ns -l app=postgresql --field-selector=status.phase=Running --no-headers | wc -l)
                                        if [ "$RUNNING_PODS" -gt 0 ]; then
                                            echo "✅ PostgreSQL tiene $RUNNING_PODS pod(s) corriendo"
                                            kubectl exec -n postgresql-ns deployment/postgresql-deployment -- pg_isready -U postgres && echo "✅ PostgreSQL responde correctamente" || echo "⚠️ PostgreSQL no responde"
                                        else
                                            echo "⚠️ No hay pods de PostgreSQL en estado Running"
                                        fi
                                    else
                                        echo "⚠️ PostgreSQL deployment no encontrado"
                                    fi
                                '''
                            } catch (Exception e) {
                                echo "❌ Error verificando PostgreSQL: ${e.message}"
                            }
                        }
                    }
                }
                
                stage('🔄 Test N8N') {
                    steps {
                        script {
                            echo "🧪 Testeando N8N..."
                            try {
                                sh '''
                                    if kubectl get deployment n8n-deployment -n n8n-ns &>/dev/null; then
                                        echo "✅ N8N deployment encontrado"
                                        kubectl get pods -n n8n-ns -l app=n8n
                                        
                                        # Verificar si hay pods running
                                        RUNNING_PODS=$(kubectl get pods -n n8n-ns -l app=n8n --field-selector=status.phase=Running --no-headers | wc -l)
                                        if [ "$RUNNING_PODS" -gt 0 ]; then
                                            echo "✅ N8N tiene $RUNNING_PODS pod(s) corriendo"
                                            # Verificar puerto
                                            kubectl get svc -n n8n-ns
                                        else
                                            echo "⚠️ No hay pods de N8N en estado Running"
                                        fi
                                    else
                                        echo "⚠️ N8N deployment no encontrado"
                                    fi
                                '''
                            } catch (Exception e) {
                                echo "❌ Error verificando N8N: ${e.message}"
                            }
                        }
                    }
                }
                
                stage('🏗️ Test Jenkins') {
                    steps {
                        script {
                            echo "🧪 Testeando Jenkins..."
                            try {
                                sh '''
                                    if kubectl get deployment jenkins-deployment -n jenkins-ns &>/dev/null; then
                                        echo "✅ Jenkins deployment encontrado"
                                        kubectl get pods -n jenkins-ns -l app=jenkins
                                        
                                        # Verificar si hay pods running
                                        RUNNING_PODS=$(kubectl get pods -n jenkins-ns -l app=jenkins --field-selector=status.phase=Running --no-headers | wc -l)
                                        if [ "$RUNNING_PODS" -gt 0 ]; then
                                            echo "✅ Jenkins tiene $RUNNING_PODS pod(s) corriendo"
                                            kubectl get svc -n jenkins-ns
                                        else
                                            echo "⚠️ No hay pods de Jenkins en estado Running"
                                        fi
                                    else
                                        echo "⚠️ Jenkins deployment no encontrado"
                                    fi
                                '''
                            } catch (Exception e) {
                                echo "❌ Error verificando Jenkins: ${e.message}"
                            }
                        }
                    }
                }
            }
        }
        
        stage('🩺 Diagnóstico de Problemas') {
            steps {
                script {
                    echo "🔍 Buscando problemas comunes..."
                    
                    try {
                        sh '''
                            echo "=== 🚨 PODS CON PROBLEMAS ==="
                            kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | grep -v Completed || echo "No hay pods con problemas"
                            
                            echo "\\n=== 📋 LOGS DE PODS CON ERRORES ==="
                            for pod in $(kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | grep -v Completed | awk '{print $2":"$1}'); do
                                if [ ! -z "$pod" ]; then
                                    POD_NAME=$(echo $pod | cut -d: -f1)
                                    NAMESPACE=$(echo $pod | cut -d: -f2)
                                    echo "\\n--- Logs de $POD_NAME en $NAMESPACE ---"
                                    kubectl logs -n $NAMESPACE $POD_NAME --tail=10 || echo "No se pudieron obtener logs"
                                fi
                            done
                        '''
                    } catch (Exception e) {
                        echo "❌ Error en diagnóstico: ${e.message}"
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
                
                // Resumen final
                sh '''
                    echo "\\n=== 📊 RESUMEN FINAL ==="
                    echo "Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
                    echo "Deployments: $(kubectl get deployments --all-namespaces --no-headers | wc -l)"
                    echo "Pods corriendo: $(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)"
                    echo "Pods con problemas: $(kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | grep -v Completed | wc -l)"
                '''
            }
        }
        
        success {
            script {
                echo "🎉 ¡Pipeline ejecutado exitosamente!"
                echo "✅ Stack verificado correctamente"
                echo ""
                echo "🌐 Aplicaciones disponibles:"
                echo "   📊 N8N: http://192.168.1.49:31199"
                echo "   🐘 PostgreSQL: 192.168.1.49:30178 (postgres/postgres)"
                echo "   🏗️ Jenkins: http://localhost:8081 (admin/admin123)"
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline falló - revisar logs para detalles"
                echo "🔍 Verificar que kubectl esté disponible en Jenkins"
                echo "🔍 Verificar conectividad a Kubernetes"
                echo "🔍 Verificar permisos RBAC del ServiceAccount jenkins"
            }
        }
        
        unstable {
            script {
                echo "⚠️ Pipeline completado con advertencias"
                echo "🔍 Revisar los logs para identificar problemas menores"
            }
        }
    }
}
