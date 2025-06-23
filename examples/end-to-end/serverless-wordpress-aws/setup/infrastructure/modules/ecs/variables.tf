variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group for the ECS tasks"
  type        = string
}

variable "efs_id" {
  description = "ID of the EFS file system"
  type        = string
}

variable "efs_access_point_id" {
  description = "ID of the EFS access point"
  type        = string
}

variable "db_host" {
  description = "Hostname of the database"
  type        = string
}

variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
}

variable "db_user" {
  description = "Username for the WordPress database"
  type        = string
}

variable "db_password" {
  description = "Password for the WordPress database"
  type        = string
  sensitive   = true
}

variable "target_group_arn" {
  description = "ARN of the target group for the load balancer"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key for monitoring"
  type        = string
  sensitive   = true
}

variable "wordpress_image" {
  description = "Docker image for WordPress"
  type        = string
  default     = "wordpress:latest"
}