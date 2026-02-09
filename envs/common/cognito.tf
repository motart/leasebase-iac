############################
# Cognito User Pool
############################

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-users"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration (use Cognito default for simplicity, can switch to SES)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Verification message template so users know Leasebase is requesting verification
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Verify your email for Leasebase"
    email_message        = <<EOT
Welcome to Leasebase!

Your email address was used to create an account in the Leasebase web application.

Your Leasebase verification code is: {####}

Enter this code in the Leasebase app to finish setting up your account.

If you did not request this, you can safely ignore this email.
EOT
  }

  # Schema attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "orgId"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "role"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # MFA configuration (optional, off by default)
  mfa_configuration = "OFF"

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = var.cognito_advanced_security_mode
  }

  tags = {
    Name        = "${local.name_prefix}-users"
    Environment = var.environment
    Project     = "leasebase"
  }
}

############################
# Cognito User Pool Domain
############################

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-${var.cognito_domain_suffix}"
  user_pool_id = aws_cognito_user_pool.main.id
}

############################
# Cognito App Client (Web SPA)
############################

resource "aws_cognito_user_pool_client" "web" {
  name         = "${local.name_prefix}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret for SPA
  generate_secret = false

  # Token validity
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # OAuth configuration
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Callback URLs
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  # Read/write attributes
  read_attributes = [
    "email",
    "email_verified",
    "given_name",
    "family_name",
    "custom:orgId",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "given_name",
    "family_name",
    "custom:orgId",
    "custom:role"
  ]
}

############################
# Cognito App Client (API - for backend token validation)
############################

resource "aws_cognito_user_pool_client" "api" {
  name         = "${local.name_prefix}-api-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # API client with secret for server-side operations
  generate_secret = true

  # Token validity
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Explicit auth flows for backend
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"
}
