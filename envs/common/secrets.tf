############################
# Secrets Manager
############################

# Database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name_prefix}/db-credentials"
  description = "Database credentials for Leasebase ${var.environment}"

  tags = {
    Name        = "${local.name_prefix}-db-credentials"
    Environment = var.environment
    Project     = "leasebase"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.db_name
  })
}

# Stripe API keys
resource "aws_secretsmanager_secret" "stripe" {
  name        = "${local.name_prefix}/stripe"
  description = "Stripe API keys for Leasebase ${var.environment}"

  tags = {
    Name        = "${local.name_prefix}-stripe"
    Environment = var.environment
    Project     = "leasebase"
  }
}

resource "aws_secretsmanager_secret_version" "stripe" {
  secret_id = aws_secretsmanager_secret.stripe.id
  secret_string = jsonencode({
    secret_key      = var.stripe_secret_key
    publishable_key = var.stripe_publishable_key
    webhook_secret  = var.stripe_webhook_secret
  })
}

# Application secrets (JWT, session, etc.)
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}/app-secrets"
  description = "Application secrets for Leasebase ${var.environment}"

  tags = {
    Name        = "${local.name_prefix}-app-secrets"
    Environment = var.environment
    Project     = "leasebase"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    jwt_secret     = var.jwt_secret
    session_secret = var.session_secret
  })
}
