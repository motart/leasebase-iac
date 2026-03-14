################################################################################
# Cognito Module - LeaseBase v2
# User Pool with web and mobile app clients
################################################################################

resource "aws_cognito_user_pool" "main" {
  name = "${var.name_prefix}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "tenant_id"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # Cognito schemas are immutable after creation — ignore drift to prevent
  # "cannot modify or remove schema items" errors on every apply.
  lifecycle {
    ignore_changes = [schema]
  }

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.pre_token_generation.arn
      lambda_version = "V2_0"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-users"
  })
}

# User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.name_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# Web Client
resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.name_prefix}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.web_callback_urls
  logout_urls   = var.web_logout_urls

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Mobile Client
resource "aws_cognito_user_pool_client" "mobile" {
  name         = "${var.name_prefix}-mobile"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 90 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

################################################################################
# Pre-Token Generation Lambda — injects custom:role into access tokens
################################################################################

data "archive_file" "pre_token_generation" {
  type        = "zip"
  source_file = "${path.module}/lambda/pre-token-generation/index.js"
  output_path = "${path.module}/lambda/pre-token-generation/dist/pre-token-generation.zip"
}

resource "aws_iam_role" "pre_token_generation" {
  name = "${var.name_prefix}-pre-token-gen"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "pre_token_generation_logs" {
  role       = aws_iam_role.pre_token_generation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "pre_token_generation" {
  name              = "/aws/lambda/${var.name_prefix}-pre-token-gen"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

resource "aws_lambda_function" "pre_token_generation" {
  function_name    = "${var.name_prefix}-pre-token-gen"
  description      = "Cognito Pre-Token Generation V2 — injects custom:role into access tokens"
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.pre_token_generation.output_path
  source_code_hash = data.archive_file.pre_token_generation.output_base64sha256
  role             = aws_iam_role.pre_token_generation.arn
  memory_size      = 128
  timeout          = 5

  depends_on = [aws_cloudwatch_log_group.pre_token_generation]

  tags = var.common_tags
}

resource "aws_lambda_permission" "cognito_pre_token" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_generation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# Resource Server for API scopes
resource "aws_cognito_resource_server" "api" {
  identifier   = "api"
  name         = "${var.name_prefix}-api"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "read"
    scope_description = "Read access"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access"
  }

  scope {
    scope_name        = "admin"
    scope_description = "Admin access"
  }
}
