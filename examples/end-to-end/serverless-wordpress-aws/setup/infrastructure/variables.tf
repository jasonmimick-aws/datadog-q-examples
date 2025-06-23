variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "wordpress-serverless"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Username for the WordPress database"
  type        = string
  default     = "wordpress"
}

variable "db_password" {
  description = "Password for the WordPress database"
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
  sensitive   = true
}

variable "wordpress_image" {
  description = "Docker image for WordPress with Datadog agent"
  type        = string
  default     = "wordpress:latest"
}