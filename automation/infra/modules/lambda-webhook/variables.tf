variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to compiled Lambda source directory"
  type        = string
}

variable "apigw_execution_arn" {
  description = "API Gateway execution ARN for Lambda permission"
  type        = string
}

variable "webhook_secret_name" {
  description = "Secrets Manager name for webhook shared secret"
  type        = string
}

variable "github_token_secret_name" {
  description = "Secrets Manager name for GitHub token"
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the repos"
  type        = string
  default     = "motart"
}

variable "log_level" {
  description = "Lambda log level"
  type        = string
  default     = "info"
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
