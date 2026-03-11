################################################################################
# Secrets Manager — Master + Per-Service Credentials
################################################################################

# ── Master credential ────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "master" {
  name        = "${var.name_prefix}/db-platform/master"
  description = "LeaseBase Aurora master credentials"
  kms_key_id  = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-master-secret"
  })
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    dbname   = var.database_name
    host     = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
    engine   = "postgres"
  })
}

# ── Per-service credentials ──────────────────────────────────────────
# Each DB-using service gets its own secret with scoped credentials.
# Passwords are generated; the actual DB user/schema creation is handled
# by scripts/schema-init.sql (run via scripts/run-schema-init.sh).

resource "random_password" "service" {
  for_each = local.db_services

  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]"
}

resource "aws_secretsmanager_secret" "service" {
  for_each = local.db_services

  name        = "leasebase/${each.key}-db"
  description = "LeaseBase ${each.key} service database credentials"
  kms_key_id  = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name    = "leasebase-${each.key}-db-secret"
    Service = each.key
  })
}

resource "aws_secretsmanager_secret_version" "service" {
  for_each = local.db_services

  secret_id = aws_secretsmanager_secret.service[each.key].id
  secret_string = jsonencode({
    username = each.value.db_user
    password = random_password.service[each.key].result
    dbname   = var.database_name
    schema   = each.value.schema
    host     = aws_db_proxy.main.endpoint
    port     = aws_rds_cluster.main.port
    engine   = "postgres"
  })
}
