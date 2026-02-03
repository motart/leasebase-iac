output "vpc_id" {
  description = "ID of the Leasebase VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (hostname:port)."
  value       = aws_db_instance.this.endpoint
}

output "api_alb_dns_name" {
  description = "DNS name of the API application load balancer."
  value       = aws_lb.api.dns_name
}

output "api_cluster_name" {
  description = "Name of the ECS cluster running the API."
  value       = aws_ecs_cluster.api.name
}

output "api_service_name" {
  description = "Name of the ECS service for the API."
  value       = aws_ecs_service.api.name
}

output "web_bucket_name" {
  description = "S3 bucket name for the web client."
  value       = aws_s3_bucket.web.bucket
}

output "web_cloudfront_domain" {
  description = "CloudFront domain name serving the web frontend."
  value       = aws_cloudfront_distribution.web.domain_name
}
