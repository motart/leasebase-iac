variable "aws_region" {
  description = "AWS region for the UAT account."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR for UAT."
  type        = string
  default     = "10.30.0.0/16"
}

# Database
variable "db_name" {
  description = "Database name for UAT."
  type        = string
  default     = "leasebase_uat"
}

variable "db_username" {
  description = "Database username for UAT."
  type        = string
  default     = "leasebase"
}

variable "db_password" {
  description = "Database password for UAT (set via tfvars, do not commit real values)."
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "Postgres engine version for UAT."
  type        = string
  default     = "16.0"
}

variable "db_instance_class" {
  description = "RDS instance class for UAT."
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS storage (GB) for UAT."
  type        = number
  default     = 50
}

variable "db_deletion_protection" {
  description = "Enable deletion protection (usually true for UAT)."
  type        = bool
  default     = true
}

# API / ECS
variable "api_port" {
  description = "API port for UAT."
  type        = number
  default     = 4000
}

variable "api_healthcheck_path" {
  description = "Health check path for UAT API."
  type        = string
  default     = "/docs"
}

variable "api_container_image" {
  description = "ECR image URI (or other registry) for UAT API."
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU units for UAT API task."
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory for UAT API task."
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Number of UAT API tasks."
  type        = number
  default     = 2
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
  default     = "AUDIT"
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
  description = "Container image for the UAT web frontend."
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
  description = "Desired task count for the UAT web service."
  type        = number
  default     = 2
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
  description = "Whether to create Route 53 DNS record for UAT subdomain."
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for leasebase.co domain."
  type        = string
  default     = "Z0031483TCJQERT4KG16"
}

variable "domain_name" {
  description = "Base domain name."
  type        = string
  default     = "leasebase.co"
}
