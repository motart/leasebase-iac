################################################################################
# RDS Proxy — Connection Pooling
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── IAM role for RDS Proxy to read Secrets Manager ───────────────────────────

resource "aws_iam_role" "proxy" {
  name = "${var.name_prefix}-db-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "proxy_secrets" {
  name = "read-secrets"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = concat(
          [aws_secretsmanager_secret.master.arn],
          [for s in aws_secretsmanager_secret.service : s.arn]
        )
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
    ]
  })
}

# ── RDS Proxy ────────────────────────────────────────────────────────────────

resource "aws_db_proxy" "main" {
  name                   = "${var.name_prefix}-db-proxy"
  debug_logging          = false # TODO: re-enable for dev after routing refactor
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy.arn
  vpc_security_group_ids = [aws_security_group.proxy.id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "Master credentials"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.master.arn
  }

  # Per-service auth entries (one per DB-using service)
  dynamic "auth" {
    for_each = aws_secretsmanager_secret.service
    content {
      auth_scheme = "SECRETS"
      description = "${auth.key} service credentials"
      iam_auth    = "DISABLED"
      secret_arn  = auth.value.arn
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-proxy"
  })
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "main" {
  db_cluster_identifier = aws_rds_cluster.main.cluster_identifier
  db_proxy_name         = aws_db_proxy.main.name
  target_group_name     = aws_db_proxy_default_target_group.main.name
}
