################################################################################
# Lambda — Jira Webhook Handler
################################################################################

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/dist/lambda.zip"
}

resource "aws_lambda_function" "webhook" {
  function_name    = "${var.name_prefix}-jira-webhook"
  description      = "Processes Jira webhooks and dispatches GitHub Actions workflows"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      WEBHOOK_SECRET_NAME = var.webhook_secret_name
      GH_TOKEN_SECRET_NAME = var.github_token_secret_name
      GITHUB_OWNER        = var.github_owner
      LOG_LEVEL           = var.log_level
    }
  }

  tags = var.common_tags
}

# Allow API Gateway to invoke this Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.apigw_execution_arn}/*/*"
}
