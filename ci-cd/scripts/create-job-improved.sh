#!/bin/bash

# Configuración de Jenkins
JENKINS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"
COOKIE_JAR="/tmp/jenkins_cookies.txt"

echo "🔐 Autenticando con Jenkins..."

# Crear sesión y obtener cookies
curl -c "$COOKIE_JAR" -b "$COOKIE_JAR" -s \
  "${JENKINS_URL}/login" \
  --user "${USERNAME}:${PASSWORD}" > /dev/null

# Obtener crumb
CRUMB=$(curl -s -b "$COOKIE_JAR" \
  "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\\\":\\\",//crumb)" \
  --user "${USERNAME}:${PASSWORD}")

echo "🔑 Crumb obtenido: $CRUMB"

# Verificar si el job ya existe
JOB_EXISTS=$(curl -s -b "$COOKIE_JAR" -o /dev/null -w "%{http_code}" \
  "${JENKINS_URL}/job/sample-pipeline/" --user "${USERNAME}:${PASSWORD}")

if [ "$JOB_EXISTS" = "200" ]; then
  echo "⚠️  El job 'sample-pipeline' ya existe. Eliminándolo..."
  curl -X POST -b "$COOKIE_JAR" \
    "${JENKINS_URL}/job/sample-pipeline/doDelete" \
    --user "${USERNAME}:${PASSWORD}" \
    --header "${CRUMB}" -s > /dev/null
  echo "🗑️  Job anterior eliminado"
fi

echo "📋 Creando job 'sample-pipeline'..."

# Crear el job
RESPONSE=$(curl -X POST "${JENKINS_URL}/createItem?name=sample-pipeline" \
  -b "$COOKIE_JAR" \
  --user "${USERNAME}:${PASSWORD}" \
  --header "Content-Type: application/xml" \
  --header "${CRUMB}" \
  -w "%{http_code}" \
  --data @- << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Pipeline de ejemplo para CI/CD con Kubernetes</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers/>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
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
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /root/.m2
      name: maven-cache
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
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
                script {
                    sh 'echo "✅ Código clonado exitosamente"'
                }
            }
        }
        
        stage('Build') {
            steps {
                container('maven') {
                    echo '🔨 Compilando aplicación...'
                    sh '''
                        echo "📦 Simulando build con Maven"
                        echo "mvn clean compile"
                        echo "✅ Build completado exitosamente"
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                container('maven') {
                    echo '🧪 Ejecutando tests...'
                    sh '''
                        echo "🔬 Ejecutando tests unitarios"
                        echo "mvn test"
                        echo "✅ Tests completados exitosamente"
                    '''
                }
            }
        }
        
        stage('Package') {
            steps {
                container('maven') {
                    echo '📦 Empaquetando aplicación...'
                    sh '''
                        echo "📦 Creando JAR/WAR"
                        echo "mvn package"
                        echo "✅ Aplicación empaquetada"
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo '🚀 Desplegando en Kubernetes...'
                    sh '''
                        echo "kubectl apply -f k8s-manifests/"
                        echo "kubectl set image deployment/mi-app mi-app=mi-app:${BUILD_NUMBER}"
                        echo "kubectl rollout status deployment/mi-app"
                        echo "✅ Aplicación desplegada exitosamente en Kubernetes"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo '🏁 Pipeline completado'
        }
        success {
            echo '🎉 Pipeline ejecutado exitosamente!'
        }
        failure {
            echo '❌ Pipeline falló. Revisar logs.'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
)

if [[ "$RESPONSE" == *"200"* ]]; then
  echo "✅ Job 'sample-pipeline' creado exitosamente"
  echo "🌐 Acceder a: ${JENKINS_URL}/job/sample-pipeline/"
else
  echo "❌ Error al crear el job. Código de respuesta: $RESPONSE"
fi

# Limpiar cookies
rm -f "$COOKIE_JAR"

echo "🚀 Jenkins está listo para CI/CD!"
echo "👤 Usuario: $USERNAME"
echo "🔑 Contraseña: $PASSWORD"
echo "🌐 URL: $JENKINS_URL"
