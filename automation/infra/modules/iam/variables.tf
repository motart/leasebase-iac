variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "log_group_arn" {
  description = "CloudWatch log group ARN the Lambda can write to"
  type        = string
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs the Lambda can read"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
