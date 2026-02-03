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

variable "api_database_url" {
  description = "DATABASE_URL for production API container."
  type        = string
  sensitive   = true
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

# Web
variable "web_bucket_suffix" {
  description = "Unique suffix for production web S3 bucket (e.g. prod-<account-id>)."
  type        = string
}

variable "web_index_document" {
  description = "Index document for production web site."
  type        = string
  default     = "index.html"
}

variable "web_error_document" {
  description = "Error document for production web site."
  type        = string
  default     = "index.html"
}
