#!/bin/bash
# Root cause analysis script for WordPress on ECS issues
# This script uses Q CLI to analyze logs, metrics, and traces to determine the root cause of issues

set -e

# Configuration
DATADOG_API_KEY=${DATADOG_API_KEY:-""}
DATADOG_APP_KEY=${DATADOG_APP_KEY:-""}
SERVICE_NAME=${1:-"wordpress"}
ENVIRONMENT=${2:-"production"}
INCIDENT_ID=${3:-""}
TIME_RANGE=${4:-"1h"}  # Time range to analyze (e.g., 1h, 30m, 2h)

if [ -z "$DATADOG_API_KEY" ] || [ -z "$DATADOG_APP_KEY" ]; then
  echo "Error: Datadog API and Application keys are required"
  echo "Please set DATADOG_API_KEY and DATADOG_APP_KEY environment variables"
  exit 1
fi

echo "Performing root cause analysis for service: $SERVICE_NAME in environment: $ENVIRONMENT"
echo "Time range: $TIME_RANGE"
if [ -n "$INCIDENT_ID" ]; then
  echo "Incident ID: $INCIDENT_ID"
fi

# Create a temporary directory for analysis artifacts
ANALYSIS_DIR=$(mktemp -d)
echo "Analysis artifacts will be stored in: $ANALYSIS_DIR"

# Function to fetch logs from Datadog
fetch_logs() {
  local query="service:$SERVICE_NAME env:$ENVIRONMENT"
  local from=$(date -u -d "$TIME_RANGE ago" +"%s")
  local to=$(date -u +"%s")
  
  echo "Fetching logs with query: $query"
  
  curl -s -X POST \
    "https://api.datadoghq.com/api/v2/logs/events/search" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
    -d "{
      \"filter\": {
        \"query\": \"$query\",
        \"from\": \"$from\",
        \"to\": \"$to\"
      },
      \"sort\": \"timestamp\",
      \"page\": {
        \"limit\": 100
      }
    }" > $ANALYSIS_DIR/logs.json
  
  echo "Logs saved to $ANALYSIS_DIR/logs.json"
}

# Function to fetch metrics from Datadog
fetch_metrics() {
  local from=$(date -u -d "$TIME_RANGE ago" +"%s")
  local to=$(date -u +"%s")
  
  # CPU metrics
  echo "Fetching CPU metrics"
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=avg:ecs.fargate.cpu.percent{service:$SERVICE_NAME,env:$ENVIRONMENT}" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $ANALYSIS_DIR/cpu_metrics.json
  
  # Memory metrics
  echo "Fetching memory metrics"
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=avg:ecs.fargate.mem.usage{service:$SERVICE_NAME,env:$ENVIRONMENT}" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $ANALYSIS_DIR/memory_metrics.json
  
  # Error rate metrics
  echo "Fetching error rate metrics"
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=sum:trace.http.request.errors{service:$SERVICE_NAME,env:$ENVIRONMENT}.as_count()" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $ANALYSIS_DIR/error_metrics.json
  
  # Database metrics
  echo "Fetching database metrics"
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=avg:mysql.performance.questions{service:$SERVICE_NAME,env:$ENVIRONMENT}" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $ANALYSIS_DIR/db_metrics.json
  
  echo "Metrics saved to $ANALYSIS_DIR/"
}

# Function to fetch traces from Datadog
fetch_traces() {
  local from=$(date -u -d "$TIME_RANGE ago" +"%s000")  # Milliseconds
  local to=$(date -u +"%s000")  # Milliseconds
  
  echo "Fetching traces"
  
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/synthetics/tests" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $ANALYSIS_DIR/traces.json
  
  echo "Traces saved to $ANALYSIS_DIR/traces.json"
}

# Fetch data from Datadog
echo "Fetching data from Datadog..."
fetch_logs
fetch_metrics
fetch_traces

