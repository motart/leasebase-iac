variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda function invoke ARN"
  type        = string
}

variable "access_log_group_arn" {
  description = "CloudWatch log group ARN for API GW access logs"
  type        = string
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
