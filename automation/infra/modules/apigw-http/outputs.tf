output "api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.webhook.id
}

output "api_endpoint" {
  description = "HTTP API default endpoint URL"
  value       = aws_apigatewayv2_api.webhook.api_endpoint
}

output "webhook_url" {
  description = "Full webhook URL for Jira"
  value       = "${aws_apigatewayv2_api.webhook.api_endpoint}/automation/jira/webhook"
}

output "execution_arn" {
  description = "Execution ARN for Lambda permission"
  value       = aws_apigatewayv2_api.webhook.execution_arn
}
