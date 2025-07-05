#!/bin/bash

# Configuración de Jenkins
JENKINS_URL="http://localhost:8081"
USERNAME="admin"
PASSWORD="admin123"

# Obtener crumb para CSRF protection
CRUMB=$(curl -s "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" --user "${USERNAME}:${PASSWORD}")
echo "Crumb obtenido: $CRUMB"

# Crear el job de ejemplo
curl -X POST "${JENKINS_URL}/createItem?name=sample-pipeline" \
  --user "${USERNAME}:${PASSWORD}" \
  --header "Content-Type: application/xml" \
  --header "${CRUMB}" \
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
                echo 'Clonando código fuente...'
                script {
                    sh 'echo "Código clonado exitosamente"'
                }
            }
        }
        
        stage('Build') {
            steps {
                container('maven') {
                    echo 'Compilando aplicación...'
                    sh '''
                        echo "Simulando build con Maven"
                        echo "mvn clean compile"
                        echo "Build completado exitosamente"
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                container('maven') {
                    echo 'Ejecutando tests...'
                    sh '''
                        echo "Ejecutando tests unitarios"
                        echo "mvn test"
                        echo "Tests completados exitosamente"
                    '''
                }
            }
        }
        
        stage('Package') {
            steps {
                container('maven') {
                    echo 'Empaquetando aplicación...'
                    sh '''
                        echo "Creando JAR/WAR"
                        echo "mvn package"
                        echo "Aplicación empaquetada"
                    '''
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo 'Desplegando en Kubernetes...'
                    sh '''
                        echo "kubectl apply -f k8s-manifests/"
                        echo "kubectl set image deployment/mi-app mi-app=mi-app:${BUILD_NUMBER}"
                        echo "kubectl rollout status deployment/mi-app"
                        echo "Aplicación desplegada exitosamente en Kubernetes"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completado'
        }
        success {
            echo 'Pipeline ejecutado exitosamente!'
        }
        failure {
            echo 'Pipeline falló. Revisar logs.'
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

echo "Job 'sample-pipeline' creado exitosamente"
