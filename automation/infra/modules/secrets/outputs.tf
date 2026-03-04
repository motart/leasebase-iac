output "webhook_secret_arn" {
  description = "ARN of webhook shared secret"
  value       = aws_secretsmanager_secret.webhook_secret.arn
}

output "github_token_secret_arn" {
  description = "ARN of GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.arn
}

output "webhook_secret_name" {
  description = "Name of webhook shared secret"
  value       = aws_secretsmanager_secret.webhook_secret.name
}

output "github_token_secret_name" {
  description = "Name of GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.name
}
