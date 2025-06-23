output "alb_security_group_id" {
  description = "ID of the security group for the application load balancer"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the security group for the ECS tasks"
  value       = aws_security_group.ecs.id
}

output "db_security_group_id" {
  description = "ID of the security group for the database"
  value       = aws_security_group.db.id
}

output "efs_security_group_id" {
  description = "ID of the security group for the EFS file system"
  value       = aws_security_group.efs.id
}