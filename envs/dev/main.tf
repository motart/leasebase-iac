terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # For dev account, set AWS_PROFILE or environment variables before running terraform.
}

module "leasebase" {
  source = "../common"

  environment       = "dev"
  aws_region        = var.aws_region
  vpc_cidr          = var.vpc_cidr

  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  db_engine_version     = var.db_engine_version
  db_instance_class     = var.db_instance_class
  db_allocated_storage  = var.db_allocated_storage
  db_deletion_protection = var.db_deletion_protection

  api_port             = var.api_port
  api_healthcheck_path = var.api_healthcheck_path
  api_container_image  = var.api_container_image
  api_database_url     = var.api_database_url
  ecs_task_cpu         = var.ecs_task_cpu
  ecs_task_memory      = var.ecs_task_memory
  ecs_desired_count    = var.ecs_desired_count

  web_bucket_suffix   = var.web_bucket_suffix
  web_index_document  = var.web_index_document
  web_error_document  = var.web_error_document
}

output "api_alb_dns_name" {
  value       = module.leasebase.api_alb_dns_name
  description = "Dev API ALB DNS name"
}

output "web_cloudfront_domain" {
  value       = module.leasebase.web_cloudfront_domain
  description = "Dev web CloudFront domain"
}
