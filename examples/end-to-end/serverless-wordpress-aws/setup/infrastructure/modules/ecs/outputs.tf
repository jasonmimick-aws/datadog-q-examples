output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.wordpress.name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.wordpress.name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.wordpress.arn
}