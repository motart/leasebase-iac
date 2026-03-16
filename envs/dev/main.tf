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
  # Canonical Cognito env vars injected into all ECS services.
  # All backend code reads COGNITO_CLIENT_ID (see service-common getJwtConfig).
  cognito_env = [
    { name = "COGNITO_USER_POOL_ID", value = module.cognito.user_pool_id },
    { name = "COGNITO_CLIENT_ID", value = module.cognito.web_client_id },
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

  # ── CORS origins (shared by BFF gateway and API Gateway) ─────────────────
  # Only the primary app domain and localhost are trusted origins.
  # Vanity subdomains (signin.*, signup.*) are NOT trusted — they 302 to app.*.
  cors_origins = compact(concat(
    var.domain_name != "" ? ["https://${var.domain_name}"] : [],
    ["http://localhost:3000"],
  ))

  # Shared internal service key for service-to-service auth (invitation flow).
  # In production this should come from Secrets Manager.
  internal_service_key = random_password.internal_service_key.result

  # ── Per-service extra environment variables ──────────────────────────────
  service_extra_env = {
    bff-gateway = concat(local.cognito_env, [
      { name = "INTERNAL_ALB_URL", value = "http://${module.alb.alb_dns_name}" },
      { name = "USE_ALB", value = "true" },
      { name = "CORS_ORIGIN", value = join(",", local.cors_origins) },
    ])
    auth-service = concat(local.cognito_env, [
      { name = "INTERNAL_SERVICE_KEY", value = local.internal_service_key },
    ])
    property-service = concat(local.cognito_env, local.redis_env)
    lease-service = concat(local.cognito_env, local.redis_env, [
      { name = "DATABASE_SCHEMA", value = "lease_service" },
    ])
    tenant-service = concat(local.cognito_env, local.redis_env, [
      { name = "INTERNAL_SERVICE_KEY", value = local.internal_service_key },
      { name = "AUTH_SERVICE_URL", value = "http://${module.alb.alb_dns_name}" },
      { name = "APP_BASE_URL", value = "https://${var.domain_name}" },
      { name = "SES_FROM_EMAIL", value = "noreply@${var.env_subdomain_prefix != "" ? "${var.env_subdomain_prefix}.${var.root_domain_name}" : var.root_domain_name}" },
      { name = "SES_REGION", value = var.aws_region },
    ])
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
      { name = "API_BASE_URL", value = "https://${var.api_domain_name}" },
      { name = "NEXT_PUBLIC_API_BASE_URL", value = "https://${var.api_domain_name}" },
      { name = "HOSTNAME", value = "0.0.0.0" },
      { name = "NEXT_PUBLIC_APP_URL", value = "https://${var.domain_name}" },
      { name = "NEXT_PUBLIC_APP_DOMAIN", value = var.root_domain_name },
      { name = "ENABLE_OLD_DOMAIN_REDIRECTS", value = var.old_root_domain_name != "" ? "true" : "false" },
      { name = "OLD_DOMAIN", value = var.old_root_domain_name },
    ])
  }

  # ── Per-service DB secret references ──────────────────────────────
  # Derived from the canonical service_db_config — no hand-maintained map.
  # Maps ECS service name (with "-service" suffix) → config key in the module.
  service_db_key_map = {
    bff-gateway          = "bff"
    auth-service         = "auth"
    property-service     = "property"
    lease-service        = "lease"
    tenant-service       = "tenant"
    maintenance-service  = "maintenance"
    payments-service     = "payments"
    notification-service = "notification"
    document-service     = "document"
    reporting-service    = "reporting"
  }

  # Only inject DATABASE_SECRET_ARN for services that actually need DB access
  service_secrets = {
    for svc, cfg_key in local.service_db_key_map : svc => [
      { name = "DATABASE_SECRET_ARN", valueFrom = module.database_platform.service_secret_arns[cfg_key] },
    ] if contains(module.database_platform.db_service_names, cfg_key)
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
    tenant-service = [
      {
        Sid      = "SESSendInvitationEmail"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = ["*"]
      },
    ]
  }
}

################################################################################
# Internal Service Key (service-to-service auth)
################################################################################

resource "random_password" "internal_service_key" {
  length  = 48
  special = false
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
# Public Web ALB — internet-facing, serves dev.leasebase.co directly.
################################################################################

resource "aws_security_group" "web_alb" {
  name_prefix = "${local.name_prefix}-web-alb-"
  description = "Security group for public web ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (redirects to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "web_alb" {
  name               = "${local.name_prefix}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_alb.id]
  subnets            = module.vpc.public_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-alb"
  })
}

