################################################################################
# Networking — Security Groups
################################################################################

# ── Database Security Group ──────────────────────────────────────────────────

resource "aws_security_group" "db" {
  name_prefix = "${var.name_prefix}-db-platform-"
  description = "LeaseBase database platform - Aurora access"
  vpc_id      = var.vpc_id

  # Allow inbound from ECS services
  dynamic "ingress" {
    for_each = var.ecs_security_group_ids
    content {
      description     = "PostgreSQL from ECS service"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-platform-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ── RDS Proxy Security Group ────────────────────────────────────────────────

resource "aws_security_group" "proxy" {
  name_prefix = "${var.name_prefix}-db-proxy-"
  description = "LeaseBase database platform - RDS Proxy access"
  vpc_id      = var.vpc_id

  # Allow inbound from ECS services
  dynamic "ingress" {
    for_each = var.ecs_security_group_ids
    content {
      description     = "PostgreSQL from ECS service"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-proxy-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Cross-references (standalone rules to avoid cycles) ─────────────────────

resource "aws_security_group_rule" "db_from_proxy" {
  type                     = "ingress"
  description              = "PostgreSQL from RDS Proxy"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.proxy.id
}

resource "aws_security_group_rule" "proxy_to_db" {
  type                     = "egress"
  description              = "PostgreSQL to Aurora"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.proxy.id
  source_security_group_id = aws_security_group.db.id
}
