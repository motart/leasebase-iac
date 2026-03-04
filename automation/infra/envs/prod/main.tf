################################################################################
# LeaseBase Automation — Prod Environment
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure for remote state:
  # backend "s3" {
  #   bucket         = "leasebase-terraform-state"
  #   key            = "automation/prod/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "leasebase-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "prod"
  name_prefix = "leasebase-automation-${local.environment}"
  common_tags = {
    App       = "LeaseBase"
    Stack     = "automation"
    Env       = local.environment
    Owner     = "motart"
    ManagedBy = "Terraform"
  }

  lambda_dist_dir = "${path.module}/../../../lambda/dist"
}

################################################################################
# CloudWatch Logs
################################################################################

module "logs" {
  source         = "../../modules/logs"
  name_prefix    = local.name_prefix
  retention_days = 30
  common_tags    = local.common_tags
}

################################################################################
# Secrets Manager
################################################################################

module "secrets" {
  source               = "../../modules/secrets"
  name_prefix          = local.name_prefix
  webhook_secret_value = var.webhook_secret
  github_token_value   = var.github_token
  common_tags          = local.common_tags
}

################################################################################
# IAM
################################################################################

module "iam" {
  source        = "../../modules/iam"
  name_prefix   = local.name_prefix
  log_group_arn = module.logs.lambda_log_group_arn
  secret_arns = [
    module.secrets.webhook_secret_arn,
    module.secrets.github_token_secret_arn,
  ]
  common_tags = local.common_tags
}

################################################################################
# Lambda
################################################################################

module "lambda" {
  source                   = "../../modules/lambda-webhook"
  name_prefix              = local.name_prefix
  lambda_role_arn          = module.iam.lambda_role_arn
  lambda_source_dir        = local.lambda_dist_dir
  apigw_execution_arn      = module.apigw.execution_arn
  webhook_secret_name      = module.secrets.webhook_secret_name
  github_token_secret_name = module.secrets.github_token_secret_name
  github_owner             = "motart"
  log_level                = "info"
  common_tags              = local.common_tags
}

################################################################################
# API Gateway
################################################################################

module "apigw" {
  source               = "../../modules/apigw-http"
  name_prefix          = local.name_prefix
  lambda_invoke_arn    = module.lambda.invoke_arn
  access_log_group_arn = module.logs.apigw_log_group_arn
  common_tags          = local.common_tags
}
