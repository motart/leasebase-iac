variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "webhook_secret_value" {
  description = "Shared secret for Jira webhook validation"
  type        = string
  sensitive   = true
}

variable "github_token_value" {
  description = "GitHub PAT for dispatching Actions workflows"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
