variable "aws_region" {
  description = "AWS region for the QA account."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR for QA."
  type        = string
  default     = "10.20.0.0/16"
}

# Database
variable "db_name" {
  description = "Database name for QA."
  type        = string
  default     = "leasebase_qa"
}

variable "db_username" {
  description = "Database username for QA."
  type        = string
  default     = "leasebase"
}

variable "db_password" {
  description = "Database password for QA (set via tfvars, do not commit real values)."
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "Postgres engine version for QA."
  type        = string
  default     = "16.0"
}

variable "db_instance_class" {
  description = "RDS instance class for QA."
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS storage (GB) for QA."
  type        = number
  default     = 50
}

variable "db_deletion_protection" {
  description = "Enable deletion protection (usually true for QA)."
  type        = bool
  default     = true
}

# API / ECS
variable "api_port" {
  description = "API port for QA."
  type        = number
  default     = 4000
}

variable "api_healthcheck_path" {
  description = "Health check path for QA API."
  type        = string
  default     = "/docs"
}

variable "api_container_image" {
  description = "ECR image URI (or other registry) for QA API."
  type        = string
}

variable "api_database_url" {
  description = "DATABASE_URL for QA API container."
  type        = string
  sensitive   = true
}

variable "ecs_task_cpu" {
  description = "CPU units for QA API task."
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory for QA API task."
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Number of QA API tasks."
  type        = number
  default     = 2
}

# Web
variable "web_bucket_suffix" {
  description = "Unique suffix for QA web S3 bucket (e.g. qa-<account-id>)."
  type        = string
}

variable "web_index_document" {
  description = "Index document for QA web site."
  type        = string
  default     = "index.html"
}

variable "web_error_document" {
  description = "Error document for QA web site."
  type        = string
  default     = "index.html"
}
