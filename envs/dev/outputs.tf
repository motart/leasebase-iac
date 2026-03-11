################################################################################
# Dev Environment Outputs
################################################################################

# Networking
output "vpc_id" {
  value = module.vpc.vpc_id
}

# ALB
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

# API Gateway
output "api_endpoint" {
  value = module.apigw.api_endpoint
}

# CloudFront (only when enabled)
output "cloudfront_domain" {
  value = var.enable_cloudfront ? module.cloudfront[0].distribution_domain_name : ""
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation in deploy scripts)"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_id : ""
}

# Cognito
output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_web_client_id" {
  value = module.cognito.web_client_id
}

output "cognito_mobile_client_id" {
  value = module.cognito.mobile_client_id
}

# Database (private)
output "db_endpoint" {
  value     = module.database_platform.proxy_endpoint
  sensitive = true
}

output "db_secret_arn" {
  value = module.database_platform.master_secret_arn
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint (for scripts)"
  value       = module.database_platform.proxy_endpoint
  sensitive   = true
}

output "service_secret_names" {
  description = "Map of service → Secrets Manager secret name"
  value       = module.database_platform.service_secret_names
}

output "service_db_config" {
  description = "Full service DB config (for run-schema-init.sh)"
  value       = module.database_platform.service_db_config
}

output "db_service_names" {
  description = "Services that need DB connectivity"
  value       = module.database_platform.db_service_names
}

output "schema_owning_service_names" {
  description = "Services that own a schema"
  value       = module.database_platform.schema_owning_service_names
}

# Redis
output "redis_endpoint" {
  value     = module.redis.primary_endpoint
  sensitive = true
}

# S3
output "documents_bucket" {
  value = module.s3_docs.bucket_name
}

# ECS
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

# ECR URLs (per service)
output "ecr_repository_urls" {
  value = { for k, v in module.services : k => v.ecr_repository_url }
}

# API Gateway custom domain
output "api_custom_domain" {
  description = "API Gateway custom domain (e.g. api.dev.leasebase.co)"
  value       = module.apigw.custom_domain_target
}

# EventBridge
output "event_bus_name" {
  value = module.eventbridge.event_bus_name
}

# SQS
output "sqs_queue_urls" {
  value = module.sqs.queue_urls
}

# GitHub Actions OIDC
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions. Set as AWS_ROLE_ARN repo variable."
  value       = module.github_oidc.role_arn
}
