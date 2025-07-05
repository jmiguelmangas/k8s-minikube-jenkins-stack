#!/bin/bash

echo "Updating Jenkins deployment with Docker-enabled image..."

# Option 1: Update the image directly (quick fix)
echo "Option 1: Patching deployment with new image..."
kubectl patch deployment jenkins -n jenkins -p '{"spec":{"template":{"spec":{"containers":[{"name":"jenkins","image":"339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python-docker"}]}}}}'

echo "Deployment updated! Jenkins will restart with Docker client included."
echo "Monitor the rollout with: kubectl rollout status deployment/jenkins -n jenkins"

# Uncomment below to apply the full deployment file instead
# echo "Option 2: Applying full deployment file..."
# kubectl apply -f jenkins-deployment-with-docker.yaml

echo "Waiting for deployment to complete..."
kubectl rollout status deployment/jenkins -n jenkins

