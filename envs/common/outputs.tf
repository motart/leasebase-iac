output "vpc_id" {
  description = "ID of the Leasebase VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (hostname:port)."
  value       = aws_db_instance.this.endpoint
}

############################
# ECR
############################

output "ecr_api_repository_url" {
  description = "ECR repository URL for the API."
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_web_repository_url" {
  description = "ECR repository URL for the web frontend."
  value       = aws_ecr_repository.web.repository_url
}

############################
# Cognito
############################

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN."
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_web_client_id" {
  description = "Cognito App Client ID for the web SPA."
  value       = aws_cognito_user_pool_client.web.id
}

output "cognito_api_client_id" {
  description = "Cognito App Client ID for the API."
  value       = aws_cognito_user_pool_client.api.id
}

output "cognito_domain" {
  description = "Cognito Hosted UI domain."
  value       = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

############################
# S3
############################

output "documents_bucket_name" {
  description = "S3 bucket name for document storage."
  value       = aws_s3_bucket.documents.bucket
}

output "documents_bucket_arn" {
  description = "S3 bucket ARN for document storage."
  value       = aws_s3_bucket.documents.arn
}

############################
# ALB & ECS
############################

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = aws_lb.api.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB (for alias records)."
  value       = aws_lb.api.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.api.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.api.arn
}

output "api_service_name" {
  description = "Name of the ECS service for the API."
  value       = aws_ecs_service.api.name
}

output "web_service_name" {
  description = "Name of the ECS service for the web frontend."
  value       = aws_ecs_service.web.name
}

output "api_task_definition_arn" {
  description = "ARN of the API task definition."
  value       = aws_ecs_task_definition.api.arn
}

output "api_migrate_task_definition_arn" {
  description = "ARN of the API migration task definition."
  value       = aws_ecs_task_definition.api_migrate.arn
}

output "web_task_definition_arn" {
  description = "ARN of the web task definition."
  value       = aws_ecs_task_definition.web.arn
}

############################
# Security Groups
############################

output "ecs_security_group_id" {
  description = "Security group ID for ECS API service."
  value       = aws_security_group.ecs_service.id
}

output "ecs_web_security_group_id" {
  description = "Security group ID for ECS web service."
  value       = aws_security_group.ecs_web.id
}

############################
# Secrets Manager
############################

output "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "stripe_secret_arn" {
  description = "ARN of the Stripe API keys secret."
  value       = aws_secretsmanager_secret.stripe.arn
}

output "app_secrets_arn" {
  description = "ARN of the application secrets."
  value       = aws_secretsmanager_secret.app_secrets.arn
}

############################
# Route 53
############################

output "subdomain_fqdn" {
  description = "Fully qualified domain name for the environment subdomain."
  value       = var.create_dns_record ? "${var.environment}.${var.domain_name}" : ""
}

output "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS."
  value       = var.create_dns_record ? aws_acm_certificate.subdomain[0].arn : ""
}
