################################################################################
# CloudWatch Logs
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}-jira-webhook"
  retention_in_days = var.retention_days
  tags              = var.common_tags
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.name_prefix}-webhook-api"
  retention_in_days = var.retention_days
  tags              = var.common_tags
}
