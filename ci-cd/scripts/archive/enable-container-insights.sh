#!/bin/bash

echo "🚀 === ENABLE EKS CONTAINER INSIGHTS ==="
echo ""
echo "Container Insights provides detailed monitoring for:"
echo "  📊 Pod CPU/Memory usage"
echo "  🔍 Container-level metrics" 
echo "  📈 Application performance insights"
echo "  🚨 Detailed alerting capabilities"
echo ""
echo "⚠️  Cost: ~$1-3/month for Container Insights"
echo ""

read -p "Do you want to enable Container Insights for EKS cluster? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔧 Enabling Container Insights for EKS cluster..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo "⚠️  kubectl not found. Installing kubectl..."
        curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.32.0/2024-08-15/bin/darwin/amd64/kubectl
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    # Update kubeconfig
    echo "📝 Updating kubeconfig for EKS cluster..."
    aws eks update-kubeconfig --region eu-west-1 --name eks-incibe-uat-neoris-hcr --profile uat
    
    # Download and apply CloudWatch configuration
    echo "📊 Deploying CloudWatch Container Insights..."
    curl -s https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/eks-incibe-uat-neoris-hcr/;s/{{region_name}}/eu-west-1/" | kubectl apply -f -
    
    echo ""
    echo "✅ Container Insights deployment initiated!"
    echo ""
    echo "📈 It will take 5-10 minutes for metrics to start appearing"
    echo "🔍 Check deployment status: kubectl get pods -n amazon-cloudwatch"
    echo ""
    echo "📊 New metrics will include:"
    echo "  - Pod CPU/Memory utilization"
    echo "  - Container restart counts"
    echo "  - Node resource usage"
    echo "  - Application performance data"
    
else
    echo ""
    echo "✅ Keeping current EKS monitoring (basic metrics only)"
    echo "🔒 Current dashboard still provides cluster health monitoring"
fi

echo ""
echo "📊 Current EKS Dashboard:"
echo "https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=EKS-Monitoring-UAT"
echo ""
echo "🚨 EKS Alarms Created:"
echo "  - EKS-High-CPU-Usage-UAT: Worker node CPU >80%"
echo "  - EKS-Failed-Nodes-UAT: Any failed nodes"
echo "  - EKS-Low-Node-Count-UAT: Insufficient nodes"

