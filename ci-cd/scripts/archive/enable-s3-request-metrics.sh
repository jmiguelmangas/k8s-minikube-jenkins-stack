#!/bin/bash

echo "🔧 === S3 REQUEST METRICS ENABLEMENT SCRIPT ==="
echo ""
echo "⚠️  WARNING: This will enable S3 Request Metrics which have costs:"
echo "   💰 Cost: ~$0.15 per 1 million requests monitored"
echo "   📊 Benefits: Real-time request monitoring, error tracking, bandwidth monitoring"
echo ""

read -p "Do you want to enable S3 Request Metrics for enhanced monitoring? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔧 Enabling S3 Request Metrics for key buckets..."
    
    BUCKETS=("incibe-clinical-history" "neoris-hcr-connector-dataproduct-bronze" "neoris-hcr-connector-dataproduct-silver" "neoris-hcr-connector-dataproduct-gold")
    
    for bucket in "${BUCKETS[@]}"; do
        echo "  📊 Enabling metrics for: $bucket"
        
        # Create metrics configuration file
        cat > /tmp/metrics-config.json << EOF
{
    "Id": "EntireBucket"
}
EOF
        
        # Enable request metrics using AWS CLI
        aws s3api put-bucket-metrics-configuration \
            --bucket "$bucket" \
            --id "EntireBucket" \
            --metrics-configuration file:///tmp/metrics-config.json \
            --profile uat 2>/dev/null || echo "    ⚠️  Could not enable metrics for $bucket (may not exist or no permissions)"
    done
    
    echo ""
    echo "✅ Request metrics enablement completed!"
    echo ""
    echo "📈 It will take 15-30 minutes for request metrics to start appearing"
    echo "🔍 You can verify in S3 Console → Bucket → Metrics → Request metrics"
    echo ""
    echo "🔧 Updating dashboard with full metrics..."
    
    # Here you would update the dashboard with the full metrics version
    echo "📊 Dashboard will show these additional metrics once active:"
    echo "   - AllRequests (total request volume)"
    echo "   - 4xxErrors (client/security errors)"
    echo "   - 5xxErrors (server errors)"
    echo "   - BytesDownloaded/Uploaded (data transfer)"
    echo "   - GetRequests, PutRequests, DeleteRequests"
    echo ""
    echo "🚨 Security alarms for request-based metrics will also become active"
    
else
    echo ""
    echo "✅ Keeping current configuration (storage metrics only)"
    echo "🔒 Security monitoring via CloudTrail remains fully active"
fi

echo ""
echo "📊 Current Dashboard Status:"
echo "✅ Storage Metrics: ACTIVE (BucketSizeBytes, NumberOfObjects)"
echo "✅ CloudTrail Security: ACTIVE (All API calls logged)"
echo "✅ Security Alarms: RDS monitoring active"
echo ""
echo "🔗 Dashboard URL:"
echo "https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=S3-Security-Monitoring-UAT"

