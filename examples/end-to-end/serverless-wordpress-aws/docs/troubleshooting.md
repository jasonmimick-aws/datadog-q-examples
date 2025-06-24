# Troubleshooting Guide: Serverless WordPress on AWS

This guide provides solutions to common issues you may encounter when deploying and managing the serverless WordPress solution on AWS with Datadog monitoring.

## Quick Diagnostic Commands

Before diving into specific issues, run these commands to gather basic information:

```bash
# Check AWS CLI configuration
aws sts get-caller-identity

# Verify Datadog API connectivity
curl -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY"

# Check ECS service status
aws ecs describe-services --cluster wordpress-cluster --services wordpress

# Check recent ECS events
aws ecs describe-services --cluster wordpress-cluster --services wordpress \
  --query 'services[0].events[0:5]'
```

## Infrastructure Deployment Issues

### Issue: Terraform Apply Fails with Permission Errors

**Symptoms:**
```
Error: AccessDenied: User: arn:aws:iam::123456789012:user/username is not authorized to perform: ecs:CreateCluster
```

**Root Cause:** Insufficient AWS IAM permissions

**Solution:**
1. Ensure your AWS user has the following managed policies:
   - `PowerUserAccess` or `AdministratorAccess`
   - Or create a custom policy with required permissions

2. Required permissions include:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:*",
           "ecs:*",
           "rds:*",
           "elasticfilesystem:*",
           "elasticloadbalancing:*",
           "iam:*",
           "logs:*",
           "secretsmanager:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

3. Verify permissions:
   ```bash
   aws iam get-user
   aws iam list-attached-user-policies --user-name your-username
   ```

### Issue: Aurora Serverless Creation Fails

**Symptoms:**
```
Error: InvalidParameterValue: Aurora Serverless is not available in the specified Availability Zone
```

**Root Cause:** Aurora Serverless not available in selected AZ

**Solution:**
1. Check Aurora Serverless availability:
   ```bash
   aws rds describe-orderable-db-instance-options \
     --engine aurora-mysql \
     --query 'OrderableDBInstanceOptions[?SupportsStorageAutoscaling==`true`].AvailabilityZones'
   ```

2. Update `terraform.tfvars` with supported AZs:
   ```hcl
   availability_zones = ["us-east-1a", "us-east-1b"]  # Use supported AZs
   ```

3. Alternative: Use Aurora Provisioned with auto-scaling:
   ```hcl
   # In setup/infrastructure/modules/database/main.tf
   engine_mode = "provisioned"
   ```

### Issue: ECS Tasks Fail to Start

**Symptoms:**
- ECS service shows 0 running tasks
- Tasks stop immediately after starting

**Diagnostic Commands:**
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks --cluster wordpress-cluster --service-name wordpress \
  --desired-status STOPPED --query 'taskArns[0]' --output text)

# Check task details
aws ecs describe-tasks --cluster wordpress-cluster --tasks $TASK_ARN

# Check task logs
aws logs get-log-events \
  --log-group-name /ecs/wordpress \
  --log-stream-name ecs/wordpress/$(echo $TASK_ARN | cut -d'/' -f3)
```

**Common Solutions:**

1. **Memory/CPU Issues:**
   ```bash
   # Increase task resources in terraform.tfvars
   task_cpu = 1024      # Increase from 512
   task_memory = 2048   # Increase from 1024
   ```

2. **Database Connection Issues:**
   ```bash
   # Check security groups allow ECS to database communication
   aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
   ```

3. **EFS Mount Issues:**
   ```bash
   # Verify EFS mount targets exist
   aws efs describe-mount-targets --file-system-id fs-xxxxxxxxx
   ```

## WordPress Configuration Issues

### Issue: WordPress Installation Page Not Loading

**Symptoms:**
- Browser shows "This site can't be reached"
- Load balancer health checks failing

**Diagnostic Commands:**
```bash
# Check load balancer status
aws elbv2 describe-load-balancers --names wordpress-alb

# Check target group health
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
  --names wordpress-targets --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

**Solutions:**

