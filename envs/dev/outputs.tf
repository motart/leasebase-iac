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

# CloudFront
output "cloudfront_domain" {
  value = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation in deploy scripts)"
  value       = module.cloudfront.distribution_id
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
