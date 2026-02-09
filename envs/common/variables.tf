variable "environment" {
  description = "Deployment environment name (dev, qa, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# Database
variable "db_name" {
  description = "Database name for the Leasebase backend."
  type        = string
  default     = "leasebase"
}

variable "db_username" {
  description = "Database master username."
  type        = string
  default     = "leasebase"
}

variable "db_password" {
  description = "Database master password. Provide via tfvars or environment, not committed to VCS."
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.0"
}

variable "db_instance_class" {
  description = "Instance class for RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GB) for RDS."
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection on RDS. Recommended true for prod."
  type        = bool
  default     = false
}

# ECS / API
variable "api_port" {
  description = "Port the API container listens on."
  type        = number
  default     = 4000
}

variable "api_healthcheck_path" {
  description = "HTTP health check path for the API load balancer."
  type        = string
  default     = "/docs"
}

variable "api_container_image" {
  description = "Container image for the Leasebase API (e.g. ECR image URI)."
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for the Fargate task."
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory (MB) for the Fargate task."
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Desired task count for the API service."
  type        = number
  default     = 1
}

############################
# Cognito
############################

variable "cognito_domain_suffix" {
  description = "Suffix for the Cognito hosted UI domain (must be globally unique)."
  type        = string
}

variable "cognito_callback_urls" {
  description = "OAuth callback URLs for the web app."
  type        = list(string)
}

variable "cognito_logout_urls" {
  description = "OAuth logout URLs for the web app."
  type        = list(string)
}

variable "cognito_advanced_security_mode" {
  description = "Advanced security mode for Cognito User Pool. Values: OFF, AUDIT, ENFORCED."
  type        = string
  default     = "OFF"
}

############################
# Document Storage
############################

variable "documents_bucket_suffix" {
  description = "Suffix for the documents S3 bucket (must be globally unique)."
  type        = string
}

variable "documents_cors_origins" {
  description = "Allowed origins for CORS on the documents bucket."
  type        = list(string)
  default     = ["*"]
}

variable "enable_s3_lifecycle" {
  description = "Whether to enable S3 lifecycle rules (can be slow to create)."
  type        = bool
  default     = false
}

############################
# Stripe
############################

variable "stripe_secret_key" {
  description = "Stripe secret API key."
  type        = string
  sensitive   = true
}

variable "stripe_publishable_key" {
  description = "Stripe publishable API key."
  type        = string
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret."
  type        = string
  sensitive   = true
}

############################
# Application Secrets
############################

variable "jwt_secret" {
  description = "Secret key for JWT signing."
  type        = string
  sensitive   = true
  default     = ""
}

variable "session_secret" {
  description = "Secret key for session encryption."
  type        = string
  sensitive   = true
  default     = ""
}

############################
# Email (SES)
############################

variable "ses_from_email" {
  description = "Verified email address for sending via SES."
  type        = string
}

############################
# Web Frontend (ECS)
############################

variable "web_container_image" {
  description = "Container image for the Leasebase web frontend."
  type        = string
}

variable "web_port" {
  description = "Port the web frontend container listens on."
  type        = number
  default     = 3000
}

variable "web_task_cpu" {
  description = "CPU units for the web Fargate task."
  type        = string
  default     = "256"
}

variable "web_task_memory" {
  description = "Memory (MB) for the web Fargate task."
  type        = string
  default     = "512"
}

variable "web_desired_count" {
  description = "Desired task count for the web service."
  type        = number
  default     = 1
}

variable "web_api_base_url" {
  description = "API base URL for the web frontend to connect to."
  type        = string
}

############################
# Application URLs
############################

variable "api_base_url" {
  description = "Public base URL for the API."
  type        = string
}

variable "web_base_url" {
  description = "Public base URL for the web frontend."
  type        = string
}

############################
# Logging
############################

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

############################
# Route 53 DNS
############################

variable "create_dns_record" {
  description = "Whether to create Route 53 DNS record for the environment subdomain."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for leasebase.co domain."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Base domain name (e.g., leasebase.co)."
  type        = string
  default     = "leasebase.co"
}

############################
# GitHub OIDC / CI-CD
############################

variable "github_org" {
  description = "GitHub organization name."
  type        = string
  default     = "leasebase-io"
}

variable "github_repo_api" {
  description = "GitHub repository name for the API."
  type        = string
  default     = "leasebase"
}

variable "github_repo_web" {
  description = "GitHub repository name for the web frontend."
  type        = string
  default     = "leasebase-web"
}

variable "github_branch_pattern" {
  description = "Branch pattern allowed for deployments (supports wildcards)."
  type        = string
  default     = "*"
}
