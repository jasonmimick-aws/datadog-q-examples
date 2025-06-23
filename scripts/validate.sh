#!/bin/bash
# Example validation script
# This script validates the structure and content of examples

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
  echo -e "${RED}ERROR: $1${NC}"
}

# Function to print success messages
success() {
  echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Function to print warning messages
warning() {
  echo -e "${YELLOW}WARNING: $1${NC}"
}

# Function to validate an example
validate_example() {
  local example_path=$1
  local example_name=$(basename "$example_path")
  
  echo "Validating example: $example_name"
  
  # Check if README.md exists
  if [ ! -f "$example_path/README.md" ]; then
    error "Missing README.md in $example_name"
    return 1
  fi
  
  # Check if metadata.yaml exists
  if [ ! -f "$example_path/metadata.yaml" ]; then
    error "Missing metadata.yaml in $example_name"
    return 1
  fi
  
  # Validate metadata.yaml structure
  validate_metadata "$example_path/metadata.yaml"
  
  # Check for required directories
  for dir in "scripts" "setup"; do
    if [ ! -d "$example_path/$dir" ]; then
      warning "Missing $dir directory in $example_name"
    fi
  done
  
  # Check README.md for required sections
  validate_readme "$example_path/README.md"
  
  success "Example $example_name passed validation"
  return 0
}

# Function to validate metadata.yaml
validate_metadata() {
  local metadata_file=$1
  
  # Check for required fields
  for field in "title" "description" "categories" "difficulty" "time_required" "environments" "tools" "contributors" "last_tested"; do
    if ! grep -q "$field:" "$metadata_file"; then
      error "Missing required field '$field' in metadata.yaml"
      return 1
    fi
  done
  
  # Validate difficulty level
  if ! grep -q "difficulty: \"\\(beginner\\|intermediate\\|advanced\\)\"" "$metadata_file"; then
    error "Invalid difficulty level in metadata.yaml. Must be one of: beginner, intermediate, advanced"
    return 1
  fi
  
  return 0
}

# Function to validate README.md
validate_readme() {
  local readme_file=$1
  
  # Check for required sections
  for section in "Problem Statement" "Prerequisites" "Solution Overview" "Implementation Steps" "Expected Outcomes"; do
    if ! grep -q "^## $section" "$readme_file"; then
      error "Missing required section '$section' in README.md"
      return 1
    fi
  done
  
  # Check for recommended sections
  for section in "Troubleshooting" "Further Reading"; do
    if ! grep -q "^## $section" "$readme_file"; then
      warning "Missing recommended section '$section' in README.md"
    fi
  done
  
  return 0
}

# Main function
main() {
  local examples_dir=${1:-"examples"}
  local exit_code=0
  
  echo "Starting validation of examples in $examples_dir"
  
  # Find all examples
  if [ -d "$examples_dir" ]; then
    # Find directories that contain a README.md and metadata.yaml
    while IFS= read -r example_dir; do
      if ! validate_example "$example_dir"; then
        exit_code=1
      fi
    done < <(find "$examples_dir" -type d -exec test -f "{}/README.md" -a -f "{}/metadata.yaml" \; -print)
  else
    error "Examples directory $examples_dir does not exist"
    exit_code=1
  fi
  
  if [ $exit_code -eq 0 ]; then
    success "All examples passed validation"
  else
    error "Some examples failed validation"
  fi
  
  return $exit_code
}

# Run the main function
main "$@"