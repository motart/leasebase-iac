variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "webhook_secret" {
  description = "Shared secret for Jira webhook header validation"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub PAT for dispatching Actions workflows"
  type        = string
  sensitive   = true
}
