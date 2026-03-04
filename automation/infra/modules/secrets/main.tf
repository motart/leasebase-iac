################################################################################
# Secrets Manager — webhook shared secret + GitHub token
################################################################################

resource "aws_secretsmanager_secret" "webhook_secret" {
  name        = "${var.name_prefix}/webhook-secret"
  description = "Shared secret for Jira webhook validation"
  tags        = var.common_tags
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = var.webhook_secret_value
}

resource "aws_secretsmanager_secret" "github_token" {
  name        = "${var.name_prefix}/github-token"
  description = "GitHub PAT for dispatching workflows"
  tags        = var.common_tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token_value
}
