################################################################################
# Outputs
################################################################################

output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "proxy_endpoint" {
  description = "RDS Proxy endpoint (services should connect here)"
  value       = aws_db_proxy.main.endpoint
}

output "cluster_port" {
  description = "Database port"
  value       = aws_rds_cluster.main.port
}

output "database_name" {
  description = "Default database name"
  value       = aws_rds_cluster.main.database_name
}

output "master_secret_arn" {
  description = "Secrets Manager ARN for master credentials"
  value       = aws_secretsmanager_secret.master.arn
}

output "service_secret_arns" {
  description = "Map of service name → Secrets Manager ARN"
  value       = { for k, v in aws_secretsmanager_secret.service : k => v.arn }
}

output "schema_names" {
  description = "Map of service name → schema name"
  value       = var.service_schemas
}

output "db_security_group_id" {
  description = "Database security group ID"
  value       = aws_security_group.db.id
}

output "proxy_security_group_id" {
  description = "RDS Proxy security group ID"
  value       = aws_security_group.proxy.id
}

output "cluster_identifier" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.main.cluster_identifier
}
