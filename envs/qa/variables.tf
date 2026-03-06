################################################################################
# QA Environment Variables
################################################################################

variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.120.0.0/16"
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

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "cloudfront_acm_certificate_arn" {
  type    = string
  default = ""
}

variable "domain_name" {
  description = "Custom domain for the web frontend (e.g. qa.leasebase.co)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 14
}

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
  default = 8
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

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

variable "sqs_queues" {
  type = map(map(any))
  default = {
    notifications       = {}
    document-processing = { visibility_timeout = 600 }
    reporting-jobs      = { visibility_timeout = 900 }
  }
}
