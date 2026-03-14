variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "web_callback_urls" {
  description = "Callback URLs for web client"
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}

variable "web_logout_urls" {
  description = "Logout URLs for web client"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for the pre-token Lambda"
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
