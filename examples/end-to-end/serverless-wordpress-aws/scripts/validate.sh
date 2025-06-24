#!/bin/bash
# Validation script for WordPress on ECS example
# This script validates that the example is correctly set up and functioning

set -e

# Configuration
DATADOG_API_KEY=${DATADOG_API_KEY:-""}
DATADOG_APP_KEY=${DATADOG_APP_KEY:-""}
SERVICE_NAME=${1:-"wordpress"}
ENVIRONMENT=${2:-"production"}
AWS_PROFILE=${3:-"default"}
AWS_REGION=${4:-"us-east-1"}
CLUSTER_NAME=${5:-"wordpress-cluster"}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create a temporary directory for validation artifacts
VALIDATION_DIR=$(mktemp -d)
echo "Validation artifacts will be stored in: $VALIDATION_DIR"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if environment variables are set
check_env_vars() {
  echo "Checking environment variables..."
  
  local missing_vars=0
  
  if [ -z "$DATADOG_API_KEY" ]; then
    echo -e "${YELLOW}Warning: DATADOG_API_KEY is not set${NC}"
    missing_vars=$((missing_vars+1))
  fi
  
  if [ -z "$DATADOG_APP_KEY" ]; then
    echo -e "${YELLOW}Warning: DATADOG_APP_KEY is not set${NC}"
    missing_vars=$((missing_vars+1))
  fi
  
  if [ $missing_vars -gt 0 ]; then
    echo -e "${YELLOW}Some environment variables are missing. Limited validation will be performed.${NC}"
    return 1
  else
    echo -e "${GREEN}All required environment variables are set.${NC}"
    return 0
  fi
}

# Function to check if required tools are installed
check_required_tools() {
  echo "Checking required tools..."
  
  local missing_tools=0
  
  # Check for AWS CLI
  if ! command_exists aws; then
    echo -e "${YELLOW}Warning: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    missing_tools=$((missing_tools+1))
  else
    echo -e "${GREEN}AWS CLI is installed.${NC}"
  fi
  
  # Check for jq
  if ! command_exists jq; then
    echo -e "${YELLOW}Warning: jq is not installed${NC}"
    echo "Please install jq: https://stedolan.github.io/jq/download/"
    missing_tools=$((missing_tools+1))
  else
    echo -e "${GREEN}jq is installed.${NC}"
  fi
  
  # Check for curl
  if ! command_exists curl; then
    echo -e "${YELLOW}Warning: curl is not installed${NC}"
    echo "Please install curl: https://curl.se/download.html"
    missing_tools=$((missing_tools+1))
  else
    echo -e "${GREEN}curl is installed.${NC}"
  fi
  
  # Check for Q CLI (simulated)
  if ! command_exists q; then
    echo -e "${YELLOW}Warning: Q CLI is not installed or not in PATH${NC}"
    echo "Please install Q CLI"
    missing_tools=$((missing_tools+1))
  else
    echo -e "${GREEN}Q CLI is installed.${NC}"
  fi
  
  if [ $missing_tools -gt 0 ]; then
    echo -e "${YELLOW}Some required tools are missing. Limited validation will be performed.${NC}"
    return 1
  else
    echo -e "${GREEN}All required tools are installed.${NC}"
    return 0
  fi
}

# Function to validate AWS configuration
validate_aws_config() {
  echo "Validating AWS configuration..."
  
  # Check if AWS CLI is configured
  if ! aws sts get-caller-identity --profile $AWS_PROFILE --region $AWS_REGION &> /dev/null; then
    echo -e "${YELLOW}Warning: AWS CLI is not configured correctly${NC}"
    echo "Please configure AWS CLI: aws configure --profile $AWS_PROFILE"
    return 1
  else
    echo -e "${GREEN}AWS CLI is configured correctly.${NC}"
    return 0
  fi
}

# Function to validate infrastructure
validate_infrastructure() {
  echo "Validating infrastructure..."
  
  # Check if ECS cluster exists
  if ! aws ecs describe-clusters --clusters $CLUSTER_NAME --profile $AWS_PROFILE --region $AWS_REGION &> /dev/null; then
    echo -e "${YELLOW}Warning: ECS cluster '$CLUSTER_NAME' does not exist${NC}"
    echo "Please create the ECS cluster using the Terraform code in setup/infrastructure/"
    return 1
  else
    echo -e "${GREEN}ECS cluster '$CLUSTER_NAME' exists.${NC}"
  fi
  
  # Check if ECS service exists
  if ! aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --profile $AWS_PROFILE --region $AWS_REGION &> /dev/null; then
    echo -e "${YELLOW}Warning: ECS service '$SERVICE_NAME' does not exist in cluster '$CLUSTER_NAME'${NC}"
    echo "Please create the ECS service using the Terraform code in setup/infrastructure/"
    return 1
  else
    echo -e "${GREEN}ECS service '$SERVICE_NAME' exists in cluster '$CLUSTER_NAME'.${NC}"
  fi
  
  # Get service details
  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --profile $AWS_PROFILE --region $AWS_REGION > $VALIDATION_DIR/service_details.json
  
  # Check if service is stable
  local running_count=$(jq -r '.services[0].runningCount' $VALIDATION_DIR/service_details.json)
  local desired_count=$(jq -r '.services[0].desiredCount' $VALIDATION_DIR/service_details.json)
  
  if [ "$running_count" -lt "$desired_count" ]; then
    echo -e "${YELLOW}Warning: ECS service is not stable. Running count ($running_count) is less than desired count ($desired_count)${NC}"
    return 1
  else
    echo -e "${GREEN}ECS service is stable. Running count: $running_count, Desired count: $desired_count${NC}"
  fi
  
  return 0
}

