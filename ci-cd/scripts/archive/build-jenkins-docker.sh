#!/bin/bash

# Login to ECR using UAT profile
echo "Logging in to ECR using UAT profile..."
aws ecr get-login-password --region eu-west-1 --profile uat | docker login --username AWS --password-stdin 339713187628.dkr.ecr.eu-west-1.amazonaws.com

# Pull the base image first
echo "Pulling base image..."
docker pull 339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python

# Build the new Jenkins image with Docker, kubectl, and requests
echo "Building Jenkins image with Docker, kubectl, and Python requests..."
docker build -f jenkins-docker-dockerfile -t 339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python-docker-tools .

# Push to ECR
echo "Pushing image to ECR..."
docker push 339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python-docker-tools

echo "Image built and pushed successfully!"
echo "New image: 339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python-docker-tools"
echo ""
echo "Installed tools:"
echo "- Docker client"
echo "- kubectl (Kubernetes CLI)"
echo "- Python requests library"
echo ""
echo "To update Jenkins deployment, run:"
echo "kubectl patch deployment jenkins -n jenkins -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"jenkins\",\"image\":\"339713187628.dkr.ecr.eu-west-1.amazonaws.com/infra-user-uat-jenkins:jenkins-python-docker-tools\"}]}}}}'"

