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
  description = "List of subnet IDs for the EFS mount targets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the EFS mount targets"
  type        = list(string)
}