1. **Security Group Issues:**
   ```bash
   # Ensure ALB security group allows inbound HTTP/HTTPS
   aws ec2 authorize-security-group-ingress \
     --group-id sg-xxxxxxxxx \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0
   ```

2. **Health Check Configuration:**
   ```bash
   # Update health check path if needed
   aws elbv2 modify-target-group \
     --target-group-arn $TARGET_GROUP_ARN \
     --health-check-path "/wp-admin/install.php"
   ```

### Issue: WordPress Database Connection Error

**Symptoms:**
```
Error establishing a database connection
```

**Diagnostic Commands:**
```bash
# Test database connectivity from ECS task
TASK_ARN=$(aws ecs list-tasks --cluster wordpress-cluster --service-name wordpress \
  --query 'taskArns[0]' --output text)

aws ecs execute-command \
  --cluster wordpress-cluster \
  --task $TASK_ARN \
  --container wordpress \
  --interactive \
  --command "/bin/bash"

# Inside container, test database connection
mysql -h $WORDPRESS_DB_HOST -u $WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -e "SELECT 1;"
```

**Solutions:**

1. **Check Database Status:**
   ```bash
   aws rds describe-db-clusters --db-cluster-identifier wordpress-cluster
   ```

2. **Verify Environment Variables:**
   ```bash
   # Check ECS task definition
   aws ecs describe-task-definition --task-definition wordpress:latest \
     --query 'taskDefinition.containerDefinitions[0].environment'
   ```

3. **Security Group Rules:**
   ```bash
   # Ensure ECS security group can reach database
   aws ec2 authorize-security-group-ingress \
     --group-id sg-database-sg \
     --protocol tcp \
     --port 3306 \
     --source-group sg-ecs-sg
   ```

### Issue: WordPress Files Not Persisting

**Symptoms:**
- Uploaded media files disappear after container restart
- Plugin installations don't persist

**Root Cause:** EFS not properly mounted or configured

**Solutions:**

1. **Verify EFS Mount:**
   ```bash
   # Check EFS file system
   aws efs describe-file-systems --file-system-id fs-xxxxxxxxx
   
   # Check mount targets
   aws efs describe-mount-targets --file-system-id fs-xxxxxxxxx
   ```

2. **Check ECS Task Definition:**
   ```bash
   aws ecs describe-task-definition --task-definition wordpress:latest \
     --query 'taskDefinition.volumes'
   ```

3. **Test EFS from Container:**
   ```bash
   # Inside WordPress container
   df -h | grep efs
   ls -la /var/www/html/wp-content/
   touch /var/www/html/wp-content/test-file
   ```

## Datadog Integration Issues

### Issue: No Metrics Appearing in Datadog

**Symptoms:**
- Datadog dashboard shows no data
- Host not appearing in Datadog infrastructure list

**Diagnostic Commands:**
```bash
# Check Datadog agent status in container
aws ecs execute-command \
  --cluster wordpress-cluster \
  --task $TASK_ARN \
  --container datadog-agent \
  --interactive \
  --command "/bin/bash"

# Inside container
datadog-agent status
```

**Solutions:**

1. **Verify API Keys:**
   ```bash
   # Check environment variables in task definition
   aws ecs describe-task-definition --task-definition wordpress:latest \
     --query 'taskDefinition.containerDefinitions[?name==`datadog-agent`].environment'
   ```

2. **Check Agent Configuration:**
   ```bash
   # Verify agent can reach Datadog
   curl -v https://api.datadoghq.com/api/v1/validate \
     -H "DD-API-KEY: $DATADOG_API_KEY"
   ```

3. **Network Connectivity:**
   ```bash
   # Ensure outbound HTTPS is allowed
   aws ec2 describe-security-groups --group-ids sg-ecs-sg \
     --query 'SecurityGroups[0].IpPermissionsEgress'
   ```

### Issue: Logs Not Appearing in Datadog

**Symptoms:**
- Application logs missing from Datadog Log Explorer
- Only infrastructure metrics visible

**Solutions:**

