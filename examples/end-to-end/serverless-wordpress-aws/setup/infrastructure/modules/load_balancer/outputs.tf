output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.wordpress.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.wordpress.arn
}