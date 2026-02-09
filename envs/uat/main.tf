terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # For UAT account, set AWS_PROFILE or env vars before running terraform.
}

module "leasebase" {
  source = "../common"

  environment = "uat"
  aws_region  = var.aws_region
  vpc_cidr    = var.vpc_cidr

  # Database
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  db_engine_version      = var.db_engine_version
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_deletion_protection = var.db_deletion_protection

  # API / ECS
  api_port             = var.api_port
  api_healthcheck_path = var.api_healthcheck_path
  api_container_image  = var.api_container_image
  ecs_task_cpu         = var.ecs_task_cpu
  ecs_task_memory      = var.ecs_task_memory
  ecs_desired_count    = var.ecs_desired_count

  # Cognito
  cognito_domain_suffix          = var.cognito_domain_suffix
  cognito_callback_urls          = var.cognito_callback_urls
  cognito_logout_urls            = var.cognito_logout_urls
  cognito_advanced_security_mode = var.cognito_advanced_security_mode

  # Document Storage
  documents_bucket_suffix = var.documents_bucket_suffix
  documents_cors_origins  = var.documents_cors_origins

  # Stripe
  stripe_secret_key      = var.stripe_secret_key
  stripe_publishable_key = var.stripe_publishable_key
  stripe_webhook_secret  = var.stripe_webhook_secret

  # Application Secrets
  jwt_secret     = var.jwt_secret
  session_secret = var.session_secret

  # Email (SES)
  ses_from_email = var.ses_from_email

  # Web Frontend
  web_container_image = var.web_container_image
  web_port            = var.web_port
  web_task_cpu        = var.web_task_cpu
  web_task_memory     = var.web_task_memory
  web_desired_count   = var.web_desired_count
  web_api_base_url    = var.web_api_base_url

  # Application URLs
  api_base_url = var.api_base_url
  web_base_url = var.web_base_url

  # Logging
  log_retention_days = var.log_retention_days

  # Route 53 DNS
  create_dns_record = var.create_dns_record
  route53_zone_id   = var.route53_zone_id
  domain_name       = var.domain_name
}

############################
# Outputs
############################

output "alb_dns_name" {
  value       = module.leasebase.alb_dns_name
  description = "UAT ALB DNS name"
}

output "ecr_api_repository_url" {
  value       = module.leasebase.ecr_api_repository_url
  description = "UAT API ECR repository URL"
}

output "ecr_web_repository_url" {
  value       = module.leasebase.ecr_web_repository_url
  description = "UAT web ECR repository URL"
}

output "cognito_user_pool_id" {
  value       = module.leasebase.cognito_user_pool_id
  description = "UAT Cognito User Pool ID"
}

output "cognito_web_client_id" {
  value       = module.leasebase.cognito_web_client_id
  description = "UAT Cognito web client ID"
}

output "cognito_domain" {
  value       = module.leasebase.cognito_domain
  description = "UAT Cognito domain"
}

output "documents_bucket_name" {
  value       = module.leasebase.documents_bucket_name
  description = "UAT documents S3 bucket name"
}

output "ecs_cluster_name" {
  value       = module.leasebase.ecs_cluster_name
  description = "UAT ECS cluster name"
}

output "api_migrate_task_definition_arn" {
  value       = module.leasebase.api_migrate_task_definition_arn
  description = "UAT API migration task definition ARN"
}

output "vpc_id" {
  value       = module.leasebase.vpc_id
  description = "UAT VPC ID"
}

output "public_subnet_ids" {
  value       = module.leasebase.public_subnet_ids
  description = "UAT public subnet IDs"
}

output "ecs_security_group_id" {
  value       = module.leasebase.ecs_security_group_id
  description = "UAT ECS security group ID"
}

output "api_service_name" {
  value       = module.leasebase.api_service_name
  description = "UAT API ECS service name"
}

output "web_service_name" {
  value       = module.leasebase.web_service_name
  description = "UAT web ECS service name"
}

output "subdomain_fqdn" {
  value       = module.leasebase.subdomain_fqdn
  description = "UAT subdomain FQDN"
}
