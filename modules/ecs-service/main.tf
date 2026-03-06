################################################################################
# ECS Service Module - LeaseBase v2
# Reusable module for each microservice: ECR, task def, service, TG, autoscaling
################################################################################

locals {
  service_name = "${var.name_prefix}-${var.name}"
}

################################################################################
# ECR Repository
################################################################################

resource "aws_ecr_repository" "main" {
  name                 = "${var.name_prefix}-${var.name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-${var.name}"
    Service = var.name
  })
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Service = var.name
  })
}

################################################################################
# IAM Task Role (what the container can do)
################################################################################

resource "aws_iam_role" "task" {
  name = "${local.service_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Service = var.name
  })
}

# Base policy for all services - Secrets Manager + SSM read
resource "aws_iam_role_policy" "task_base" {
  name = "base-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "SecretsManagerRead"
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParametersByPath"
          ]
          Resource = "*"
        },
        {
          Sid      = "KMSDecrypt"
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = "*"
        },
        {
          Sid    = "XRay"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = "*"
        }
      ],
      var.extra_iam_statements
    )
  })
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "service" {
  name_prefix = "${local.service_name}-"
  description = "Security group for ${var.name} ECS service"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.register_with_alb ? [1] : []
    content {
      description     = "Traffic from internal ALB"
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name    = "${local.service_name}-sg"
    Service = var.name
  })

  lifecycle {
    create_before_destroy = true
  }
}


################################################################################
# Target Group + Listener Rule
################################################################################

resource "aws_lb_target_group" "main" {
  count = var.register_with_alb ? 1 : 0

  name        = "${var.name_prefix}-${replace(var.name, "-service", "")}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    path                = var.health_check_path
    matcher             = "200-299"
  }

  deregistration_delay = 30

  tags = merge(var.common_tags, {
    Service = var.name
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "main" {
  count = var.register_with_alb ? 1 : 0

  listener_arn = var.alb_listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  tags = merge(var.common_tags, {
    Service = var.name
  })
}

################################################################################
# ECS Task Definition (bootstrap / env-var seed)
#
# CI (deploy_ecs.sh) owns the task definition lifecycle after initial creation.
# On each deploy, CI fetches the latest revision, swaps the image tag, and
# registers a new revision — preserving all env vars set here.
#
# To add or change env vars: update extra_environment in the env config,
# run terraform apply, then trigger a CI deploy (or force a redeployment)
# so the new revision inherits the updated vars.
################################################################################

resource "aws_ecs_task_definition" "main" {
  family                   = local.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${aws_ecr_repository.main.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = concat(
        [
          { name = "PORT", value = tostring(var.container_port) },
          { name = "NODE_ENV", value = var.environment },
          { name = "SERVICE_NAME", value = var.name },
        ],
        var.extra_environment
      )

      secrets = var.secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.name
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(var.common_tags, {
    Service = var.name
  })
}

################################################################################
# ECS Service
################################################################################

resource "aws_ecs_service" "main" {
  name            = local.service_name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.register_with_alb ? [aws_lb_target_group.main[0].arn] : []
    content {
      target_group_arn = load_balancer.value
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  dynamic "load_balancer" {
    for_each = var.additional_target_group_arns
    content {
      target_group_arn = load_balancer.value
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  propagate_tags = "TASK_DEFINITION"

  lifecycle {
    # desired_count: managed by autoscaling, not Terraform
    # task_definition: managed by CI (deploy_ecs.sh), not Terraform
    ignore_changes = [desired_count, task_definition]
  }

  tags = merge(var.common_tags, {
    Service = var.name
  })
}

################################################################################
# Auto Scaling
################################################################################

resource "aws_appautoscaling_target" "main" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${local.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.main.resource_id
  scalable_dimension = aws_appautoscaling_target.main.scalable_dimension
  service_namespace  = aws_appautoscaling_target.main.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
