variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC Link"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener to integrate with"
  type        = string
}

variable "cors_allow_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ── Custom domain ────────────────────────────────────────────────────────────

variable "custom_domain_name" {
  description = "Custom domain name for API Gateway (e.g. api.dev.leasebase.co). Empty to skip."
  type        = string
  default     = ""
}

variable "custom_domain_certificate_arn" {
  description = "ACM certificate ARN for the custom domain (must be in the same region as the API)."
  type        = string
  default     = ""
}

variable "custom_domain_zone_id" {
  description = "Route53 hosted zone ID for the custom domain DNS record."
  type        = string
  default     = ""
}
