################################################################################
# GitHub Actions OIDC — IAM role for CI/CD pipelines
#
# Creates:
#   1. GitHub OIDC identity provider (if not already present)
#   2. IAM role assumable by GitHub Actions via OIDC
#   3. Least-privilege policy scoped to ECR push + ECS deploy
################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition
  oidc_provider = "token.actions.githubusercontent.com"
}

################################################################################
# OIDC Provider (idempotent — skip if already exists)
################################################################################

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://${local.oidc_provider}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name = "github-actions-oidc"
  })
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
}

################################################################################
# IAM Role — GitHub Actions
################################################################################

resource "aws_iam_role" "github_actions" {
  name = "${var.name_prefix}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${local.oidc_provider}:sub" = [
              for repo in var.github_repositories :
              "repo:${repo}:ref:refs/heads/${var.allowed_branch}"
            ]
          }
        }
      },
      # Allow workflow_dispatch (which doesn't include a ref in sub for reusable workflows)
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${local.oidc_provider}:sub" = [
              for repo in var.github_repositories :
              "repo:${repo}:environment:*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-actions"
  })
}

################################################################################
# Policy — ECR (push images)
################################################################################

resource "aws_iam_role_policy" "ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = [
          for repo in var.ecr_repository_arns :
          repo
        ]
      }
    ]
  })
}

################################################################################
# Policy — ECS (deploy)
################################################################################

resource "aws_iam_role_policy" "ecs" {
  name = "ecs-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSReadDeploy"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:ListTasks"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassECSRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = var.ecs_role_arns
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

################################################################################
# Policy — STS (for account ID lookup in scripts)
################################################################################

resource "aws_iam_role_policy" "sts" {
  name = "sts-identity"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "STSGetCallerIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Policy — CloudFront (cache invalidation after deploys)
################################################################################

resource "aws_iam_role_policy" "cloudfront" {
  count = length(var.cloudfront_distribution_arns) > 0 ? 1 : 0
  name  = "cloudfront-invalidate"
  role  = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = var.cloudfront_distribution_arns
      }
    ]
  })
}

################################################################################
# Optional: CloudWatch Logs (for debugging)
################################################################################

resource "aws_iam_role_policy" "logs" {
  count = var.allow_logs_access ? 1 : 0
  name  = "cloudwatch-logs"
  role  = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