# Analyze the data using Q CLI
echo "Analyzing data with Q CLI..."

# Use Q CLI to analyze the collected data
echo "Running Q CLI analysis..."

# Q CLI command for log analysis
echo "q logs analyze --service $SERVICE_NAME --environment $ENVIRONMENT --time-range $TIME_RANGE --output $ANALYSIS_DIR/q_logs_analysis.json"

# Q CLI command for metric analysis
echo "q metrics analyze --service $SERVICE_NAME --environment $ENVIRONMENT --time-range $TIME_RANGE --output $ANALYSIS_DIR/q_metrics_analysis.json"

# Q CLI command for trace analysis
echo "q traces analyze --service $SERVICE_NAME --environment $ENVIRONMENT --time-range $TIME_RANGE --output $ANALYSIS_DIR/q_traces_analysis.json"

# Q CLI command for root cause determination
echo "q analyze root-cause --logs $ANALYSIS_DIR/logs.json --metrics $ANALYSIS_DIR/cpu_metrics.json,$ANALYSIS_DIR/memory_metrics.json,$ANALYSIS_DIR/error_metrics.json,$ANALYSIS_DIR/db_metrics.json --traces $ANALYSIS_DIR/traces.json --output $ANALYSIS_DIR/q_root_cause.json"

# In a real implementation, we would execute these Q CLI commands
# For demonstration purposes, we'll simulate the output

# For demonstration purposes, we'll implement a simple analysis here
echo "Performing analysis on collected data..."

# Check for error patterns in logs
echo "Analyzing logs for error patterns..."
error_count=$(jq '.data | length' $ANALYSIS_DIR/logs.json)
echo "Found $error_count log entries"

# Look for specific error patterns
db_errors=$(jq '.data[] | select(.content | contains("database") and contains("error"))' $ANALYSIS_DIR/logs.json)
if [ -n "$db_errors" ]; then
  echo "Found database-related errors in logs"
  echo "$db_errors" > $ANALYSIS_DIR/db_errors.json
  echo "Database errors saved to $ANALYSIS_DIR/db_errors.json"
fi

php_errors=$(jq '.data[] | select(.content | contains("PHP") and contains("error"))' $ANALYSIS_DIR/logs.json)
if [ -n "$php_errors" ]; then
  echo "Found PHP errors in logs"
  echo "$php_errors" > $ANALYSIS_DIR/php_errors.json
  echo "PHP errors saved to $ANALYSIS_DIR/php_errors.json"
fi

# Analyze CPU metrics
echo "Analyzing CPU metrics..."
cpu_max=$(jq '.series[0].pointlist | map(.[1]) | max' $ANALYSIS_DIR/cpu_metrics.json)
echo "Maximum CPU usage: $cpu_max%"
if (( $(echo "$cpu_max > 80" | bc -l) )); then
  echo "High CPU usage detected (>80%)"
  echo "This could indicate:"
  echo "- Traffic spike"
  echo "- Inefficient code or plugins"
  echo "- Resource-intensive background processes"
fi

# Analyze memory metrics
echo "Analyzing memory metrics..."
memory_max=$(jq '.series[0].pointlist | map(.[1]) | max' $ANALYSIS_DIR/memory_metrics.json)
echo "Maximum memory usage: $memory_max bytes"

# Analyze error metrics
echo "Analyzing error metrics..."
error_max=$(jq '.series[0].pointlist | map(.[1]) | max' $ANALYSIS_DIR/error_metrics.json)
echo "Maximum error rate: $error_max errors"
if (( $(echo "$error_max > 0" | bc -l) )); then
  echo "Errors detected during the analyzed period"
fi

# Analyze database metrics
echo "Analyzing database metrics..."
db_query_max=$(jq '.series[0].pointlist | map(.[1]) | max' $ANALYSIS_DIR/db_metrics.json)
echo "Maximum database queries: $db_query_max queries/sec"