1. **Enable Log Collection:**
   ```bash
   # Check Datadog agent configuration
   # Ensure DD_LOGS_ENABLED=true in task definition
   ```

2. **Configure Log Driver:**
   ```json
   {
     "logDriver": "awslogs",
     "options": {
       "awslogs-group": "/ecs/wordpress",
       "awslogs-region": "us-east-1",
       "awslogs-stream-prefix": "ecs"
     }
   }
   ```

3. **Check Log Group Permissions:**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/ecs/wordpress"
   ```

## Q CLI Issues

### Issue: Q CLI Commands Fail with Authentication Error

**Symptoms:**
```
Error: Failed to authenticate with Datadog API
```

**Solutions:**

1. **Verify Environment Variables:**
   ```bash
   echo $DATADOG_API_KEY
   echo $DATADOG_APP_KEY
   ```

2. **Test API Connectivity:**
   ```bash
   curl -X GET "https://api.datadoghq.com/api/v1/validate" \
     -H "DD-API-KEY: $DATADOG_API_KEY" \
     -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY"
   ```

3. **Check Key Permissions:**
   - Ensure API key has required scopes
   - Verify Application key is not expired

### Issue: Detection Script Returns No Data

**Symptoms:**
```
CPU Usage: N/A
Memory Usage: N/A
```

**Root Cause:** Metrics not available or incorrect query

**Solutions:**

1. **Verify Metric Names:**
   ```bash
   # List available metrics
   curl -X GET "https://api.datadoghq.com/api/v1/metrics" \
     -H "DD-API-KEY: $DATADOG_API_KEY" \
     -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" | \
     jq '.metrics[] | select(. | contains("ecs"))'
   ```

2. **Check Time Range:**
   ```bash
   # Ensure data exists in the queried time range
   # Modify scripts/detect.sh to use longer time range
   local from=$(date -u -d '15 minutes ago' +"%s")  # Increase from 5 minutes
   ```

3. **Verify Service Tags:**
   ```bash
   # Check if service and environment tags are correct
   curl -X GET "https://api.datadoghq.com/api/v1/tags/hosts" \
     -H "DD-API-KEY: $DATADOG_API_KEY" \
     -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY"
   ```

## Performance Issues

### Issue: High Response Times

**Symptoms:**
- WordPress pages load slowly (>3 seconds)
- High latency in Datadog metrics

**Diagnostic Commands:**
```bash
# Check database performance
aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name wordpress-params

# Monitor ECS task performance
aws ecs describe-services --cluster wordpress-cluster --services wordpress \
  --query 'services[0].deployments[0]'
