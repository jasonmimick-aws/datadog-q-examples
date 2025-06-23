#!/bin/bash
# Script to simulate high CPU usage in WordPress containers
# This script uses AWS CLI to update the ECS service to run a modified task definition
# that includes a CPU-intensive process

set -e

# Configuration
CLUSTER_NAME=${1:-"wordpress-cluster"}
SERVICE_NAME=${2:-"wordpress-service"}
DURATION=${3:-300}  # Duration in seconds (default: 5 minutes)

echo "Simulating high CPU usage on ECS service $SERVICE_NAME in cluster $CLUSTER_NAME"
echo "This simulation will run for $DURATION seconds"

# Get current task definition
TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].taskDefinition' --output text)
echo "Current task definition: $TASK_DEF"

# Create a new task definition revision with CPU stress test
CONTAINER_DEF=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.containerDefinitions' --output json)

# Add CPU stress command to the WordPress container
UPDATED_CONTAINER_DEF=$(echo $CONTAINER_DEF | jq '.[0].command = ["/bin/bash", "-c", "apt-get update && apt-get install -y stress-ng && stress-ng --cpu 2 --timeout '"$DURATION"'s & apache2-foreground"]')

# Register the new task definition
NEW_TASK_DEF=$(aws ecs register-task-definition \
  --family $(echo $TASK_DEF | cut -d':' -f1) \
  --execution-role-arn $(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.executionRoleArn' --output text) \
  --task-role-arn $(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.taskRoleArn' --output text) \
  --network-mode $(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.networkMode' --output text) \
  --container-definitions "$UPDATED_CONTAINER_DEF" \
  --requires-compatibilities FARGATE \
  --cpu $(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.cpu' --output text) \
  --memory $(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.memory' --output text) \
  --volumes "$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.volumes' --output json)" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

echo "Created new task definition: $NEW_TASK_DEF"

# Update the service to use the new task definition
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $NEW_TASK_DEF
echo "Updated service to use the new task definition"

echo "High CPU simulation started. Will run for $DURATION seconds."
echo "Monitor in Datadog dashboard to observe the effects."

# Wait for the specified duration
echo "Waiting for $DURATION seconds..."
sleep $DURATION

# Revert to the original task definition
echo "Reverting to original task definition: $TASK_DEF"
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $TASK_DEF

echo "Service reverted to original configuration."
echo "Note: It may take a few minutes for the new tasks to be deployed."