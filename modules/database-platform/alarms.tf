################################################################################
# CloudWatch Alarms — Database Monitoring
################################################################################

locals {
  alarm_actions = var.sns_alarm_topic_arn != "" ? [var.sns_alarm_topic_arn] : []
}

# ── CPU Utilization ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.name_prefix}-db-cpu-high"
  alarm_description   = "Aurora cluster CPU utilization > ${var.alarm_cpu_threshold}%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.common_tags
}

# ── Database Connections ─────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "${var.name_prefix}-db-connections-high"
  alarm_description   = "Aurora database connections > ${var.alarm_connections_threshold}"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = var.alarm_connections_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.common_tags
}

# ── Free Local Storage ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "storage" {
  alarm_name          = "${var.name_prefix}-db-storage-low"
  alarm_description   = "Aurora free local storage < ${var.alarm_free_storage_threshold / 1073741824} GB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeLocalStorage"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_free_storage_threshold
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.alarm_actions

  tags = var.common_tags
}

# ── Deadlocks ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "deadlocks" {
  alarm_name          = "${var.name_prefix}-db-deadlocks"
  alarm_description   = "Aurora deadlocks detected"
  namespace           = "AWS/RDS"
  metric_name         = "Deadlocks"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = local.alarm_actions

  tags = var.common_tags
}
