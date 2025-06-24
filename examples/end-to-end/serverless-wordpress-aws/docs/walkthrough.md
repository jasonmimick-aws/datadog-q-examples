# Complete Walkthrough: Serverless WordPress on AWS with Datadog

This comprehensive walkthrough guides you through deploying, monitoring, and managing a serverless WordPress installation on AWS using ECS Fargate and Aurora Serverless, with full observability through Datadog and incident management using Q CLI.

## Overview

By the end of this walkthrough, you will have:
- A fully functional serverless WordPress site running on AWS
- Complete monitoring and observability through Datadog
- Automated incident detection and remediation capabilities using Q CLI
- Understanding of how to troubleshoot and optimize the deployment

## Prerequisites

Before starting, ensure you have:

### Required Tools
- AWS CLI v2.0+ installed and configured
- Terraform v1.0+ installed
- Docker installed and running
- Q CLI v1.0+ installed
- Git for cloning the repository

### Required Access
- AWS account with administrator permissions
- Datadog account with API and Application keys
- Basic familiarity with AWS services (ECS, RDS, VPC)

### Environment Setup
```bash
# Verify AWS CLI configuration
aws sts get-caller-identity

# Set Datadog credentials
export DATADOG_API_KEY="your-datadog-api-key"
export DATADOG_APP_KEY="your-datadog-application-key"

# Verify Q CLI installation
q --version
```

## Phase 1: Infrastructure Deployment

### Step 1: Clone and Prepare the Repository

```bash
# Clone the repository
git clone <repository-url>
cd datadog-q-examples/examples/end-to-end/serverless-wordpress-aws

# Make scripts executable
chmod +x scripts/*.sh
chmod +x setup/datadog/*.sh
```

### Step 2: Configure Terraform Variables

Create a `terraform.tfvars` file in the `setup/infrastructure` directory:

```bash
cd setup/infrastructure
cat > terraform.tfvars << EOF
# Project Configuration
project_name = "wordpress-serverless"
environment = "production"

# AWS Configuration
aws_region = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database Configuration
db_name = "wordpress"
db_username = "wpuser"
db_password = "your-secure-password-here"  # Use AWS Secrets Manager in production

# ECS Configuration
wordpress_image = "wordpress:latest"
task_cpu = 512
task_memory = 1024
desired_count = 2

# Datadog Configuration
datadog_api_key = "$DATADOG_API_KEY"

# Domain Configuration (optional)
domain_name = "your-domain.com"  # Leave empty if not using custom domain
EOF
```

### Step 3: Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan -var-file=terraform.tfvars

# Deploy the infrastructure (this takes 10-15 minutes)
terraform apply -var-file=terraform.tfvars

# Save important outputs
terraform output > ../../../terraform_outputs.txt
```

**What happens during deployment:**
- VPC with public and private subnets across multiple AZs
- Aurora Serverless MySQL database in private subnets
- EFS file system for WordPress persistent storage
- Application Load Balancer for traffic distribution
- ECS Fargate cluster and service
- Security groups with least-privilege access
- IAM roles for ECS tasks and services

### Step 4: Verify Infrastructure Deployment

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster wordpress-cluster \
  --services wordpress

# Verify database is running
aws rds describe-db-clusters \
  --db-cluster-identifier wordpress-cluster

# Get the load balancer URL
aws elbv2 describe-load-balancers \
  --names wordpress-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

## Phase 2: WordPress Configuration

### Step 5: Access WordPress Setup

```bash
# Get the load balancer URL from Terraform output
ALB_URL=$(terraform output -raw alb_dns_name)
echo "WordPress URL: http://$ALB_URL"

