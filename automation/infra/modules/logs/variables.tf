variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 14
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