# Function to validate Datadog integration
validate_datadog_integration() {
  echo "Validating Datadog integration..."
  
  if [ -z "$DATADOG_API_KEY" ] || [ -z "$DATADOG_APP_KEY" ]; then
    echo -e "${YELLOW}Warning: Datadog API keys not set, skipping Datadog validation${NC}"
    return 1
  fi
  
  # Check if Datadog API is accessible
  if ! curl -s -o /dev/null -w "%{http_code}" "https://api.datadoghq.com/api/v1/validate" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" | grep -q "200"; then
    echo -e "${YELLOW}Warning: Unable to access Datadog API${NC}"
    echo "Please check your Datadog API and Application keys"
    return 1
  else
    echo -e "${GREEN}Datadog API is accessible.${NC}"
  fi
  
  # Check if metrics are being reported
  local from=$(date -u -d '1 hour ago' +"%s")
  local to=$(date -u +"%s")
  local query="avg:ecs.fargate.cpu.percent{service:$SERVICE_NAME,env:$ENVIRONMENT}"
  
  curl -s -X GET \
    "https://api.datadoghq.com/api/v1/query?from=$from&to=$to&query=$query" \
    -H "DD-API-KEY: $DATADOG_API_KEY" \
    -H "DD-APPLICATION-KEY: $DATADOG_APP_KEY" > $VALIDATION_DIR/metrics_check.json
  
  if jq -e '.series[0].pointlist | length > 0' $VALIDATION_DIR/metrics_check.json > /dev/null; then
    echo -e "${GREEN}Metrics are being reported to Datadog.${NC}"
  else
    echo -e "${YELLOW}Warning: No metrics found in Datadog for service '$SERVICE_NAME' in environment '$ENVIRONMENT'${NC}"
    echo "Please check that the Datadog agent is properly configured in your ECS tasks"
    return 1
  fi
  
  return 0
}

# Function to validate scripts
validate_scripts() {
  echo "Validating scripts..."
  
  local scripts=("detect.sh" "analyze.sh" "remediate.sh")
  local missing_scripts=0
  
  for script in "${scripts[@]}"; do
    if [ ! -f "$(dirname "$0")/$script" ]; then
      echo -e "${YELLOW}Warning: Script '$script' not found${NC}"
      missing_scripts=$((missing_scripts+1))
    else
      if [ ! -x "$(dirname "$0")/$script" ]; then
        echo -e "${YELLOW}Warning: Script '$script' is not executable${NC}"
        echo "Please make it executable: chmod +x $(dirname "$0")/$script"
        missing_scripts=$((missing_scripts+1))
      else
        echo -e "${GREEN}Script '$script' exists and is executable.${NC}"
      fi
    fi
  done
  
  if [ $missing_scripts -gt 0 ]; then
    echo -e "${YELLOW}Some scripts are missing or not executable. Limited functionality will be available.${NC}"
    return 1
  else
    echo -e "${GREEN}All required scripts exist and are executable.${NC}"
    return 0
  fi
}

# Function to validate test data
validate_test_data() {
  echo "Validating test data..."
  
  local data_dir="../data"
  
  if [ ! -d "$data_dir" ]; then
    echo -e "${YELLOW}Warning: Data directory not found${NC}"
    return 1
  fi
  
  # Check for required test data files
  local required_files=("cpu_spike.json" "memory_leak.json" "database_errors.json" "php_errors.json")
  local missing_files=0
  
  for file in "${required_files[@]}"; do
    if [ ! -f "$data_dir/$file" ]; then
      echo -e "${YELLOW}Warning: Test data file '$file' not found${NC}"
      missing_files=$((missing_files+1))
    else
      echo -e "${GREEN}Test data file '$file' exists.${NC}"
    fi
  done
  
  if [ $missing_files -gt 0 ]; then
    echo -e "${YELLOW}Some test data files are missing. Limited testing will be possible.${NC}"
    return 1
  else
    echo -e "${GREEN}All required test data files exist.${NC}"
    return 0
  fi
}

