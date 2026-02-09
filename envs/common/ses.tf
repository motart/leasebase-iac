############################
# SES Email Configuration
############################

# Email identity for sending notifications
# Note: For production, use a verified domain instead of individual email addresses
resource "aws_ses_email_identity" "notifications" {
  email = var.ses_from_email
}

# Optional: Domain identity (uncomment if using domain-based verification)
# resource "aws_ses_domain_identity" "main" {
#   domain = var.ses_domain
# }

# resource "aws_ses_domain_dkim" "main" {
#   domain = aws_ses_domain_identity.main.domain
# }

# SES configuration set for tracking
resource "aws_ses_configuration_set" "main" {
  name = "${local.name_prefix}-config-set"

  reputation_metrics_enabled = true

  delivery_options {
    tls_policy = "Require"
  }
}

# CloudWatch event destination for email events
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "${local.name_prefix}-cloudwatch"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true

  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "open",
    "click"
  ]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "ses:source-ip"
    value_source   = "messageTag"
  }
}

# IAM policy for SES sending (more granular than the one in iam.tf)
resource "aws_iam_role_policy" "ecs_ses_config_set" {
  name = "${local.name_prefix}-ses-config-set"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:ConfigurationSetName" = aws_ses_configuration_set.main.name
          }
        }
      }
    ]
  })
}
