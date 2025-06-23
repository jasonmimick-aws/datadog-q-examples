#!/bin/bash
# Script to simulate database connection issues in WordPress
# This script temporarily modifies the security group rules to block database access

set -e

# Configuration
DB_SECURITY_GROUP_ID=${1:-""}
ECS_SECURITY_GROUP_ID=${2:-""}
DURATION=${3:-300}  # Duration in seconds (default: 5 minutes)

if [ -z "$DB_SECURITY_GROUP_ID" ] || [ -z "$ECS_SECURITY_GROUP_ID" ]; then
  echo "Error: Security group IDs are required"
  echo "Usage: $0 <db-security-group-id> <ecs-security-group-id> [duration-in-seconds]"
  exit 1
fi

echo "Simulating database connection issues by modifying security group rules"
echo "This simulation will run for $DURATION seconds"

# Get current ingress rules for the database security group
echo "Backing up current security group rules..."
CURRENT_RULES=$(aws ec2 describe-security-groups --group-ids $DB_SECURITY_GROUP_ID --query 'SecurityGroups[0].IpPermissions' --output json)
echo "Current rules backed up"

# Remove the ingress rule that allows ECS to connect to the database
echo "Removing database access from ECS security group..."
aws ec2 revoke-security-group-ingress \
  --group-id $DB_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 3306 \
  --source-group $ECS_SECURITY_GROUP_ID

echo "Database access blocked. WordPress should now experience connection errors."
echo "Monitor in Datadog dashboard to observe the effects."

# Wait for the specified duration
echo "Waiting for $DURATION seconds..."
sleep $DURATION

# Restore the original security group rules
echo "Restoring database access..."
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SECURITY_GROUP_ID \
  --protocol tcp \
  --port 3306 \
  --source-group $ECS_SECURITY_GROUP_ID

echo "Database access restored."
echo "Note: It may take a few minutes for WordPress to recover fully."