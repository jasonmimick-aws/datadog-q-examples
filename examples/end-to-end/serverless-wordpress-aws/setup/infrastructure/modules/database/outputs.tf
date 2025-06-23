output "db_endpoint" {
  description = "Endpoint of the Aurora Serverless database"
  value       = aws_rds_cluster.wordpress.endpoint
}

output "db_reader_endpoint" {
  description = "Reader endpoint of the Aurora Serverless database"
  value       = aws_rds_cluster.wordpress.reader_endpoint
}

output "db_cluster_identifier" {
  description = "Identifier of the Aurora Serverless database cluster"
  value       = aws_rds_cluster.wordpress.cluster_identifier
}