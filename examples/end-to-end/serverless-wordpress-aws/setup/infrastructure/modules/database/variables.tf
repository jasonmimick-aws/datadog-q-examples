variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "db_subnet_group_id" {
  description = "ID of the database subnet group"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs for the database"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
}

variable "db_username" {
  description = "Username for the WordPress database"
  type        = string
}

variable "db_password" {
  description = "Password for the WordPress database"
  type        = string
  sensitive   = true
}