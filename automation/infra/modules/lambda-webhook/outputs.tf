output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.webhook.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.webhook.arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN (for API Gateway integration)"
  value       = aws_lambda_function.webhook.invoke_arn
}
