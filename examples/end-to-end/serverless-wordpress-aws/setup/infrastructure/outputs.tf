output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.load_balancer.alb_dns_name
}

output "database_endpoint" {
  description = "Endpoint of the Aurora Serverless database"
  value       = module.database.db_endpoint
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "wordpress_url" {
  description = "URL to access the WordPress site"
  value       = "http://${module.load_balancer.alb_dns_name}"
}