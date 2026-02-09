variable "aws_region" {
  description = "AWS region for the production account."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR for production."
  type        = string
  default     = "10.30.0.0/16"
}

# Database
variable "db_name" {
  description = "Database name for production."
  type        = string
  default     = "leasebase_prod"
}

variable "db_username" {
  description = "Database username for production."
  type        = string
  default     = "leasebase"
}

variable "db_password" {
  description = "Database password for production (set via tfvars, do not commit real values)."
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "Postgres engine version for production."
  type        = string
  default     = "16.0"
}

variable "db_instance_class" {
  description = "RDS instance class for production."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS storage (GB) for production."
  type        = number
  default     = 100
}

variable "db_deletion_protection" {
  description = "Enable deletion protection (should be true for production)."
  type        = bool
  default     = true
}

# API / ECS
variable "api_port" {
  description = "API port for production."
  type        = number
  default     = 4000
}

variable "api_healthcheck_path" {
  description = "Health check path for production API."
  type        = string
  default     = "/docs"
}

variable "api_container_image" {
  description = "ECR image URI (or other registry) for production API."
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for production API task."
  type        = string
  default     = "1024"
}

variable "ecs_task_memory" {
  description = "Memory for production API task."
  type        = string
  default     = "2048"
}

variable "ecs_desired_count" {
  description = "Number of production API tasks."
  type        = number
  default     = 3
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
  description = "Advanced security mode for Cognito. Values: OFF, AUDIT, ENFORCED."
  type        = string
  default     = "ENFORCED"
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
  description = "Container image for the production web frontend."
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
  default     = "512"
}

variable "web_task_memory" {
  description = "Memory (MB) for the web Fargate task."
  type        = string
  default     = "1024"
}

variable "web_desired_count" {
  description = "Desired task count for the production web service."
  type        = number
  default     = 3
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
  default     = 90
}
