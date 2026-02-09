#!/usr/bin/env bash
set -euo pipefail

# Full deployment orchestration script for Leasebase.
# This script handles the complete deployment process:
# 1. Bootstrap remote state (if needed)
# 2. Deploy infrastructure
# 3. Build and push Docker images
# 4. Update ECS services
# 5. Run database migrations
#
# Usage:
#   scripts/deploy-all.sh \
#     --profile iamadmin-master \
#     --env dev \
#     [--skip-bootstrap] \
#     [--skip-build] \
#     [--skip-migrate] \
#     [--auto-approve]

PROFILE=""
ENV_NAME=""
REGION="us-west-1"
SKIP_BOOTSTRAP=false
SKIP_BUILD=false
SKIP_MIGRATE=false
AUTO_APPROVE=false
TAG="latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

print_banner() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                    LEASEBASE DEPLOYMENT                        ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
}

print_step() {
  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "  $1"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2;;
    --env)
      ENV_NAME="$2"; shift 2;;
    --region)
      REGION="$2"; shift 2;;
    --tag)
      TAG="$2"; shift 2;;
    --skip-bootstrap)
      SKIP_BOOTSTRAP=true; shift;;
    --skip-build)
      SKIP_BUILD=true; shift;;
    --skip-migrate)
      SKIP_MIGRATE=true; shift;;
    --auto-approve)
      AUTO_APPROVE=true; shift;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1;;
  esac
done

if [[ -z "$PROFILE" || -z "$ENV_NAME" ]]; then
  echo "ERROR: --profile and --env are required" >&2
  echo ""
  echo "Usage: $0 --profile <aws-profile> --env <dev|qa|prod> [options]"
  echo ""
  echo "Options:"
  echo "  --profile       AWS profile to use (required)"
  echo "  --env           Environment to deploy: dev, qa, or prod (required)"
  echo "  --region        AWS region (default: us-west-1)"
  echo "  --tag           Docker image tag (default: latest)"
  echo "  --skip-bootstrap  Skip remote state bootstrap"
  echo "  --skip-build    Skip Docker image build"
  echo "  --skip-migrate  Skip database migrations"
  echo "  --auto-approve  Auto-approve Terraform changes"
  exit 1
fi

export AWS_PROFILE="$PROFILE"
ENV_DIR="${ROOT_DIR}/envs/${ENV_NAME}"
TFVARS_FILE="${ENV_DIR}/${ENV_NAME}.tfvars"

print_banner

echo "Configuration:"
echo "  Profile:     $PROFILE"
echo "  Environment: $ENV_NAME"
echo "  Region:      $REGION"
echo "  Image Tag:   $TAG"
echo ""

# Validate prerequisites
if ! command -v terraform &> /dev/null; then
  echo "ERROR: terraform is not installed" >&2
  exit 1
fi

if ! command -v aws &> /dev/null; then
  echo "ERROR: aws CLI is not installed" >&2
  exit 1
fi

if ! command -v docker &> /dev/null; then
  echo "ERROR: docker is not installed" >&2
  exit 1
fi

# Check tfvars file exists
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "ERROR: tfvars file not found: $TFVARS_FILE" >&2
  echo ""
  echo "Please create it from the example:"
  echo "  cp ${ENV_DIR}/${ENV_NAME}.tfvars.example ${TFVARS_FILE}"
  echo "  # Edit ${TFVARS_FILE} with your configuration"
  exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "AWS Account: $ACCOUNT_ID"

# ─────────────────────────────────────────────────────────────────
# Step 1: Bootstrap Remote State (if needed)
# ─────────────────────────────────────────────────────────────────
BUCKET_NAME="leasebase-tfstate-${ENV_NAME}-${ACCOUNT_ID}"
TABLE_NAME="terraform-locks-${ENV_NAME}"

if [[ "$SKIP_BOOTSTRAP" == "false" ]]; then
  print_step "Step 1: Checking Remote State Backend"

  if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Remote state bucket exists: $BUCKET_NAME"
  else
    echo "Creating remote state backend..."
    "${SCRIPT_DIR}/bootstrap_remote_state.sh" \
      --profile "$PROFILE" \
      --region "$REGION" \
      --env "$ENV_NAME" \
      --bucket-prefix leasebase-tfstate
  fi

  # Auto-configure backend.tf if not already configured
  BACKEND_FILE="${ENV_DIR}/backend.tf"
  if grep -q "# Uncomment" "$BACKEND_FILE" 2>/dev/null || [[ ! -s "$BACKEND_FILE" ]]; then
    echo "Configuring backend.tf with remote state settings..."
    cat > "$BACKEND_FILE" <<BACKEND_EOF
