variable "name" {
  description = "Service name (e.g. bff-gateway, lease-service)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ALB listener ARN for target group registration"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID (for ingress rules)"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 4
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "path_patterns" {
  description = "ALB path patterns for routing"
  type        = list(string)
}

variable "priority" {
  description = "ALB listener rule priority"
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "secrets" {
  description = "Secrets to inject as env vars (from Secrets Manager / SSM)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "extra_environment" {
  description = "Additional environment variables to inject into the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "extra_iam_statements" {
  description = "Additional IAM policy statements for the task role"
  type = list(object({
    Sid      = string
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

variable "ecr_force_delete" {
  description = "Force delete ECR repo (for non-prod)"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "additional_target_group_arns" {
  description = "Additional target group ARNs for the ECS service (e.g. public web ALB)"
  type        = list(string)
  default     = []
}

variable "register_with_alb" {
  description = "Create a target group and listener rule on the internal ALB. Set false for services that only use an external ALB (e.g. web)."
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "Docker image tag to deploy (immutable Git SHA). CI passes the commit SHA; Terraform uses it for the seed task definition."
  type        = string
  default     = "latest"
}

