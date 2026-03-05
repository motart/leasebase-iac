################################################################################
# Aurora PostgreSQL — Cluster + Instances + Parameter Groups
################################################################################

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:,.<>?"
}

# ── Subnet Group ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-platform"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-platform-subnet-group"
  })
}

# ── Cluster Parameter Group ──────────────────────────────────────────────────

resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.name_prefix}-db-platform-pg"
  family      = "aurora-postgresql16"
  description = "LeaseBase database platform cluster parameter group"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries > 1s
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = var.common_tags
}

# ── Aurora Cluster ───────────────────────────────────────────────────────────

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.name_prefix}-db-cluster"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = random_password.master.result

  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.db.id]

  storage_encrypted = true
  kms_key_id        = var.kms_key_id

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-db-platform-final"

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-cluster"
  })
}

# ── Aurora Instances (Multi-AZ: instance_count >= 2) ─────────────────────────

resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count

  identifier         = "${var.name_prefix}-db-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible          = false
  performance_insights_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-${count.index}"
  })
}
