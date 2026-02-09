############################
# Web Frontend ECS Service (Next.js SSR)
############################

# Security group for web service
resource "aws_security_group" "ecs_web" {
  name        = "${local.name_prefix}-ecs-web-sg"
  description = "ECS web service security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "From ALB"
    from_port       = var.web_port
    to_port         = var.web_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-ecs-web-sg"
    Environment = var.environment
  }
}

# Target group for web frontend
resource "aws_lb_target_group" "web" {
  name        = "${local.name_prefix}-web-tg"
  port        = var.web_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${local.name_prefix}-web-tg"
    Environment = var.environment
  }
}

# ALB listener rule for web (default action - web serves the root)
resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  # Ensure API paths are handled first (lower priority number = higher priority)
  depends_on = [aws_lb_listener_rule.api]
}

# ALB listener rule for API (higher priority)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/docs", "/docs/*", "/healthz", "/readyz", "/stripe/*"]
    }
  }
}

# Web task definition
resource "aws_ecs_task_definition" "web" {
  family                   = "${local.name_prefix}-web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.web_task_cpu
  memory                   = var.web_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = var.web_container_image
      essential = true

      portMappings = [{
        containerPort = var.web_port
        hostPort      = var.web_port
        protocol      = "tcp"
      }]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment == "prod" ? "production" : "development"
        },
        {
          name  = "PORT"
          value = tostring(var.web_port)
        },
        {
          name  = "NEXT_PUBLIC_API_BASE_URL"
          value = var.web_api_base_url
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_REGION"
          value = var.aws_region
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_USER_POOL_ID"
          value = aws_cognito_user_pool.main.id
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_CLIENT_ID"
          value = aws_cognito_user_pool_client.web.id
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_DOMAIN"
          value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_OAUTH_REDIRECT_SIGNIN"
          value = var.cognito_callback_urls[0]
        },
        {
          name  = "NEXT_PUBLIC_COGNITO_OAUTH_REDIRECT_SIGNOUT"
          value = var.cognito_logout_urls[0]
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])

  tags = {
    Name        = "${local.name_prefix}-web-task"
    Environment = var.environment
  }
}

# CloudWatch log group for web
resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.name_prefix}-web"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.name_prefix}-web-logs"
    Environment = var.environment
  }
}

# Web ECS service
resource "aws_ecs_service" "web" {
  name            = "${local.name_prefix}-web-service"
  cluster         = aws_ecs_cluster.api.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.web_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_web.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = var.web_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener_rule.web]
}
