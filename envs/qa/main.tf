################################################################################
# Dev Environment - LeaseBase v2
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  environment = "qa"
  name_prefix = "leasebase-${local.environment}-v2"
  common_tags = {
    App       = "LeaseBase"
    Env       = local.environment
    Stack     = "v2"
    Owner     = "motart"
    ManagedBy = "Terraform"
  }

  # ── BFF gateway needs ALB URL to proxy to backend services ────────────────
  bff_gateway_extra_env = [
    { name = "INTERNAL_ALB_URL", value = "http://${module.alb.alb_dns_name}" },
    { name = "USE_ALB", value = "true" },
    { name = "CORS_ORIGIN", value = var.domain_name != "" ? "https://${var.domain_name}" : "http://localhost:3000" },
  ]

  services = {
    bff-gateway = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/api/*", "/health"]
      priority          = 100
    }
    auth-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/auth/*"]
      priority          = 110
    }
    lease-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/leases/*"]
      priority          = 120
    }
    property-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/properties/*"]
      priority          = 130
    }
    tenant-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/tenants/*"]
      priority          = 140
    }
    maintenance-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/maintenance/*"]
      priority          = 150
    }
    payments-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/payments/*"]
      priority          = 160
    }
    notification-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/notifications/*"]
      priority          = 170
    }
    document-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/documents/*"]
      priority          = 180
    }
    reporting-service = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/health"
      path_patterns     = ["/internal/reports/*"]
      priority          = 190
    }
  }
}

################################################################################
# KMS
################################################################################

module "kms" {
  source      = "../../modules/kms"
  environment = local.environment
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source               = "../../modules/vpc"
  environment          = local.environment
  name_prefix          = local.name_prefix
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  az_count             = var.az_count
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints
  enable_flow_logs     = var.enable_flow_logs
  common_tags          = local.common_tags
}

################################################################################
# ALB (internal, for VPC Link)
################################################################################

module "alb" {
  source          = "../../modules/alb"
  name_prefix     = local.name_prefix
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.private_subnet_ids
  internal        = true
  certificate_arn = var.acm_certificate_arn
  common_tags     = local.common_tags
}

################################################################################
# API Gateway
################################################################################

module "apigw" {
  source           = "../../modules/apigw"
  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids
  alb_listener_arn = module.alb.listener_arn
  common_tags      = local.common_tags
}

################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 1
  }
}

################################################################################
# ECS Execution Role (shared)
################################################################################

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_extras" {
  name = "extras"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "kms:Decrypt"
      ]
      Resource = "*"
    }]
  })
}

################################################################################
# ECS Services (10 microservices via for_each)
################################################################################

module "services" {
  source   = "../../modules/ecs-service"
  for_each = local.services

  name                  = each.key
  environment           = local.environment
  name_prefix           = local.name_prefix
  aws_region            = var.aws_region
  cluster_id            = aws_ecs_cluster.main.id
  cluster_name          = aws_ecs_cluster.main.name
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  alb_listener_arn      = module.alb.listener_arn
  alb_security_group_id = module.alb.security_group_id
  container_port        = each.value.port
  cpu                   = each.value.cpu
  memory                = each.value.memory
  desired_count         = each.value.desired_count
  health_check_path     = each.value.health_check_path
  path_patterns         = each.value.path_patterns
  priority              = each.value.priority
  log_retention_days    = var.log_retention_days
  execution_role_arn    = aws_iam_role.ecs_execution.arn
  ecr_force_delete      = true
  extra_environment     = each.key == "bff-gateway" ? local.bff_gateway_extra_env : []
  common_tags           = local.common_tags
}

################################################################################
# RDS Aurora Serverless v2
################################################################################

module "rds" {
  source                     = "../../modules/rds-aurora"
  environment                = local.environment
  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [for s in module.services : s.security_group_id]
  kms_key_id                 = module.kms.key_id
  db_name                    = var.db_name
  min_capacity               = var.aurora_min_capacity
  max_capacity               = var.aurora_max_capacity
  deletion_protection        = false
  skip_final_snapshot        = true
  common_tags                = local.common_tags
}

################################################################################
# Redis
################################################################################

module "redis" {
  source                     = "../../modules/redis"
  environment                = local.environment
  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [for s in module.services : s.security_group_id]
  node_type                  = var.redis_node_type
  common_tags                = local.common_tags
}

################################################################################
# OpenSearch (optional - disabled by default)
################################################################################

module "opensearch" {
  source      = "../../modules/opensearch"
  environment = local.environment
  name_prefix = local.name_prefix
  enabled     = var.enable_opensearch
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  common_tags = local.common_tags
}

################################################################################
# EventBridge
################################################################################

module "eventbridge" {
  source      = "../../modules/eventbridge"
  environment = local.environment
  name_prefix = local.name_prefix
  kms_key_id  = module.kms.key_id
  common_tags = local.common_tags
}

################################################################################
# SQS Queues
################################################################################

module "sqs" {
  source      = "../../modules/sqs"
  environment = local.environment
  name_prefix = local.name_prefix
  kms_key_id  = module.kms.key_id
  queues      = var.sqs_queues
  common_tags = local.common_tags
}

################################################################################
# Lambda Workers (optional)
################################################################################

module "lambda_worker" {
  source      = "../../modules/lambda-worker"
  environment = local.environment
  name_prefix = local.name_prefix
  enabled     = var.enable_lambda_workers
  common_tags = local.common_tags
}

################################################################################
# S3 Documents
################################################################################

module "s3_docs" {
  source        = "../../modules/s3-docs"
  environment   = local.environment
  name_prefix   = local.name_prefix
  kms_key_arn   = module.kms.key_arn
  force_destroy = true
  common_tags   = local.common_tags
}

################################################################################
# Cognito
################################################################################

module "cognito" {
  source      = "../../modules/cognito"
  environment = local.environment
  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

################################################################################
# CloudFront
################################################################################

module "cloudfront" {
  source               = "../../modules/cloudfront"
  environment          = local.environment
  name_prefix          = local.name_prefix
  api_gateway_endpoint = module.apigw.api_endpoint
  acm_certificate_arn  = var.cloudfront_acm_certificate_arn
  web_acl_arn          = module.waf.web_acl_arn
  common_tags          = local.common_tags
}

################################################################################
# WAF (optional)
################################################################################

module "waf" {
  source      = "../../modules/waf"
  environment = local.environment
  name_prefix = local.name_prefix
  enabled     = var.enable_waf
  common_tags = local.common_tags
}

################################################################################
# Observability
################################################################################

module "observability" {
  source           = "../../modules/observability"
  environment      = local.environment
  name_prefix      = local.name_prefix
  aws_region       = var.aws_region
  ecs_cluster_name = aws_ecs_cluster.main.name
  service_names    = [for k, v in module.services : v.service_name]
  common_tags      = local.common_tags
}
