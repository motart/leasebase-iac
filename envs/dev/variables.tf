################################################################################
# Dev Environment Variables
################################################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# VPC
variable "vpc_cidr" {
  type    = string
  default = "10.110.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "enable_vpc_endpoints" {
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  type    = bool
  default = false
}

# ALB / TLS
variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM cert ARN in us-east-1 for CloudFront"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Custom domain for CloudFront (e.g. dev.leasebase.co)"
  type        = string
  default     = ""
}

variable "root_domain_name" {
  description = "Root domain for Route53 hosted zone lookup (e.g. leasebase.co)"
  type        = string
  default     = "leasebase.co"
}

# ECS
variable "log_retention_days" {
  type    = number
  default = 7
}

# RDS Aurora
variable "db_name" {
  type    = string
  default = "leasebase"
}

variable "aurora_min_capacity" {
  type    = number
  default = 0.5
}

variable "aurora_max_capacity" {
  type    = number
  default = 4
}

# Redis
variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

# Feature flags
variable "enable_opensearch" {
  type    = bool
  default = false
}

variable "enable_waf" {
  type    = bool
  default = false
}

variable "enable_lambda_workers" {
  type    = bool
  default = false
}

# SQS
variable "sqs_queues" {
  type = map(map(any))
  default = {
    notifications       = {}
    document-processing = { visibility_timeout = 600 }
    reporting-jobs      = { visibility_timeout = 900 }
  }
}

# GitHub OIDC
variable "github_oidc_repositories" {
  description = "GitHub repos allowed to assume the CI/CD role (format: org/repo)"
  type        = list(string)
  default     = ["motart/leasebase_all"]  # TODO: update if repo name differs
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider (set false if already exists in account)"
  type        = bool
  default     = true
}
