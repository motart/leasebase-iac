variable "aws_region" {
  description = "AWS region for the dev account."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR for dev."
  type        = string
  default     = "10.10.0.0/16"
}

# Database
variable "db_name" {
  description = "Database name for dev."
  type        = string
  default     = "leasebase_dev"
}

variable "db_username" {
  description = "Database username for dev."
  type        = string
  default     = "leasebase"
}

variable "db_password" {
  description = "Database password for dev (set via tfvars, do not commit real values)."
  type        = string
  sensitive   = true
}

variable "db_engine_version" {
  description = "Postgres engine version for dev."
  type        = string
  default     = "16.0"
}

variable "db_instance_class" {
  description = "RDS instance class for dev."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage (GB) for dev."
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Enable deletion protection (usually false for dev)."
  type        = bool
  default     = false
}

# API / ECS
variable "api_port" {
  description = "API port for dev."
  type        = number
  default     = 4000
}

variable "api_healthcheck_path" {
  description = "Health check path for dev API."
  type        = string
  default     = "/docs"
}

variable "api_container_image" {
  description = "ECR image URI (or other registry) for dev API."
  type        = string
}

variable "api_database_url" {
  description = "DATABASE_URL for dev API container."
  type        = string
  sensitive   = true
}

variable "ecs_task_cpu" {
  description = "CPU units for dev API task."
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "Memory for dev API task."
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Number of dev API tasks."
  type        = number
  default     = 1
}

# Web
variable "web_bucket_suffix" {
  description = "Unique suffix for dev web S3 bucket (e.g. dev-<account-id>)."
  type        = string
}

variable "web_index_document" {
  description = "Index document for dev web site."
  type        = string
  default     = "index.html"
}

variable "web_error_document" {
  description = "Error document for dev web site."
  type        = string
  default     = "index.html"
}
