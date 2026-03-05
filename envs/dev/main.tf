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
  environment = "dev"
  name_prefix = "leasebase-${local.environment}-v2"
  common_tags = {
    App       = "LeaseBase"
    Env       = local.environment
    Stack     = "v2"
    Owner     = "motart"
    ManagedBy = "Terraform"
  }

  # ── Cognito env vars shared by all services ──────────────────────────────
  cognito_env = [
    { name = "COGNITO_USER_POOL_ID", value = module.cognito.user_pool_id },
    { name = "COGNITO_WEB_CLIENT_ID", value = module.cognito.web_client_id },
    { name = "COGNITO_REGION", value = var.aws_region },
    { name = "JWKS_URI", value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${module.cognito.user_pool_id}/.well-known/jwks.json" },
  ]

  # ── Redis env var shared by services that need caching ───────────────────
  redis_env = [
    { name = "REDIS_URL", value = "redis://${module.redis.primary_endpoint}:${module.redis.port}" },
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
    web = {
      port              = 3000
      cpu               = 256
      memory            = 512
      desired_count     = 1
      health_check_path = "/healthz"
      path_patterns     = ["/*"]
      priority          = 500
    }
  }

  # ── Per-service extra environment variables ──────────────────────────────
  service_extra_env = {
    bff-gateway         = local.cognito_env
    auth-service        = local.cognito_env
    property-service    = concat(local.cognito_env, local.redis_env)
    lease-service       = concat(local.cognito_env, local.redis_env)
    tenant-service      = concat(local.cognito_env, local.redis_env)
    maintenance-service = concat(local.cognito_env, local.redis_env)
    payments-service    = concat(local.cognito_env, local.redis_env)
    notification-service = concat(local.cognito_env, [
      { name = "SQS_QUEUE_URL", value = module.sqs.queue_urls["notifications"] },
    ])
    document-service = concat(local.cognito_env, [
      { name = "S3_DOCUMENTS_BUCKET", value = module.s3_docs.bucket_name },
      { name = "SQS_QUEUE_URL", value = module.sqs.queue_urls["document-processing"] },
    ])
    reporting-service = concat(local.cognito_env, [
      { name = "SQS_QUEUE_URL", value = module.sqs.queue_urls["reporting-jobs"] },
    ])
    web = concat(local.cognito_env, [
      { name = "API_BASE_URL", value = "http://${module.alb.alb_dns_name}" },
      { name = "HOSTNAME", value = "0.0.0.0" },
    ])
  }

  # ── Per-service DB secret references ────────────────────────────────────
  # Maps service names that need DB access to their Secrets Manager secret ARN
  service_db_secret_map = {
    property-service     = "property"
    lease-service        = "lease"
    tenant-service       = "tenant"
    maintenance-service  = "maintenance"
    payments-service     = "payments"
    notification-service = "notification"
    document-service     = "document"
    reporting-service    = "reporting"
  }

  service_secrets = {
    for svc, schema_key in local.service_db_secret_map : svc => [
      { name = "DATABASE_SECRET_ARN", valueFrom = module.database_platform.service_secret_arns[schema_key] },
    ]
  }

  # ── Per-service IAM statements ──────────────────────────────────────────
  service_extra_iam = {
    document-service = [
      {
        Sid      = "S3DocumentAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [module.s3_docs.bucket_arn, "${module.s3_docs.bucket_arn}/*"]
      },
      {
        Sid      = "SQSSendDocProcessing"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs.queue_arns["document-processing"]]
      },
    ]
    notification-service = [
      {
        Sid      = "SQSSendNotifications"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs.queue_arns["notifications"]]
      },
    ]
    reporting-service = [
      {
        Sid      = "SQSSendReportingJobs"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [module.sqs.queue_arns["reporting-jobs"]]
      },
    ]
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
  extra_environment     = lookup(local.service_extra_env, each.key, [])
  secrets               = lookup(local.service_secrets, each.key, [])
  extra_iam_statements  = lookup(local.service_extra_iam, each.key, [])
  common_tags           = local.common_tags
}

################################################################################
# Database Platform (Aurora + Proxy + Per-Service Secrets + Alarms)
################################################################################

module "database_platform" {
  source                 = "../../modules/database-platform"
  environment            = local.environment
  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  ecs_security_group_ids = [] # SG rules created externally to avoid for_each cycle
  kms_key_id             = module.kms.key_arn
  kms_key_arn            = module.kms.key_arn
  database_name          = var.db_name
  instance_count         = 1 # single instance in dev for cost savings
  min_capacity           = var.aurora_min_capacity
  max_capacity           = var.aurora_max_capacity
  deletion_protection    = false
  skip_final_snapshot    = true
  common_tags            = local.common_tags
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
  allowed_security_group_ids = [] # SG rules created externally to avoid for_each cycle
  node_type                  = var.redis_node_type
  common_tags                = local.common_tags
}

# ── External SG rules (avoid cycle: services ↔ redis/database_platform) ──────
# module.services SG IDs can't be passed into modules that feed back into
# services (via extra_environment), so we wire access here as standalone rules.

resource "aws_security_group_rule" "redis_from_services" {
  for_each = module.services

  type                     = "ingress"
  description              = "Redis from ${each.key}"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.redis.security_group_id
  source_security_group_id = each.value.security_group_id
}

resource "aws_security_group_rule" "db_from_services" {
  for_each = module.services

  type                     = "ingress"
  description              = "PostgreSQL from ${each.key}"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.database_platform.db_security_group_id
  source_security_group_id = each.value.security_group_id
}

resource "aws_security_group_rule" "db_proxy_from_services" {
  for_each = module.services

  type                     = "ingress"
  description              = "PostgreSQL via Proxy from ${each.key}"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.database_platform.proxy_security_group_id
  source_security_group_id = each.value.security_group_id
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
  domain_aliases       = var.cloudfront_acm_certificate_arn != "" ? [var.domain_name] : []
  web_acl_arn          = module.waf.web_acl_arn
  common_tags          = local.common_tags
}

################################################################################
# Route53 - dev.leasebase.co → CloudFront
################################################################################

data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.root_domain_name
}

resource "aws_route53_record" "web" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
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

################################################################################
# GitHub Actions OIDC (CI/CD)
################################################################################

module "github_oidc" {
  source = "../../modules/github-oidc"

  name_prefix                = local.name_prefix
  github_repositories        = var.github_oidc_repositories
  allowed_branch             = "develop"
  create_oidc_provider       = var.create_github_oidc_provider
  existing_oidc_provider_arn = var.existing_github_oidc_provider_arn

  ecr_repository_arns = [
    for k, v in module.services : "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${v.ecr_repository_name}"
  ]

  ecs_role_arns = concat(
    [aws_iam_role.ecs_execution.arn],
    [for k, v in module.services : v.task_role_arn]
  )

  cloudfront_distribution_arns = [module.cloudfront.distribution_arn]

  allow_logs_access = true
  common_tags       = local.common_tags
}

data "aws_caller_identity" "current" {}