resource "aws_lb_target_group" "web_alb" {
  name        = "${local.name_prefix}-web-pub"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    path                = "/healthz"
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web-pub-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "web_alb_https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.regional.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_alb.arn
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "web_alb_http_redirect" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
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

  # CORS: web frontend (all persona subdomains) and local dev
  cors_allow_origins = local.cors_origins

  # Custom domain: api.dev.leasebase.ai
  custom_domain_name            = var.api_domain_name
  custom_domain_certificate_arn = var.api_domain_name != "" ? aws_acm_certificate_validation.regional.certificate_arn : ""
  custom_domain_zone_id         = var.api_domain_name != "" ? aws_route53_zone.leasebase_ai.zone_id : ""
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

  # Web service: skip internal ALB, register only with public web ALB.
  # All other services: register with internal ALB only.
  register_with_alb            = each.key != "web"
  additional_target_group_arns = each.key == "web" ? [aws_lb_target_group.web_alb.arn] : []
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

# Allow traffic from the public web ALB to the web ECS tasks (same pattern as
# redis_from_services / db_from_services to avoid for_each on unknown SG IDs).
resource "aws_security_group_rule" "web_alb_to_web_ecs" {
  type                     = "ingress"
  description              = "Traffic from public web ALB"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = module.services["web"].security_group_id
  source_security_group_id = aws_security_group.web_alb.id
}

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
  source             = "../../modules/cognito"
  environment        = local.environment
  name_prefix        = local.name_prefix
  log_retention_days = var.log_retention_days
  common_tags        = local.common_tags
}

################################################################################
# CloudFront (disabled for dev — traffic goes directly to ALB / API GW)
################################################################################
# State migration: module.cloudfront -> module.cloudfront[0] when count was added.
# Prevents destroy/recreate (and downtime) by mapping old state addresses.
moved {
  from = module.cloudfront.aws_cloudfront_distribution.main
  to   = module.cloudfront[0].aws_cloudfront_distribution.main
}

moved {
  from = module.cloudfront.aws_cloudfront_origin_request_policy.web_default
  to   = module.cloudfront[0].aws_cloudfront_origin_request_policy.web_default
}

moved {
  from = module.cloudfront.aws_cloudfront_response_headers_policy.security
  to   = module.cloudfront[0].aws_cloudfront_response_headers_policy.security
}

module "cloudfront" {
  count = var.enable_cloudfront ? 1 : 0

  source               = "../../modules/cloudfront"
  environment          = local.environment
  name_prefix          = local.name_prefix
  api_gateway_endpoint = module.apigw.api_endpoint
  acm_certificate_arn  = var.cloudfront_acm_certificate_arn
  domain_aliases = var.cloudfront_acm_certificate_arn != "" ? concat(
    [var.domain_name],
    # Vanity redirect domains added when CloudFront is the routing target;
    # the us-east-1 cert must cover *.root_domain_name for this to work.
    var.route53_web_target == "cloudfront" ? var.vanity_redirect_domains : [],
  ) : []
  web_acl_arn      = module.waf.web_acl_arn
  web_alb_dns_name = aws_lb.web_alb.dns_name
  common_tags      = local.common_tags
}

################################################################################
# Route53 — leasebase.ai hosted zone (shared/global, managed from DEV stack)
################################################################################

resource "aws_route53_zone" "leasebase_ai" {
  name = var.root_domain_name
  tags = merge(local.common_tags, {
    Name = "${var.root_domain_name}-zone"
    Note = "Shared/global zone. Managed from DEV stack because DEV is the only stack today."
  })
}

# WordPress marketing site — apex and www
resource "aws_route53_record" "wordpress_apex" {
  zone_id = aws_route53_zone.leasebase_ai.zone_id
  name    = var.root_domain_name
  type    = "A"
  ttl     = 300
  records = ["54.242.108.62"]
}

resource "aws_route53_record" "wordpress_www" {
  zone_id = aws_route53_zone.leasebase_ai.zone_id
  name    = "www.${var.root_domain_name}"
  type    = "A"
  ttl     = 300
  records = ["54.242.108.62"]
}

