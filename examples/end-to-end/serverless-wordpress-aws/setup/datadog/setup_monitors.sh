#!/bin/bash
# Script to set up Datadog monitors for WordPress on ECS

# Check if Datadog API key is provided
if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
  echo "Error: Datadog API key (DD_API_KEY) and Application key (DD_APP_KEY) must be set as environment variables."
  exit 1
fi

# Base URL for Datadog API
DD_API_URL="https://api.datadoghq.com/api/v1"

# Common headers for API requests
HEADERS=(
  -H "Content-Type: application/json"
  -H "DD-API-KEY: $DD_API_KEY"
  -H "DD-APPLICATION-KEY: $DD_APP_KEY"
)

echo "Setting up Datadog monitors for WordPress on ECS..."

# Monitor 1: High CPU Usage
echo "Creating monitor for high CPU usage..."
curl -X POST "$DD_API_URL/monitor" \
  "${HEADERS[@]}" \
  -d '{
    "name": "WordPress - High CPU Usage",
    "type": "metric alert",
    "query": "avg(last_5m):avg:ecs.fargate.cpu.percent{service:wordpress} > 80",
    "message": "CPU usage for WordPress service is above 80% for 5 minutes. @slack-ops-channel",
    "tags": ["service:wordpress", "env:production"],
    "priority": 2,
    "options": {
      "thresholds": {
        "critical": 80,
        "warning": 70
      },
      "notify_audit": true,
      "require_full_window": false,
      "notify_no_data": false,
      "renotify_interval": 60,
      "include_tags": true,
      "evaluation_delay": 300
    }
  }'

# Monitor 2: High Memory Usage
echo "Creating monitor for high memory usage..."
curl -X POST "$DD_API_URL/monitor" \
  "${HEADERS[@]}" \
  -d '{
    "name": "WordPress - High Memory Usage",
    "type": "metric alert",
    "query": "avg(last_5m):avg:ecs.fargate.mem.rss{service:wordpress} / avg:ecs.fargate.mem.limit{service:wordpress} * 100 > 85",
    "message": "Memory usage for WordPress service is above 85% for 5 minutes. @slack-ops-channel",
    "tags": ["service:wordpress", "env:production"],
    "priority": 2,
    "options": {
      "thresholds": {
        "critical": 85,
        "warning": 75
      },
      "notify_audit": true,
      "require_full_window": false,
      "notify_no_data": false,
      "renotify_interval": 60,
      "include_tags": true,
      "evaluation_delay": 300
    }
  }'

# Monitor 3: HTTP Error Rate
echo "Creating monitor for HTTP error rate..."
curl -X POST "$DD_API_URL/monitor" \
  "${HEADERS[@]}" \
  -d '{
    "name": "WordPress - High HTTP Error Rate",
    "type": "query alert",
    "query": "sum(last_5m):sum:trace.http.request.errors{service:wordpress}.as_count() / sum:trace.http.request.hits{service:wordpress}.as_count() * 100 > 5",
    "message": "WordPress service is experiencing a high rate of HTTP errors (>5%). @slack-ops-channel",
    "tags": ["service:wordpress", "env:production"],
    "priority": 1,
    "options": {
      "thresholds": {
        "critical": 5,
        "warning": 2
      },
      "notify_audit": true,
      "require_full_window": false,
      "notify_no_data": false,
      "renotify_interval": 30,
      "include_tags": true
    }
  }'

# Monitor 4: Database Connection Issues
echo "Creating monitor for database connection issues..."
curl -X POST "$DD_API_URL/monitor" \
  "${HEADERS[@]}" \
  -d '{
    "name": "WordPress - Database Connection Issues",
    "type": "metric alert",
    "query": "avg(last_5m):avg:mysql.net.max_connections{service:wordpress} - avg:mysql.net.connections{service:wordpress} < 10",
    "message": "WordPress database is running low on available connections. @slack-ops-channel",
    "tags": ["service:wordpress", "env:production"],
    "priority": 1,
    "options": {
      "thresholds": {
        "critical": 10,
        "warning": 20
      },
      "notify_audit": true,
      "require_full_window": false,
      "notify_no_data": true,
      "no_data_timeframe": 10,
      "renotify_interval": 30,
      "include_tags": true
    }
  }'

# Monitor 5: Slow Response Time
echo "Creating monitor for slow response time..."
curl -X POST "$DD_API_URL/monitor" \
  "${HEADERS[@]}" \
  -d '{
    "name": "WordPress - Slow Response Time",
    "type": "metric alert",
    "query": "avg(last_5m):avg:trace.http.request{service:wordpress} > 2000",
    "message": "WordPress service is experiencing slow response times (>2s). @slack-ops-channel",
    "tags": ["service:wordpress", "env:production"],
    "priority": 2,
    "options": {
      "thresholds": {
        "critical": 2000,
        "warning": 1000
      },
      "notify_audit": true,
      "require_full_window": false,
      "notify_no_data": false,
      "renotify_interval": 60,
      "include_tags": true
    }
  }'

echo "Datadog monitors setup complete!"