################################################################################
# Database Platform Module — Variables
################################################################################

variable "name_prefix" {
  description = "Prefix for all resource names (e.g. leasebase-dev-v2)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for DB subnet group"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "Security group IDs of ECS services allowed to connect"
  type        = list(string)
  default     = []
}

variable "kms_key_id" {
  description = "KMS key ID for encryption at rest"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for Secrets Manager encryption"
  type        = string
}

# ── Aurora ───────────────────────────────────────────────────────────────────

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "master_username" {
  description = "Master database username"
  type        = string
  default     = "leasebase_admin"
}

variable "database_name" {
  description = "Default database name"
  type        = string
  default     = "leasebase"
}

variable "instance_count" {
  description = "Number of Aurora cluster instances (>=2 for Multi-AZ)"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 8
}

variable "backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on delete"
  type        = bool
  default     = true
}

# ── Service schemas ──────────────────────────────────────────────────────────

variable "service_schemas" {
  description = "Map of service name → schema name for per-service isolation"
  type        = map(string)
  default = {
    property     = "property_service"
    lease        = "lease_service"
    tenant       = "tenant_service"
    maintenance  = "maintenance_service"
    payments     = "payments_service"
    notification = "notification_service"
    document     = "document_service"
    reporting    = "reporting_service"
  }
}

# ── Alarms ───────────────────────────────────────────────────────────────────

variable "alarm_cpu_threshold" {
  description = "CPU alarm threshold (percent)"
  type        = number
  default     = 80
}

variable "alarm_connections_threshold" {
  description = "Database connections alarm threshold"
  type        = number
  default     = 100
}

variable "alarm_free_storage_threshold" {
  description = "Free local storage alarm threshold (bytes)"
  type        = number
  default     = 5368709120 # 5 GB
}

variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications (empty = no notifications)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
