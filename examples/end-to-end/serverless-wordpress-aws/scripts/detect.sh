#!/bin/bash
# Script for detecting issues in the serverless WordPress deployment using Q CLI and Datadog API

set -e

# Configuration
DATADOG_API_KEY=${DATADOG_API_KEY:-""}
DATADOG_APP_KEY=${DATADOG_APP_KEY:-""}
SERVICE_NAME=${1:-"wordpress"}
ENVIRONMENT=${2:-"production"}
THRESHOLD_CPU=${3:-80}  # CPU threshold percentage
THRESHOLD_MEMORY=${4:-80}  # Memory threshold percentage
THRESHOLD_ERRORS=${5:-5}  # Error threshold count
THRESHOLD_LATENCY=${6:-2000}  # Latency threshold in ms

if [ -z "$DATADOG_API_KEY" ] || [ -z "$DATADOG_APP_KEY" ]; then
  echo "Error: Datadog API and Application keys are required"
  echo "Please set DATADOG_API_KEY and DATADOG_APP_KEY environment variables"
  exit 1
fi

echo "Detecting issues for service: $SERVICE_NAME in environment: $ENVIRONMENT"

# Function to query Datadog metrics
query_metric() {
  local metric=$1
  local query=$2
  local from=$(date -u -d '5 minutes ago' +"%s")
  local to=$(date -u +"%s")
  
  echo "Querying metric: $metric"
  
  result=$(curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=$query" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY")
  
  # Extract the latest value
  value=$(echo $result | jq -r '.series[0].pointlist[-1][1] // "N/A"')
  echo "$metric: $value"
  echo "$value"
}

# Check CPU usage
cpu_query="avg:ecs.fargate.cpu.percent{service:$SERVICE_NAME,env:$ENVIRONMENT}"
cpu_value=$(query_metric "CPU Usage" "$cpu_query")

# Check memory usage
memory_query="avg:ecs.fargate.mem.usage{service:$SERVICE_NAME,env:$ENVIRONMENT} / avg:ecs.fargate.mem.limit{service:$SERVICE_NAME,env:$ENVIRONMENT} * 100"
memory_value=$(query_metric "Memory Usage" "$memory_query")

# Check error rate
error_query="sum:trace.http.request.errors{service:$SERVICE_NAME,env:$ENVIRONMENT}.as_count()"
error_value=$(query_metric "Error Rate" "$error_query")

# Check response latency
latency_query="avg:trace.http.request{service:$SERVICE_NAME,env:$ENVIRONMENT}"
latency_value=$(query_metric "Response Latency" "$latency_query")

# Check database connections
db_conn_query="avg:mysql.net.connections{service:$SERVICE_NAME,env:$ENVIRONMENT}"
db_conn_value=$(query_metric "DB Connections" "$db_conn_query")

# Analyze results using Q CLI
echo "Analyzing metrics with Q CLI..."

# Create a temporary file with the metrics data
metrics_file=$(mktemp)
cat > $metrics_file << EOF
{
  "service": "$SERVICE_NAME",
  "environment": "$ENVIRONMENT",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "metrics": {
    "cpu_usage": $cpu_value,
    "memory_usage": $memory_value,
    "error_rate": $error_value,
    "response_latency": $latency_value,
    "db_connections": $db_conn_value
  },
  "thresholds": {
    "cpu_usage": $THRESHOLD_CPU,
    "memory_usage": $THRESHOLD_MEMORY,
    "error_rate": $THRESHOLD_ERRORS,
    "response_latency": $THRESHOLD_LATENCY
  }
}
EOF

# Use Q CLI to analyze the metrics (this is a placeholder for the actual Q CLI command)
# In a real implementation, this would use the Q CLI to analyze the metrics
echo "Q CLI analysis:"
echo "Analyzing metrics data in $metrics_file"
echo "This would use Q CLI to analyze the metrics and provide recommendations"

# For demonstration purposes, we'll implement a simple analysis here
if (( $(echo "$cpu_value > $THRESHOLD_CPU" | bc -l) )); then
  echo "ALERT: High CPU usage detected ($cpu_value% > $THRESHOLD_CPU%)"
  echo "Possible causes:"
  echo "- Traffic spike"
  echo "- Inefficient WordPress plugins"
  echo "- Resource-intensive background processes"
  echo "Recommended actions:"
  echo "- Check for recent traffic patterns"
  echo "- Review active plugins"
  echo "- Consider scaling up the service"
fi

if (( $(echo "$memory_value > $THRESHOLD_MEMORY" | bc -l) )); then
  echo "ALERT: High memory usage detected ($memory_value% > $THRESHOLD_MEMORY%)"
  echo "Possible causes:"
  echo "- Memory leaks in WordPress plugins"
  echo "- Insufficient memory allocation"
  echo "- Large media processing operations"
  echo "Recommended actions:"
  echo "- Review memory-intensive plugins"
  echo "- Consider increasing memory allocation"
  echo "- Optimize media handling"
fi

if (( $(echo "$error_value > $THRESHOLD_ERRORS" | bc -l) )); then
  echo "ALERT: High error rate detected ($error_value > $THRESHOLD_ERRORS)"
  echo "Possible causes:"
  echo "- Database connectivity issues"
  echo "- PHP errors in themes or plugins"
  echo "- External service failures"
  echo "Recommended actions:"
  echo "- Check database connection status"
  echo "- Review WordPress error logs"
  echo "- Verify external service health"
fi

if (( $(echo "$latency_value > $THRESHOLD_LATENCY" | bc -l) )); then
  echo "ALERT: High response latency detected ($latency_value ms > $THRESHOLD_LATENCY ms)"
  echo "Possible causes:"
  echo "- Database query performance issues"
  echo "- Inefficient WordPress theme or plugins"
  echo "- Network latency"
  echo "Recommended actions:"
  echo "- Optimize database queries"
  echo "- Enable caching"
  echo "- Review theme and plugin performance"
fi

# Check for database connection issues
if [[ "$db_conn_value" == "N/A" || "$db_conn_value" == "0" ]]; then
  echo "ALERT: Database connection issues detected"
  echo "Possible causes:"
  echo "- Database server down"
  echo "- Security group misconfiguration"
  echo "- Network connectivity issues"
  echo "Recommended actions:"
  echo "- Check database server status"
  echo "- Verify security group rules"
  echo "- Check network connectivity"
fi

# Cleanup
rm $metrics_file

echo "Detection complete. Use 'q analyze' for more detailed analysis."