# Terraform Backend Configuration for ${ENV_NAME} Environment
# Auto-configured by deploy-all.sh

terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "envs/${ENV_NAME}/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${TABLE_NAME}"
    encrypt        = true
  }
}
BACKEND_EOF
    echo "Backend configured: s3://${BUCKET_NAME}/envs/${ENV_NAME}/terraform.tfstate"
  fi
else
  print_step "Step 1: Skipping Remote State Bootstrap"
fi

# ─────────────────────────────────────────────────────────────────
# Step 2: Deploy Infrastructure
# ─────────────────────────────────────────────────────────────────
print_step "Step 2: Deploying Infrastructure"

cd "$ENV_DIR"

echo "Initializing Terraform..."
terraform init -upgrade

echo ""
echo "Planning infrastructure changes..."
terraform plan -var-file="${ENV_NAME}.tfvars" -out="${ENV_NAME}.tfplan"

if [[ "$AUTO_APPROVE" == "true" ]]; then
  echo ""
  echo "Applying infrastructure changes (auto-approved)..."
  terraform apply "${ENV_NAME}.tfplan"
else
  echo ""
  read -p "Apply these infrastructure changes? (yes/no): " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    terraform apply "${ENV_NAME}.tfplan"
  else
    echo "Deployment cancelled."
    exit 0
  fi
fi

rm -f "${ENV_NAME}.tfplan"

# Get outputs for subsequent steps
ECR_API_URL=$(terraform output -raw ecr_api_repository_url)
ECR_WEB_URL=$(terraform output -raw ecr_web_repository_url)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
API_SERVICE=$(terraform output -raw api_service_name)
WEB_SERVICE=$(terraform output -raw web_service_name)

echo ""
echo "Infrastructure deployed successfully!"
echo "  ECR API: $ECR_API_URL"
echo "  ECR Web: $ECR_WEB_URL"
echo "  Cluster: $CLUSTER_NAME"

# ─────────────────────────────────────────────────────────────────
# Step 3: Build and Push Docker Images
# ─────────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == "false" ]]; then
  print_step "Step 3: Building and Pushing Docker Images"

  "${SCRIPT_DIR}/build-and-push.sh" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --env "$ENV_NAME" \
    --tag "$TAG"
else
  print_step "Step 3: Skipping Docker Image Build"
fi

# ─────────────────────────────────────────────────────────────────
# Step 4: Update ECS Services
# ─────────────────────────────────────────────────────────────────
print_step "Step 4: Updating ECS Services"

echo "Forcing new deployment of API service..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$API_SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --query 'service.serviceName' \
  --output text

echo "Forcing new deployment of Web service..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$WEB_SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --query 'service.serviceName' \
  --output text

echo ""
echo "ECS services are deploying. This may take a few minutes."

# ─────────────────────────────────────────────────────────────────
# Step 5: Run Database Migrations
# ─────────────────────────────────────────────────────────────────
if [[ "$SKIP_MIGRATE" == "false" ]]; then
  print_step "Step 5: Running Database Migrations"

  "${SCRIPT_DIR}/run-migration.sh" \
    --profile "$PROFILE" \
    --region "$REGION" \
    --env "$ENV_NAME"
else
  print_step "Step 5: Skipping Database Migrations"
fi

# ─────────────────────────────────────────────────────────────────
# Deployment Complete
# ─────────────────────────────────────────────────────────────────
print_step "Deployment Complete!"

cd "$ENV_DIR"

ALB_DNS=$(terraform output -raw alb_dns_name)
COGNITO_DOMAIN=$(terraform output -raw cognito_domain)

echo "Your Leasebase environment is now deployed!"
echo ""
echo "Endpoints:"
echo "  Application:  http://${ALB_DNS}"
echo "  API:          http://${ALB_DNS}/api"
echo "  API Docs:     http://${ALB_DNS}/docs"
echo "  Health:       http://${ALB_DNS}/healthz"
echo ""
echo "Cognito:"
echo "  Domain:       https://${COGNITO_DOMAIN}"
echo ""
echo "Note: ECS services may still be starting. Allow 2-5 minutes for full availability."
echo ""
echo "To check service status:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $API_SERVICE $WEB_SERVICE --region $REGION"
