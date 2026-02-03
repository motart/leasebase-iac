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

variable "api_database_url" {
  description = "DATABASE_URL value injected into the API container. Typically points at the RDS instance."
  type        = string
  sensitive   = true
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

# Web client
variable "web_bucket_suffix" {
  description = "Suffix to make the web S3 bucket globally unique (e.g. account or random string)."
  type        = string
}

variable "web_index_document" {
  description = "Index document for the static site."
  type        = string
  default     = "index.html"
}

variable "web_error_document" {
  description = "Error document for the static site."
  type        = string
  default     = "index.html"
}