# Open in browser or use curl to verify
curl -I http://$ALB_URL
```

Navigate to the URL in your browser and complete the WordPress installation:

1. **Language Selection**: Choose your preferred language
2. **Database Configuration**: This should be pre-configured via environment variables
3. **Site Information**: 
   - Site Title: "My Serverless WordPress Site"
   - Username: Create an admin user
   - Password: Use a strong password
   - Email: Your email address
4. **Complete Installation**: Click "Install WordPress"

### Step 6: Configure WordPress for Containerized Environment

Access the WordPress admin panel and install recommended plugins:

```bash
# Connect to a running WordPress container to install plugins via WP-CLI
TASK_ARN=$(aws ecs list-tasks --cluster wordpress-cluster --service-name wordpress --query 'taskArns[0]' --output text)

# Execute commands in the container
aws ecs execute-command \
  --cluster wordpress-cluster \
  --task $TASK_ARN \
  --container wordpress \
  --interactive \
  --command "/bin/bash"
```

Inside the container, install essential plugins:
```bash
# Install WP-CLI if not already available
wp plugin install redis-cache --activate --allow-root
wp plugin install w3-total-cache --activate --allow-root
wp plugin install health-check --activate --allow-root
```

## Phase 3: Datadog Integration Setup

### Step 7: Configure Datadog Monitoring

```bash
cd setup/datadog

# Set up Datadog dashboards and monitors
./setup_monitors.sh

# Verify Datadog agent is reporting
curl -X GET \
  "https://api.datadoghq.com/api/v1/hosts" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" | \
  jq '.host_list[] | select(.name | contains("wordpress"))'
```

### Step 8: Import Datadog Dashboard

```bash
# Import the pre-configured dashboard
curl -X POST \
  "https://api.datadoghq.com/api/v1/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" \
  -d @dashboard.json

echo "Dashboard imported successfully"
```

### Step 9: Verify Monitoring Setup

Check that metrics are flowing into Datadog:

```bash
# Check for ECS metrics
curl -X GET \
  "https://api.datadoghq.com/api/v1/query?from=$(date -d '5 minutes ago' +%s)&to=$(date +%s)&query=avg:ecs.fargate.cpu.percent{service:wordpress}" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" | \
  jq '.series[0].pointlist[-1]'
```

## Phase 4: Q CLI Configuration and Testing

### Step 10: Test Detection Capabilities

```bash
cd ../../../scripts

# Run basic detection
./detect.sh wordpress production

# Expected output should show current metrics
# If no issues are detected, you'll see normal metric values
```

### Step 11: Simulate and Detect Issues

Test the incident detection workflow:

```bash
# Simulate high CPU usage
./simulate_high_cpu.sh wordpress-cluster wordpress 300  # 5 minutes

# Wait 2-3 minutes, then run detection
./detect.sh wordpress production 70 80 5 2000

# You should see alerts for high CPU usage
```

### Step 12: Perform Root Cause Analysis

```bash
# Run analysis on the simulated issue
./analyze.sh wordpress production INC-TEST-001 30m

