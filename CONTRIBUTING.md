# Contributing to Datadog Q Examples Library

Thank you for your interest in contributing to the Datadog Q Examples Library! This document provides guidelines and instructions for contributing new examples or improving existing ones.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Example Structure](#example-structure)
- [Quality Standards](#quality-standards)
- [Submission Process](#submission-process)
- [Review Process](#review-process)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [project maintainers].

## How to Contribute

There are several ways to contribute to the Datadog Q Examples Library:

1. **Add a new example**: Create a new example demonstrating how to solve a specific problem using Q CLI and Datadog
2. **Improve an existing example**: Enhance, fix, or expand an existing example
3. **Update documentation**: Improve the general documentation or example-specific documentation
4. **Report issues**: Report bugs or suggest improvements for existing examples

## Example Structure

Each example must follow this structure:

```
examples/category/example-name/
├── README.md                 # Overview, problem statement, and instructions
├── metadata.yaml             # Example metadata
├── setup/                    # Setup scripts and configurations
│   ├── infrastructure/       # Infrastructure as code (if applicable)
│   └── datadog/              # Datadog configurations (dashboards, monitors)
├── data/                     # Sample data (if applicable)
├── scripts/                  # Implementation scripts
│   ├── detect.sh             # Detection scripts
│   ├── analyze.sh            # Analysis scripts
│   └── remediate.sh          # Remediation scripts
├── docs/                     # Example-specific documentation
│   ├── walkthrough.md        # Step-by-step walkthrough
│   └── advanced.md           # Advanced scenarios
└── tests/                    # Validation tests
```

### README.md Template

Each example's README.md should follow this structure:

```markdown
# Example Title

## Problem Statement
[Clear description of the problem this example addresses]

## Prerequisites
- Required tools and versions
- Required access and permissions
- Environment assumptions

## Solution Overview
[Brief description of the approach and technologies used]

## Implementation Steps
1. Step 1: [Description]
2. Step 2: [Description]
...

## Expected Outcomes
[What users should expect to see when successfully implementing the example]

## Troubleshooting
[Common issues and their solutions]

## Further Reading
[Links to related documentation and resources]
```

### Metadata Format

Each example must include a metadata.yaml file with the following information:

```yaml
# metadata.yaml
title: "Example Title"
description: "Brief description of the example"
categories:
  - "category1"
  - "category2"
difficulty: "beginner|intermediate|advanced"
time_required: "30 minutes"
environments:
  - "AWS"
  - "Kubernetes"
tools:
  - name: "Q CLI"
    version: ">=1.0.0"
  - name: "Datadog Agent"
    version: ">=7.0.0"
contributors:
  - name: "Your Name"
    github: "yourusername"
last_tested: "YYYY-MM-DD"
```

## Quality Standards

All examples must meet these quality standards:

1. **Completeness**: Examples must include all necessary code, configuration, and instructions to implement the solution
2. **Accuracy**: Examples must be tested and verified to work as described
3. **Clarity**: Instructions must be clear and easy to follow
4. **Relevance**: Examples must address real-world problems and use cases
5. **Security**: Examples must follow security best practices
6. **Maintainability**: Examples should minimize version dependencies and follow a consistent style

## Submission Process

To submit a new example or improvement:

1. **Fork the repository**: Create your own fork of the repository
2. **Create a branch**: Create a branch for your changes
3. **Implement your example**: Follow the example structure and quality standards
4. **Test your example**: Ensure your example works as expected
5. **Submit a pull request**: Submit a pull request with your changes

### Using Templates

To create a new example, you can use the provided templates:

```bash
# Copy the basic example template
cp -r templates/basic-example examples/category/your-example-name
```

## Review Process

All contributions will be reviewed by project maintainers. The review process includes:

1. **Structural validation**: Ensuring the example follows the required structure
2. **Quality check**: Verifying the example meets quality standards
3. **Technical review**: Evaluating the technical approach and implementation
4. **Documentation review**: Checking that documentation is clear and complete

Once your contribution passes review, it will be merged into the main repository.

Thank you for contributing to the Datadog Q Examples Library!