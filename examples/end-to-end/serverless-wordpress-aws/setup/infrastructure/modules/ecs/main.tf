resource "aws_ecs_cluster" "wordpress" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "wordpress" {
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 30

  tags = {
    Name = "${var.name_prefix}-logs"
  }
}

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "${var.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = var.wordpress_image
      essential = true
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "WORDPRESS_DB_HOST"
          value = var.db_host
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = var.db_name
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = var.db_user
        },
        {
          name  = "WORDPRESS_DB_PASSWORD"
          value = var.db_password
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "wordpress-data"
          containerPath = "/var/www/html"
          readOnly      = false
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.wordpress.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "wordpress"
        }
      },
      
      # Enable Datadog APM for WordPress
      dockerLabels = {
        "com.datadoghq.ad.logs" = "[{\"source\": \"wordpress\", \"service\": \"wordpress\"}]"
        "com.datadoghq.ad.check_names" = "[\"apache\", \"mysql\"]"
        "com.datadoghq.ad.init_configs" = "[{}, {}]"
        "com.datadoghq.ad.instances" = "[{\"apache_status_url\": \"http://%%host%%/server-status?auto\"}, {\"server\": \"%%host%%\", \"user\": \"${var.db_user}\", \"pass\": \"${var.db_password}\"}]"
      }
    },
    {
      name      = "datadog-agent"
      image     = "datadog/agent:7"
      essential = true
      
      environment = [
        {
          name  = "DD_API_KEY"
          value = var.datadog_api_key
        },
        {
          name  = "DD_SITE"
          value = "datadoghq.com"
        },
        # APM Configuration
        {
          name  = "DD_APM_ENABLED"
          value = "true"
        },
        {
          name  = "DD_APM_NON_LOCAL_TRAFFIC"
          value = "true"
        },
        # Logs Configuration
        {
          name  = "DD_LOGS_ENABLED"
          value = "true"
        },
        {
          name  = "DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL"
          value = "true"
        },
        # Metrics Configuration
        {
          name  = "DD_PROCESS_AGENT_ENABLED"
          value = "true"
        },
        {
          name  = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
          value = "true"
        },
        # ECS Integration
        {
          name  = "DD_ECS_COLLECT_RESOURCE_TAGS_EC2"
          value = "true"
        },
        {
          name  = "ECS_FARGATE"
          value = "true"
        },
        # Tagging
        {
          name  = "DD_TAGS"
          value = "service:wordpress env:production"
        },
        # Auto-discovery
        {
          name  = "DD_AUTOCONFIG_FROM_LABELS"
          value = "true"
        },
        # WordPress DB Connection
        {
          name  = "WORDPRESS_DB_HOST"
          value = var.db_host
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = var.db_name
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = var.db_user
        },
        {
          name  = "WORDPRESS_DB_PASSWORD"
          value = var.db_password
        }
      ]
      
      portMappings = [
        {
          containerPort = 8126
          hostPort      = 8126
          protocol      = "tcp"
        },
        {
          containerPort = 8125
          hostPort      = 8125
          protocol      = "udp"
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "datadog-config"
          containerPath = "/etc/datadog-agent"
          readOnly      = false
        },
        {
          sourceVolume  = "docker-socket"
          containerPath = "/var/run/docker.sock"
          readOnly      = true
        },
        {
          sourceVolume  = "proc"
          containerPath = "/host/proc"
          readOnly      = true
        },
        {
          sourceVolume  = "cgroup"
          containerPath = "/host/sys/fs/cgroup"
          readOnly      = true
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.wordpress.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "datadog"
        }
      }
    }
  ])

  volume {
    name = "wordpress-data"
    
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }
  
  # Volumes for Datadog agent
  volume {
    name = "datadog-config"
  }
  
  volume {
    name = "docker-socket"
  }
  
  volume {
    name = "proc"
  }
  
  volume {
    name = "cgroup"
  }

  tags = {
    Name = "${var.name_prefix}-task"
  }
}

resource "aws_ecs_service" "wordpress" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.wordpress.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "wordpress"
    container_port   = 80
  }

  tags = {
    Name = "${var.name_prefix}-service"
  }
}

# IAM roles for ECS
resource "aws_iam_role" "ecs_execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-task-role"
  }
}

resource "aws_iam_policy" "efs_access" {
  name        = "${var.name_prefix}-efs-access-policy"
  description = "Policy to allow ECS tasks to access EFS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = var.efs_id
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = var.efs_access_point_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.efs_access.arn
}

data "aws_region" "current" {}