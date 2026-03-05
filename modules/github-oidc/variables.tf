variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repos in 'org/repo' format allowed to assume this role"
  type        = list(string)
}

variable "allowed_branch" {
  description = "Branch allowed to assume the role (e.g. 'develop', 'main')"
  type        = string
  default     = "develop"
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider (set false if it already exists in the account)"
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "ARN of an existing OIDC provider (used when create_oidc_provider = false)"
  type        = string
  default     = ""
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the role can push to"
  type        = list(string)
}

variable "ecs_role_arns" {
  description = "List of IAM role ARNs the role can pass to ECS (execution + task roles)"
  type        = list(string)
}

variable "cloudfront_distribution_arns" {
  description = "CloudFront distribution ARNs the role can create invalidations for"
  type        = list(string)
  default     = []
}

variable "allow_logs_access" {
  description = "Whether to allow CloudWatch Logs read access"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