# Function to validate documentation
validate_documentation() {
  echo "Validating documentation..."
  
  local docs_dir="../docs"
  
  if [ ! -d "$docs_dir" ]; then
    echo -e "${YELLOW}Warning: Documentation directory not found${NC}"
    return 1
  fi
  
  # Check for required documentation files
  local required_files=("deployment.md" "incident_detection.md" "q_cli_commands.md" "root_cause_analysis.md")
  local missing_files=0
  
  for file in "${required_files[@]}"; do
    if [ ! -f "$docs_dir/$file" ]; then
      echo -e "${YELLOW}Warning: Documentation file '$file' not found${NC}"
      missing_files=$((missing_files+1))
    else
      echo -e "${GREEN}Documentation file '$file' exists.${NC}"
    fi
  done
  
  if [ $missing_files -gt 0 ]; then
    echo -e "${YELLOW}Some documentation files are missing. Limited guidance will be available.${NC}"
    return 1
  else
    echo -e "${GREEN}All required documentation files exist.${NC}"
    return 0
  fi
}

# Function to run a simple test
run_test() {
  echo "Running test: $1"
  
  case "$1" in
    "detect")
      echo "Testing detection script..."
      if [ -x "$(dirname "$0")/detect.sh" ]; then
        "$(dirname "$0")/detect.sh" $SERVICE_NAME $ENVIRONMENT > $VALIDATION_DIR/detect_output.txt
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Detection script executed successfully.${NC}"
          return 0
        else
          echo -e "${YELLOW}Warning: Detection script failed${NC}"
          return 1
        fi
      else
        echo -e "${YELLOW}Warning: Detection script not found or not executable${NC}"
        return 1
      fi
      ;;
    
    "analyze")
      echo "Testing analysis script..."
      if [ -x "$(dirname "$0")/analyze.sh" ]; then
        "$(dirname "$0")/analyze.sh" $SERVICE_NAME $ENVIRONMENT > $VALIDATION_DIR/analyze_output.txt
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Analysis script executed successfully.${NC}"
          return 0
        else
          echo -e "${YELLOW}Warning: Analysis script failed${NC}"
          return 1
        fi
      else
        echo -e "${YELLOW}Warning: Analysis script not found or not executable${NC}"
        return 1
      fi
      ;;
    
    "remediate")
      echo "Testing remediation script (dry run)..."
      if [ -x "$(dirname "$0")/remediate.sh" ]; then
        # We'll just check if the script exists and is executable, but not actually run it
        # to avoid making changes to the infrastructure
        echo -e "${GREEN}Remediation script exists and is executable.${NC}"
        echo -e "${YELLOW}Note: Remediation script not actually executed to avoid making changes.${NC}"
        return 0
      else
        echo -e "${YELLOW}Warning: Remediation script not found or not executable${NC}"
        return 1
      fi
      ;;
    
    *)
      echo -e "${RED}Error: Unknown test '$1'${NC}"
      return 1
      ;;
  esac
}

# Function to generate a validation report
generate_report() {
  echo "Generating validation report..."
  
  cat > $VALIDATION_DIR/validation_report.md << EOF
# Validation Report

## Environment
- Service: $SERVICE_NAME
- Environment: $ENVIRONMENT
- AWS Region: $AWS_REGION
- Validation Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Validation Results

### Prerequisites
- Environment Variables: $(if check_env_vars > /dev/null; then echo "✅"; else echo "⚠️"; fi)
- Required Tools: $(if check_required_tools > /dev/null; then echo "✅"; else echo "⚠️"; fi)
- AWS Configuration: $(if validate_aws_config > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Infrastructure
- ECS Cluster: $(if validate_infrastructure > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Datadog Integration
- Datadog API Access: $(if validate_datadog_integration > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Scripts
- Script Validation: $(if validate_scripts > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Test Data
- Test Data Validation: $(if validate_test_data > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Documentation
- Documentation Validation: $(if validate_documentation > /dev/null; then echo "✅"; else echo "⚠️"; fi)

### Tests
- Detection Test: $(if run_test "detect" > /dev/null; then echo "✅"; else echo "⚠️"; fi)
- Analysis Test: $(if run_test "analyze" > /dev/null; then echo "✅"; else echo "⚠️"; fi)
- Remediation Test: $(if run_test "remediate" > /dev/null; then echo "✅"; else echo "⚠️"; fi)

## Summary

This validation report provides an overview of the setup and functionality of the WordPress on ECS example. Any warnings or errors should be addressed before using the example in a production environment.

### Next Steps

1. Address any warnings or errors identified in this report
2. Run a full end-to-end test of the example
3. Customize the example for your specific environment
4. Document any changes made to the example
EOF
  
  echo "Validation report generated: $VALIDATION_DIR/validation_report.md"
}

# Main validation flow
echo "Starting validation of WordPress on ECS example..."

# Run all validation checks
check_env_vars
check_required_tools
validate_aws_config
validate_infrastructure
validate_datadog_integration
validate_scripts
validate_test_data
validate_documentation

# Run tests
run_test "detect"
run_test "analyze"
run_test "remediate"

# Generate validation report
generate_report

echo "Validation complete. Report available at: $VALIDATION_DIR/validation_report.md"

# Display the report
cat $VALIDATION_DIR/validation_report.md