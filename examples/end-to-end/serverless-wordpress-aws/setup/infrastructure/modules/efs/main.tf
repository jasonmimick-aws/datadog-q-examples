resource "aws_efs_file_system" "wordpress" {
  creation_token = "${var.name_prefix}-efs"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.name_prefix}-efs"
  }
}

resource "aws_efs_mount_target" "wordpress" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = var.security_group_ids
}

resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.wordpress.id

  posix_user {
    gid = 33 # www-data
    uid = 33 # www-data
  }

  root_directory {
    path = "/wordpress"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.name_prefix}-efs-ap"
  }
}