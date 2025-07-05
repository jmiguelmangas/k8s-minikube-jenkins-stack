#!/bin/bash

echo "Configuring Jenkins URL to fix reverse proxy warning..."

# Method 1: Using Jenkins CLI (if available)
echo "Attempting to configure Jenkins URL via configuration file..."

# Create the Jenkins Location Configuration XML
cat > /tmp/jenkins-location-config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<jenkins.model.JenkinsLocationConfiguration>
  <adminAddress>admin@incibe-dataproduct.sbs</adminAddress>
  <jenkinsUrl>https://jenkins.incibe-dataproduct.sbs/</jenkinsUrl>
</jenkins.model.JenkinsLocationConfiguration>
EOF

# Copy the configuration to Jenkins pod
kubectl cp /tmp/jenkins-location-config.xml jenkins/jenkins-6cdf57f9f9-np29d:/var/jenkins_home/jenkins.model.JenkinsLocationConfiguration.xml -c jenkins

echo "Configuration file copied. Restarting Jenkins container..."

# Restart Jenkins to apply the configuration
kubectl rollout restart deployment/jenkins -n jenkins

echo "Waiting for deployment to complete..."
kubectl rollout status deployment/jenkins -n jenkins

echo "Jenkins URL configuration completed!"
echo "Please check the Jenkins admin panel - the reverse proxy warning should be gone."
echo "If the warning persists, you may need to manually set the Jenkins URL in:"
echo "Manage Jenkins > Configure System > Jenkins Location > Jenkins URL"
echo "Set it to: https://jenkins.incibe-dataproduct.sbs/"

# Clean up temp file
rm -f /tmp/jenkins-location-config.xml