# app.dev.leasebase.ai — points to either the public web ALB or CloudFront,
# controlled by var.route53_web_target for safe 2-step cutover.
resource "aws_route53_record" "web" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = aws_route53_zone.leasebase_ai.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name = (
      var.route53_web_target == "cloudfront" && var.enable_cloudfront
      ? module.cloudfront[0].distribution_domain_name
      : aws_lb.web_alb.dns_name
    )
    zone_id = (
      var.route53_web_target == "cloudfront" && var.enable_cloudfront
      ? module.cloudfront[0].distribution_hosted_zone_id
      : aws_lb.web_alb.zone_id
    )
    evaluate_target_health = var.route53_web_target == "alb"
  }
}

# Vanity redirect subdomains — all point to the web ALB for 302 redirect.
# signin.dev.leasebase.ai, signup.dev.leasebase.ai
resource "aws_route53_record" "vanity_redirects" {
  for_each = var.domain_name != "" ? toset(var.vanity_redirect_domains) : toset([])

  zone_id = aws_route53_zone.leasebase_ai.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}

################################################################################
# ALB Vanity Redirect Listener Rules (signin.* → /auth/login, signup.* → /auth/register)
################################################################################

resource "aws_lb_listener_rule" "vanity_signin_redirect" {
  count        = var.domain_name != "" && length([for d in var.vanity_redirect_domains : d if can(regex("^signin\\.", d))]) > 0 ? 1 : 0
  listener_arn = aws_lb_listener.web_alb_https.arn
  priority     = 10

  condition {
    host_header {
      values = [for d in var.vanity_redirect_domains : d if can(regex("^signin\\.", d))]
    }
  }

  action {
    type = "redirect"
    redirect {
      host        = var.domain_name
      path        = "/auth/login"
      query       = ""
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }
}

resource "aws_lb_listener_rule" "vanity_signup_redirect" {
  count        = var.domain_name != "" && length([for d in var.vanity_redirect_domains : d if can(regex("^signup\\.", d))]) > 0 ? 1 : 0
  listener_arn = aws_lb_listener.web_alb_https.arn
  priority     = 11

  condition {
    host_header {
      values = [for d in var.vanity_redirect_domains : d if can(regex("^signup\\.", d))]
    }
  }

  action {
    type = "redirect"
    redirect {
      host        = var.domain_name
      path        = "/auth/register"
      query       = ""
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }
}

################################################################################
# ACM Certificate (us-west-2) — covers app.dev.leasebase.ai + api.dev.leasebase.ai + *.dev.leasebase.ai
################################################################################

resource "aws_acm_certificate" "regional" {
  count = var.domain_name != "" ? 1 : 0

  domain_name = var.domain_name
  subject_alternative_names = compact(concat(
    var.api_domain_name != "" ? [var.api_domain_name] : [],
    var.env_subdomain_prefix != "" ? ["*.${var.env_subdomain_prefix}.${var.root_domain_name}"] : ["*.${var.root_domain_name}"],
  ))
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-regional-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in(var.domain_name != "" ? aws_acm_certificate.regional[0].domain_validation_options : []) :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.leasebase_ai.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "regional" {
  certificate_arn         = aws_acm_certificate.regional[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# Legacy ACM Certificate — *.leasebase.co (old-domain redirect TLS continuity)
# Remove when old-domain redirects are decommissioned.
################################################################################

resource "aws_acm_certificate" "old_domain_redirect" {
  count             = var.old_root_domain_name != "" ? 1 : 0
  domain_name       = "*.${var.old_root_domain_name}"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-old-domain-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "old_domain" {
  count = var.old_root_domain_name != "" ? 1 : 0
  name  = var.old_root_domain_name
}

resource "aws_route53_record" "old_cert_validation" {
  for_each = {
    for dvo in(var.old_root_domain_name != "" ? aws_acm_certificate.old_domain_redirect[0].domain_validation_options : []) :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.old_domain[0].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "old_domain_redirect" {
  count                   = var.old_root_domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.old_domain_redirect[0].arn
  validation_record_fqdns = [for r in aws_route53_record.old_cert_validation : r.fqdn]
}

# Attach legacy cert to web ALB as additional cert (SNI).
# This allows old-domain HTTPS to terminate at the ALB so middleware can 301.
resource "aws_lb_listener_certificate" "old_domain" {
  count           = var.old_root_domain_name != "" ? 1 : 0
  listener_arn    = aws_lb_listener.web_alb_https.arn
  certificate_arn = aws_acm_certificate_validation.old_domain_redirect[0].certificate_arn
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

  cloudfront_distribution_arns = var.enable_cloudfront ? [module.cloudfront[0].distribution_arn] : []

  allow_logs_access = true
  common_tags       = local.common_tags
}

data "aws_caller_identity" "current" {}
