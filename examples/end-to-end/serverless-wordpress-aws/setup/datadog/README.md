# Datadog Integration for Serverless WordPress on AWS

This directory contains the configuration files and scripts needed to integrate Datadog monitoring with the serverless WordPress deployment on AWS ECS.

## Components

1. **datadog-agent-config.yaml**: Configuration file for the Datadog agent running in the ECS task.
2. **dashboard.json**: Predefined dashboard for monitoring WordPress performance and health.
3. **setup_monitors.sh**: Script to set up Datadog monitors for alerting on critical conditions.

## Integration Details

### Agent Configuration

The Datadog agent is deployed as a sidecar container in the same ECS task as the WordPress container. This setup enables:

- **Log Collection**: All logs from the WordPress container are automatically collected.
- **APM/Tracing**: Application performance monitoring is enabled to track HTTP requests and database queries.
- **Metrics Collection**: System metrics (CPU, memory, network) and application-specific metrics are collected.

### Monitoring Dashboard

The included dashboard provides visibility into:

- WordPress service health and response times
- Infrastructure metrics (CPU, memory usage)
- Database performance metrics
- Error rates and logs

### Alerting

The setup script configures alerts for:

- High CPU usage (>80%)
- High memory usage (>85%)
- Elevated HTTP error rates (>5%)
- Database connection issues
- Slow response times (>2s)

## Setup Instructions

1. **Deploy Infrastructure**: The Terraform code automatically deploys the Datadog agent alongside WordPress.

2. **Configure API Keys**: Set your Datadog API and application keys:
   ```bash
   export DD_API_KEY="your_api_key"
   export DD_APP_KEY="your_application_key"
   ```

3. **Set Up Monitors**: Run the setup script to create the monitors:
   ```bash
   ./setup_monitors.sh
   ```

4. **Import Dashboard**: Import the dashboard.json file into your Datadog account through the Datadog UI or API.

## Customization

- Modify the `datadog-agent-config.yaml` file to adjust agent settings.
- Edit the `dashboard.json` file to customize the monitoring dashboard.
- Update the `setup_monitors.sh` script to change alert thresholds or add new monitors.

## Troubleshooting

If you encounter issues with the Datadog integration:

1. Check that the Datadog API key is correctly set in the Terraform variables.
2. Verify that the Datadog agent container is running in the ECS task.
3. Check the agent logs for any configuration errors.
4. Ensure that the necessary permissions are granted to the ECS task role.