# Incident Detection Guide

This guide explains how to detect and diagnose incidents in the serverless WordPress deployment using Datadog and Q CLI.

## Monitoring with Datadog

The WordPress deployment is monitored using Datadog with the following components:

### Key Metrics

1. **Infrastructure Metrics**
   - CPU utilization
   - Memory usage
   - Network traffic
   - ECS task counts

2. **Application Metrics**
   - Request latency
   - Error rates
   - Database query performance
   - WordPress hook execution times

3. **Database Metrics**
   - Query throughput
   - Connection count
   - Buffer pool utilization
   - Slow query count

### Dashboards

The main dashboard for monitoring the WordPress deployment is available in the Datadog dashboard. It includes:

- Service health overview
- Infrastructure metrics
- Application performance
- Database performance
- Error logs

### Alerts

The following alerts are configured in Datadog:

1. **High CPU Alert**
   - Triggers when CPU usage exceeds 80% for 5 minutes
   - Indicates potential performance issues or traffic spikes

2. **Memory Usage Alert**
   - Triggers when memory usage exceeds 80% for 5 minutes
   - Indicates potential memory leaks or insufficient resources

3. **Error Rate Alert**
   - Triggers when error rate exceeds 5 errors per minute
   - Indicates application issues or external service failures

4. **Database Connection Alert**
   - Triggers when database connections drop to zero
   - Indicates database connectivity issues

5. **Response Time Alert**
   - Triggers when average response time exceeds 2 seconds
   - Indicates performance degradation

## Using Q CLI for Incident Detection

The `detect.sh` script in the `scripts` directory uses Q CLI to detect and diagnose incidents. It performs the following steps:

1. Queries Datadog for key metrics
2. Analyzes the metrics against predefined thresholds
3. Identifies potential issues
4. Provides initial recommendations

### Running the Detection Script

```bash
# Set Datadog API and Application keys
export DATADOG_API_KEY="your_api_key"
export DATADOG_APP_KEY="your_app_key"

# Run the detection script
./scripts/detect.sh [service_name] [environment] [cpu_threshold] [memory_threshold] [error_threshold] [latency_threshold]
```

Example:
```bash
./scripts/detect.sh wordpress production 80 80 5 2000
```

### Understanding Detection Output

The detection script output includes:

1. **Current Metric Values**
   - CPU usage
   - Memory usage
   - Error rate
   - Response latency
   - Database connections

2. **Alerts**
   - Triggered when metrics exceed thresholds
   - Include possible causes
   - Provide recommended actions

3. **Q CLI Analysis**
   - More detailed analysis of the metrics
   - Correlation between different metrics
   - Identification of patterns

## Common Incident Patterns

### 1. High CPU Usage

**Symptoms:**
- CPU usage consistently above 80%
- Increased response times
- Potential task restarts

**Possible Causes:**
- Traffic spike
- Inefficient WordPress plugins
- Resource-intensive background processes

**Detection:**
```bash
./scripts/detect.sh wordpress production 80 80 5 2000
```

### 2. Database Connection Issues

**Symptoms:**
- Database connection errors in logs
- HTTP 500 errors
- Zero database connections metric

**Possible Causes:**
- Security group misconfiguration
- Database server down
- Network connectivity issues

**Detection:**
```bash
./scripts/detect.sh wordpress production 80 80 5 2000
```

### 3. Memory Leaks

**Symptoms:**
- Gradually increasing memory usage
- Eventual container restarts
- Performance degradation over time

**Possible Causes:**
- Memory leaks in WordPress plugins
- PHP memory management issues
- Improper caching configuration

**Detection:**
```bash
./scripts/detect.sh wordpress production 80 80 5 2000
```

## Simulating Incidents for Testing

The `scripts` directory includes scripts to simulate common incidents for testing:

### 1. Simulate High CPU Usage

```bash
./scripts/simulate_high_cpu.sh [cluster_name] [service_name] [duration]
```

This script temporarily modifies the ECS task definition to include a CPU-intensive process, causing high CPU utilization.

### 2. Simulate Database Issues

```bash
./scripts/simulate_db_issues.sh [db_security_group_id] [ecs_security_group_id] [duration]
```

This script temporarily modifies security group rules to block database access, causing database connection errors.

## Next Steps

After detecting an incident, proceed to the [Root Cause Analysis](./root_cause_analysis.md) guide to determine the underlying cause and implement a fix.