```

**Solutions:**

1. **Enable WordPress Caching:**
   ```bash
   # Install and configure caching plugins
   wp plugin install w3-total-cache --activate --allow-root
   wp plugin install redis-cache --activate --allow-root
   ```

2. **Optimize Database:**
   ```bash
   # Increase database capacity if using Aurora Serverless v1
   # Or migrate to Aurora Serverless v2 for better performance
   ```

3. **Scale ECS Service:**
   ```bash
   aws ecs update-service \
     --cluster wordpress-cluster \
     --service wordpress \
     --desired-count 4  # Increase from 2
   ```

### Issue: High Memory Usage

**Symptoms:**
- Memory usage consistently above 80%
- Containers being killed due to memory limits

**Solutions:**

1. **Increase Task Memory:**
   ```bash
   # Update terraform.tfvars
   task_memory = 2048  # Increase from 1024
   
   # Apply changes
   terraform apply -var-file=terraform.tfvars
   ```

2. **Optimize WordPress:**
   ```bash
   # Limit WordPress memory usage
   echo "define('WP_MEMORY_LIMIT', '256M');" >> wp-config.php
   ```

3. **Monitor Memory Leaks:**
   ```bash
   # Use Datadog APM to identify memory-intensive operations
   # Check for problematic plugins or themes
   ```

## Security Issues

### Issue: WordPress Admin Panel Accessible from Internet

**Symptoms:**
- WordPress admin accessible without VPN
- Security scanning alerts

**Solutions:**

1. **Restrict Admin Access:**
   ```bash
   # Update ALB security group to restrict /wp-admin access
   aws ec2 authorize-security-group-ingress \
     --group-id sg-alb-sg \
     --protocol tcp \
     --port 80 \
     --cidr 10.0.0.0/8  # Only allow internal access
   ```

2. **Implement WAF:**
   ```bash
   # Create WAF web ACL
   aws wafv2 create-web-acl \
     --name wordpress-waf \
     --scope REGIONAL \
     --default-action Allow={}
   ```

3. **Use Strong Authentication:**
   ```bash
   # Install two-factor authentication plugin
   wp plugin install two-factor --activate --allow-root
   ```

## Backup and Recovery Issues

### Issue: No Backup Strategy

**Symptoms:**
- No automated backups configured
- Risk of data loss

**Solutions:**

1. **Enable RDS Automated Backups:**
   ```bash
   aws rds modify-db-cluster \
     --db-cluster-identifier wordpress-cluster \
     --backup-retention-period 7 \
     --preferred-backup-window "03:00-04:00"
   ```

2. **Backup EFS Data:**
   ```bash
   # Enable EFS backup
   aws efs put-backup-policy \
     --file-system-id fs-xxxxxxxxx \
     --backup-policy Status=ENABLED
   ```

3. **WordPress-Level Backups:**
   ```bash
   # Install backup plugin
   wp plugin install updraftplus --activate --allow-root
   ```

## Monitoring and Alerting Issues

### Issue: Too Many False Positive Alerts

**Symptoms:**
- Frequent alerts for normal operations
- Alert fatigue among team members

**Solutions:**

1. **Adjust Alert Thresholds:**
   ```bash
   # Edit setup/datadog/setup_monitors.sh
   # Increase CPU threshold from 80% to 90%
   # Increase memory threshold based on baseline
   ```

2. **Add Alert Conditions:**
   ```bash
   # Require sustained high usage before alerting
   # Add time-based conditions (e.g., only during business hours)
   ```

3. **Implement Alert Grouping:**
   ```bash
   # Group related alerts to reduce noise
   # Use Datadog alert dependencies
   ```

## Getting Help

### Collecting Diagnostic Information

When seeking help, collect this information:

```bash
#!/bin/bash
# Diagnostic information collection script

echo "=== AWS Configuration ===" > diagnostic_info.txt
aws sts get-caller-identity >> diagnostic_info.txt

echo "=== ECS Service Status ===" >> diagnostic_info.txt
aws ecs describe-services --cluster wordpress-cluster --services wordpress >> diagnostic_info.txt

echo "=== Recent ECS Events ===" >> diagnostic_info.txt
aws ecs describe-services --cluster wordpress-cluster --services wordpress \
  --query 'services[0].events[0:10]' >> diagnostic_info.txt

echo "=== Database Status ===" >> diagnostic_info.txt
aws rds describe-db-clusters --db-cluster-identifier wordpress-cluster >> diagnostic_info.txt

echo "=== Load Balancer Status ===" >> diagnostic_info.txt
aws elbv2 describe-load-balancers --names wordpress-alb >> diagnostic_info.txt

echo "=== Datadog Connectivity ===" >> diagnostic_info.txt
curl -X GET "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" >> diagnostic_info.txt 2>&1

echo "Diagnostic information saved to diagnostic_info.txt"
```

### Support Resources

- **AWS Support**: Use AWS Support Center for infrastructure issues
- **Datadog Support**: Contact Datadog support for monitoring issues
- **WordPress Community**: WordPress.org support forums
- **GitHub Issues**: Report bugs in the example repository

### Community Resources

- **AWS ECS Documentation**: https://docs.aws.amazon.com/ecs/
- **Datadog Documentation**: https://docs.datadoghq.com/
- **WordPress Codex**: https://codex.wordpress.org/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/

This troubleshooting guide covers the most common issues encountered when deploying and managing the serverless WordPress solution. For issues not covered here, use the diagnostic commands and support resources to gather more information and seek help from the appropriate communities.