output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.main.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.main.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.main.name
}

output "target_group_arn" {
  description = "Target group ARN (empty when register_with_alb is false)"
  value       = var.register_with_alb ? aws_lb_target_group.main[0].arn : ""
}

output "task_role_arn" {
  description = "Task role ARN"
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Task role name"
  value       = aws_iam_role.task.name
}

output "security_group_id" {
  description = "Service security group ID"
  value       = aws_security_group.service.id
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.main.name
}
