terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a random string for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name_prefix = "${var.project_name}-${random_string.suffix.result}"
}

# Import modules
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  name_prefix  = local.name_prefix
  vpc_cidr     = var.vpc_cidr
  azs          = var.availability_zones
}

module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  name_prefix  = local.name_prefix
  vpc_id       = module.vpc.vpc_id
}

module "database" {
  source = "./modules/database"
  
  project_name       = var.project_name
  name_prefix        = local.name_prefix
  db_subnet_group_id = module.vpc.database_subnet_group_id
  vpc_security_group_ids = [module.security.db_security_group_id]
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

module "efs" {
  source = "./modules/efs"
  
  project_name = var.project_name
  name_prefix  = local.name_prefix
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  security_group_ids = [module.security.efs_security_group_id]
}

module "load_balancer" {
  source = "./modules/load_balancer"
  
  project_name = var.project_name
  name_prefix  = local.name_prefix
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
}

module "ecs" {
  source = "./modules/ecs"
  
  project_name        = var.project_name
  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_id   = module.security.ecs_security_group_id
  efs_id              = module.efs.efs_id
  efs_access_point_id = module.efs.access_point_id
  db_host             = module.database.db_endpoint
  db_name             = var.db_name
  db_user             = var.db_username
  db_password         = var.db_password
  target_group_arn    = module.load_balancer.target_group_arn
  datadog_api_key     = var.datadog_api_key
  wordpress_image     = var.wordpress_image
}