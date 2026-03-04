output "webhook_url" {
  description = "Jira webhook URL — register this in Jira admin"
  value       = module.apigw.webhook_url
}

output "api_endpoint" {
  description = "API Gateway base endpoint"
  value       = module.apigw.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = module.logs.lambda_log_group_name
}
