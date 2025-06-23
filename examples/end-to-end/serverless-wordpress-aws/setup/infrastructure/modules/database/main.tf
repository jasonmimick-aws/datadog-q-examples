resource "aws_rds_cluster" "wordpress" {
  cluster_identifier      = "${var.name_prefix}-db-cluster"
  engine                  = "aurora-mysql"
  engine_mode             = "serverless"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = var.db_subnet_group_id
  vpc_security_group_ids  = var.vpc_security_group_ids
  skip_final_snapshot     = true
  backup_retention_period = 7
  
  scaling_configuration {
    auto_pause               = true
    min_capacity             = 1
    max_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }

  tags = {
    Name = "${var.name_prefix}-db-cluster"
  }
}