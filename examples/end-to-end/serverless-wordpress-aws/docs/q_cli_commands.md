# Q CLI Commands for WordPress on ECS

This document provides a reference for Q CLI commands used in the serverless WordPress on AWS example. These commands help with detection, analysis, and remediation of common issues.

## Prerequisites

- Q CLI installed and configured
- Datadog API and Application keys set as environment variables
- AWS CLI configured with appropriate permissions

```bash
# Set up environment variables
export DATADOG_API_KEY="your-api-key"
export DATADOG_APP_KEY="your-app-key"
```

## Detection Commands

### Detect Issues

Use these commands to detect issues in your WordPress on ECS deployment:

```bash
# Basic detection
./scripts/detect.sh wordpress production

# Custom thresholds
./scripts/detect.sh wordpress production 70 80 10 3000

# Direct Q CLI command for anomaly detection
q detect anomalies \
  --service wordpress \
  --environment production \
  --metrics cpu,memory,errors,latency \
  --time-range 5m \
  --output anomalies.json

# Direct Q CLI command for threshold violations
q detect threshold-violations \
  --service wordpress \
  --environment production \
  --thresholds cpu=80,memory=80,errors=5,latency=2000 \
  --time-range 5m \
  --output violations.json

# Direct Q CLI command for pattern detection
q detect patterns \
  --service wordpress \
  --environment production \
  --time-range 5m \
  --output patterns.json
```

## Analysis Commands

Use these commands to analyze issues in your WordPress on ECS deployment:

```bash
# Basic analysis
./scripts/analyze.sh wordpress production

# Analysis with incident ID and custom time range
./scripts/analyze.sh wordpress production INC-12345 2h

# Direct Q CLI command for log analysis
q logs analyze \
  --service wordpress \
  --environment production \
  --time-range 1h \
  --output logs_analysis.json

# Direct Q CLI command for metric analysis
q metrics analyze \
  --service wordpress \
  --environment production \
  --time-range 1h \
  --output metrics_analysis.json

# Direct Q CLI command for trace analysis
q traces analyze \
  --service wordpress \
  --environment production \
  --time-range 1h \
  --output traces_analysis.json

# Direct Q CLI command for root cause determination
q analyze root-cause \
  --logs logs.json \
  --metrics cpu_metrics.json,memory_metrics.json,error_metrics.json \
  --traces traces.json \
  --output root_cause.json
```

## Remediation Commands

Use these commands to implement fixes for issues in your WordPress on ECS deployment:

```bash
# Basic remediation
./scripts/remediate.sh wordpress production

# Specific issue type remediation
./scripts/remediate.sh wordpress production cpu
./scripts/remediate.sh wordpress production memory
./scripts/remediate.sh wordpress production database
./scripts/remediate.sh wordpress production php
./scripts/remediate.sh wordpress production scaling

# Direct Q CLI command for generating remediation plan
q remediate plan \
  --root-cause root_cause.json \
  --service wordpress \
  --environment production \
  --output remediation_plan.json

# Direct Q CLI command for implementing remediation
q remediate implement \
  --plan remediation_plan.json \
  --service wordpress \
  --environment production \
  --output remediation_report.json

# Direct Q CLI command for scaling remediation
q remediate scale \
  --service wordpress \
  --environment production \
  --cluster wordpress-cluster \
  --desired-count 4 \
  --output scale_report.json

# Direct Q CLI command for resource remediation
q remediate resources \
  --service wordpress \
  --environment production \
  --cluster wordpress-cluster \
  --cpu 2048 \
  --memory 4096 \
  --output resource_report.json
```

## Verification Commands

Use these commands to verify the effectiveness of remediation:

```bash
# Direct Q CLI command for verification
q verify \
  --service wordpress \
  --environment production \
  --remediation-id REM-12345 \
  --time-range 30m \
  --output verification_report.json

# Direct Q CLI command for comparing before and after metrics
q compare metrics \
  --service wordpress \
  --environment production \
  --before "2025-06-23T10:00:00Z" \
  --after "2025-06-23T11:00:00Z" \
  --metrics cpu,memory,errors,latency \
  --output comparison_report.json
```

## Documentation Commands

Use these commands to generate documentation for incidents and remediations:

```bash
# Direct Q CLI command for generating incident documentation
q document incident \
  --service wordpress \
  --environment production \
  --incident-id INC-12345 \
  --root-cause root_cause.json \
  --remediation remediation_report.json \
  --output incident_doc.md

# Direct Q CLI command for generating runbook
q document runbook \
  --service wordpress \
  --environment production \
  --issue-type cpu \
  --detection detect.sh \
  --analysis analyze.sh \
  --remediation remediate.sh \
  --output cpu_runbook.md
```

## Integration with Datadog

Use these commands to integrate Q CLI with Datadog:

```bash
# Direct Q CLI command for creating Datadog monitor
q datadog create-monitor \
  --name "WordPress CPU High" \
  --query "avg:ecs.fargate.cpu.percent{service:wordpress,env:production} > 80" \
  --type metric alert \
  --message "CPU usage is high on WordPress service" \
  --tags "service:wordpress,env:production" \
  --output monitor.json

# Direct Q CLI command for creating Datadog dashboard
q datadog create-dashboard \
  --name "WordPress Service Overview" \
  --description "Overview of WordPress service metrics" \
  --widgets cpu:ecs.fargate.cpu.percent,memory:ecs.fargate.mem.usage,errors:trace.http.request.errors \
  --output dashboard.json
```

## Automation Examples

### Automated Detection and Remediation

This example shows how to set up automated detection and remediation:

```bash
#!/bin/bash
# Automated detection and remediation script

# Detect issues
./scripts/detect.sh wordpress production > detection_output.txt

# Check if issues were detected
if grep -q "ALERT" detection_output.txt; then
  echo "Issues detected, performing analysis..."
  
  # Analyze issues
  ./scripts/analyze.sh wordpress production > analysis_output.txt
  
  # Extract issue type from analysis
  if grep -q "High CPU utilization" analysis_output.txt; then
    ISSUE_TYPE="cpu"
  elif grep -q "High memory usage" analysis_output.txt; then
    ISSUE_TYPE="memory"
  elif grep -q "Database connectivity issues" analysis_output.txt; then
    ISSUE_TYPE="database"
  elif grep -q "PHP application errors" analysis_output.txt; then
    ISSUE_TYPE="php"
  else
    ISSUE_TYPE=""
  fi
  
  # Remediate issues
  if [ -n "$ISSUE_TYPE" ]; then
    echo "Remediating $ISSUE_TYPE issues..."
    ./scripts/remediate.sh wordpress production $ISSUE_TYPE
  else
    echo "No specific issue type identified, performing general remediation..."
    ./scripts/remediate.sh wordpress production
  fi
else
  echo "No issues detected"
fi
```

### Scheduled Health Check

This example shows how to set up a scheduled health check:

```bash
#!/bin/bash
# Scheduled health check script

# Run detection
./scripts/detect.sh wordpress production > /dev/null

# Check for specific issues
CPU_ISSUE=$(q detect threshold-violations --metrics cpu --threshold 80 --service wordpress --environment production --output json | jq -r '.violations.cpu')
MEMORY_ISSUE=$(q detect threshold-violations --metrics memory --threshold 80 --service wordpress --environment production --output json | jq -r '.violations.memory')
ERROR_ISSUE=$(q detect threshold-violations --metrics errors --threshold 5 --service wordpress --environment production --output json | jq -r '.violations.errors')

# Report health status
echo "WordPress Health Check: $(date)"
echo "CPU Status: ${CPU_ISSUE:-OK}"
echo "Memory Status: ${MEMORY_ISSUE:-OK}"
echo "Error Status: ${ERROR_ISSUE:-OK}"

# Send health report to Datadog
q datadog send-event \
  --title "WordPress Health Check" \
  --text "CPU: ${CPU_ISSUE:-OK}, Memory: ${MEMORY_ISSUE:-OK}, Errors: ${ERROR_ISSUE:-OK}" \
  --tags "service:wordpress,env:production" \
  --alert_type "info"
```

## Best Practices

1. **Regular Detection**: Run detection commands on a schedule to catch issues early
2. **Comprehensive Analysis**: Use multiple analysis commands to get a complete picture
3. **Targeted Remediation**: Use specific issue types for more effective remediation
4. **Verification**: Always verify the effectiveness of remediation
5. **Documentation**: Generate documentation for incidents and remediations
6. **Automation**: Automate detection, analysis, and remediation where possible
7. **Integration**: Integrate with Datadog for comprehensive monitoring