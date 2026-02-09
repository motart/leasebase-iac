############################
# GitHub OIDC Provider
############################

# Create GitHub OIDC provider (one per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.environment}-github-oidc"
    Environment = var.environment
  }
}

############################
# GitHub Actions Deploy Role
############################

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to specific repositories and branches
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo_api}:ref:refs/heads/${var.github_branch_pattern}",
        "repo:${var.github_org}/${var.github_repo_web}:ref:refs/heads/${var.github_branch_pattern}",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.environment}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "${var.environment}-github-actions-deploy"
    Environment = var.environment
  }
}

# Policy for ECR access
data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid    = "ECRGetAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      aws_ecr_repository.api.arn,
      aws_ecr_repository.web.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "${var.environment}-github-actions-ecr"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

# Policy for ECS deployment
data "aws_iam_policy_document" "github_actions_ecs" {
  statement {
    sid    = "ECSUpdateService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:ListTasks",
      "ecs:DescribeTasks"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.api.arn]
    }
  }

  statement {
    sid    = "ECSDescribeCluster"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:ListTasks"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECSTaskDefinitions"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PassRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ecs_task_role.arn,
      aws_iam_role.ecs_task_execution.arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_ecs" {
  name   = "${var.environment}-github-actions-ecs"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_ecs.json
}

############################
# Outputs
############################

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deploy role"
  value       = aws_iam_role.github_actions_deploy.arn
}