# Review the generated analysis report
cat /tmp/*/root_cause_analysis.md
```

### Step 13: Test Remediation

```bash
# Remediate the CPU issue
./remediate.sh wordpress production cpu

# Verify the remediation was successful
./detect.sh wordpress production
```

## Phase 5: Validation and Testing

### Step 14: Load Testing

Generate some traffic to test the system under load:

```bash
# Install Apache Bench if not available
# For Ubuntu/Debian: sudo apt-get install apache2-utils
# For macOS: brew install httpd

# Run a simple load test
ab -n 1000 -c 10 http://$ALB_URL/

# Monitor the results in Datadog dashboard
```

### Step 15: Database Performance Testing

Test database connectivity and performance:

```bash
# Simulate database issues
./scripts/simulate_db_issues.sh

# Detect the database issues
./detect.sh wordpress production

# Analyze and remediate
./analyze.sh wordpress production INC-DB-001 15m
./remediate.sh wordpress production database
```

### Step 16: Complete Validation

Run the comprehensive validation script:

```bash
./validate.sh wordpress production

# This script checks:
# - Infrastructure health
# - WordPress functionality
# - Datadog integration
# - Q CLI capabilities
# - All monitoring and alerting
```

## Phase 6: Optimization and Best Practices

### Step 17: Performance Optimization

Implement performance optimizations:

```bash
# Enable WordPress caching
# Access WordPress admin panel
# Go to W3 Total Cache settings
# Enable Page Cache, Database Cache, and Object Cache

# Configure CloudFront (optional)
cd setup/infrastructure
# Uncomment CloudFront configuration in main.tf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Step 18: Security Hardening

Implement security best practices:

```bash
# Update WordPress and plugins
wp core update --allow-root
wp plugin update --all --allow-root

# Install security plugins
wp plugin install wordfence --activate --allow-root
wp plugin install limit-login-attempts-reloaded --activate --allow-root

# Configure SSL/TLS (if using custom domain)
# Set up AWS Certificate Manager certificate
# Update ALB listener to use HTTPS
```

### Step 19: Monitoring Optimization

Fine-tune monitoring and alerting:

```bash
# Adjust alert thresholds based on observed baseline
# Edit setup/datadog/setup_monitors.sh
# Update CPU threshold from 80% to 85% if appropriate
# Update memory threshold based on actual usage patterns

# Re-run monitor setup
cd setup/datadog
./setup_monitors.sh
```

## Understanding the Architecture

### Key Components Explained

**ECS Fargate**: Provides serverless compute for WordPress containers
- No server management required
- Automatic scaling based on demand
- Pay only for resources used

**Aurora Serverless**: Provides serverless database
- Automatically scales based on demand
- Pauses during inactivity to save costs
- Compatible with MySQL WordPress requirements

**Application Load Balancer**: Distributes traffic
- Health checks ensure only healthy containers receive traffic
- SSL termination (when configured)
- Integration with AWS WAF for security

**Amazon EFS**: Provides persistent storage
- Shared across all WordPress containers
- Stores uploaded media and plugin files
- Automatically scales storage capacity

### Datadog Integration Points

**Infrastructure Monitoring**:
- ECS task and service metrics
- Database performance metrics
- Load balancer metrics
- Network and storage metrics

**Application Performance Monitoring (APM)**:
- WordPress response times
- Database query performance
- Plugin execution times
- User experience metrics

**Log Management**:
- Application logs from WordPress
- Web server access logs
- Database logs
- System logs from containers

### Q CLI Workflow

**Detection Phase**:
- Queries Datadog APIs for current metrics
- Compares against predefined thresholds
- Identifies anomalies and patterns
- Generates initial alerts and recommendations

**Analysis Phase**:
- Collects detailed logs, metrics, and traces
- Correlates data across different sources
- Applies machine learning for pattern recognition
- Determines most likely root causes

**Remediation Phase**:
- Generates remediation plans based on root cause
- Implements fixes through AWS APIs
- Validates that fixes resolve the issues
- Documents the incident and resolution

## Next Steps

After completing this walkthrough:

1. **Customize for Your Environment**:
   - Adjust resource sizes based on your traffic
   - Configure custom domain and SSL
   - Implement backup strategies

2. **Extend Monitoring**:
   - Add custom WordPress metrics
   - Implement synthetic monitoring
   - Set up log-based alerts

3. **Automate Operations**:
   - Set up CI/CD for WordPress updates
   - Implement automated scaling policies
   - Create runbooks for common issues

4. **Explore Advanced Features**:
   - Multi-region deployment
   - Blue/green deployment strategies
   - Advanced security configurations

## Troubleshooting Common Issues

If you encounter issues during the walkthrough, refer to the [Troubleshooting Guide](./troubleshooting.md) for detailed solutions to common problems.

## Educational Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [WordPress Performance Optimization](https://wordpress.org/support/article/optimization/)
- [Datadog Monitoring Best Practices](https://docs.datadoghq.com/monitors/guide/)
- [Q CLI Documentation](https://docs.q-cli.com/)

This walkthrough provides a complete end-to-end experience of deploying and managing a serverless WordPress application with comprehensive monitoring and automated incident management.