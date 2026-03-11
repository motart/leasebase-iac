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

output "service_secret_names" {
  description = "Map of service name → Secrets Manager secret name (for CLI lookup)"
  value       = { for k, v in aws_secretsmanager_secret.service : k => v.name }
}

output "schema_names" {
  description = "Map of schema-owning service name → schema name"
  value       = { for k, v in local.schema_owning_services : k => v.schema }
}

# ── Structured outputs for scripts & docs ─────────────────────────────

output "service_db_config" {
  description = "Full resolved service DB config (consumed by run-schema-init.sh)"
  value       = var.service_db_config
}

output "db_service_names" {
  description = "Services that need DB connectivity"
  value       = keys(local.db_services)
}

output "schema_owning_service_names" {
  description = "Services that own a database schema"
  value       = keys(local.schema_owning_services)
}

output "public_schema_service_names" {
  description = "Services that use only the public schema (no owned schema)"
  value       = keys(local.public_schema_services)
}

output "proxy_auth_services" {
  description = "Services with RDS Proxy auth entries"
  value       = keys(local.proxy_auth_services)
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