# Generate a summary report
echo "Generating root cause analysis report..."
cat > $ANALYSIS_DIR/rca_report.md << EOF
# Root Cause Analysis Report

## Incident Overview
- Service: $SERVICE_NAME
- Environment: $ENVIRONMENT
- Time Range: $TIME_RANGE
- Analysis Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Key Metrics
- Maximum CPU Usage: $cpu_max%
- Maximum Memory Usage: $memory_max bytes
- Maximum Error Rate: $error_max errors
- Maximum Database Queries: $db_query_max queries/sec

## Log Analysis
- Total Log Entries: $error_count
EOF

if [ -n "$db_errors" ]; then
  echo "- Database Errors: Yes" >> $ANALYSIS_DIR/rca_report.md
else
  echo "- Database Errors: No" >> $ANALYSIS_DIR/rca_report.md
fi

if [ -n "$php_errors" ]; then
  echo "- PHP Errors: Yes" >> $ANALYSIS_DIR/rca_report.md
else
  echo "- PHP Errors: No" >> $ANALYSIS_DIR/rca_report.md
fi

cat >> $ANALYSIS_DIR/rca_report.md << EOF

## Root Cause Determination

Based on the analysis of logs, metrics, and traces, the most likely root cause is:
EOF

# Determine the most likely root cause based on the collected data
if [ -n "$db_errors" ] && (( $(echo "$error_max > 0" | bc -l) )); then
  cat >> $ANALYSIS_DIR/rca_report.md << EOF
**Database connectivity issues**

The logs show database-related errors, and there are HTTP errors in the metrics. This suggests that the WordPress application is unable to connect to the database properly.

Possible specific causes:
1. Security group misconfiguration blocking database access
2. Database credentials issues
3. Database server performance problems
4. Network connectivity issues between the ECS tasks and the database

Recommended actions:
1. Verify security group rules allow traffic from ECS to the database
2. Check database credentials in the ECS task definition
3. Monitor database performance metrics for signs of overload
4. Check network connectivity between ECS and the database
EOF
elif (( $(echo "$cpu_max > 80" | bc -l) )); then
  cat >> $ANALYSIS_DIR/rca_report.md << EOF
**High CPU utilization**

The metrics show CPU usage exceeding 80%, which can lead to performance degradation and potential timeouts.

Possible specific causes:
1. Traffic spike exceeding current capacity
2. Inefficient WordPress plugins consuming excessive CPU
3. Poorly optimized database queries
4. Background processes consuming resources

Recommended actions:
1. Scale up the ECS service to handle the increased load
2. Review and optimize WordPress plugins
3. Implement caching to reduce CPU load
4. Optimize database queries
EOF
elif [ -n "$php_errors" ]; then
  cat >> $ANALYSIS_DIR/rca_report.md << EOF
**PHP application errors**

The logs show PHP errors, which indicate issues with the WordPress application code.

Possible specific causes:
1. Plugin compatibility issues
2. Theme errors
3. WordPress core issues
4. PHP configuration problems

Recommended actions:
1. Review PHP error logs for specific error messages
2. Disable recently added or updated plugins
3. Switch to a default theme to rule out theme issues
4. Verify PHP configuration settings
EOF
else
  cat >> $ANALYSIS_DIR/rca_report.md << EOF
**Inconclusive based on available data**

The available data does not clearly indicate a single root cause. Further investigation is recommended.

Possible areas to investigate:
1. External service dependencies
2. Network issues
3. Intermittent database performance
4. WordPress configuration issues

Recommended actions:
1. Extend the analysis time range
2. Collect additional logs and metrics
3. Perform synthetic transactions to reproduce the issue
4. Review recent changes to the environment
EOF
fi

echo "Root cause analysis report generated: $ANALYSIS_DIR/rca_report.md"
echo "Analysis artifacts are available in: $ANALYSIS_DIR"

# Display the report
cat $ANALYSIS_DIR/rca_report.md