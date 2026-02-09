#!/usr/bin/env bash
set -euo pipefail

# Deploy Leasebase infrastructure using Terraform.
#
# Usage:
#   scripts/deploy.sh \
#     --profile iamadmin-master \
#     --env dev \
#     [--plan-only] \
#     [--auto-approve] \
#     [--destroy]

PROFILE=""
ENV_NAME=""
PLAN_ONLY=false
AUTO_APPROVE=false
DESTROY=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2;;
    --env)
      ENV_NAME="$2"; shift 2;;
    --plan-only)
      PLAN_ONLY=true; shift;;
    --auto-approve)
      AUTO_APPROVE=true; shift;;
    --destroy)
      DESTROY=true; shift;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1;;
  esac
done

if [[ -z "$PROFILE" || -z "$ENV_NAME" ]]; then
  echo "ERROR: --profile and --env are required" >&2
  echo "Usage: $0 --profile <aws-profile> --env <dev|qa|prod> [--plan-only] [--auto-approve]" >&2
  exit 1
fi

ENV_DIR="${ROOT_DIR}/envs/${ENV_NAME}"
TFVARS_FILE="${ENV_DIR}/${ENV_NAME}.tfvars"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "ERROR: Environment directory not found: $ENV_DIR" >&2
  exit 1
fi

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "ERROR: tfvars file not found: $TFVARS_FILE" >&2
  echo "Please copy ${ENV_NAME}.tfvars.example to ${ENV_NAME}.tfvars and configure it." >&2
  exit 1
fi

export AWS_PROFILE="$PROFILE"

echo "========================================"
echo "Leasebase Infrastructure Deployment"
echo "========================================"
echo "Profile:     $PROFILE"
echo "Environment: $ENV_NAME"
echo "Directory:   $ENV_DIR"
echo "========================================"

cd "$ENV_DIR"

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
terraform init -upgrade

if [[ "$DESTROY" == "true" ]]; then
  echo ""
  echo "WARNING: Destroying infrastructure!"
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform destroy -var-file="${ENV_NAME}.tfvars" -auto-approve
  else
    terraform destroy -var-file="${ENV_NAME}.tfvars"
  fi
  echo "Infrastructure destroyed."
  exit 0
fi

# Plan
echo ""
echo "Planning Terraform changes..."
terraform plan -var-file="${ENV_NAME}.tfvars" -out="${ENV_NAME}.tfplan"

if [[ "$PLAN_ONLY" == "true" ]]; then
  echo ""
  echo "Plan complete (--plan-only specified, skipping apply)."
  exit 0
fi

# Apply
echo ""
echo "Applying Terraform changes..."
if [[ "$AUTO_APPROVE" == "true" ]]; then
  terraform apply "${ENV_NAME}.tfplan"
else
  read -p "Apply these changes? (yes/no): " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    terraform apply "${ENV_NAME}.tfplan"
  else
    echo "Apply cancelled."
    exit 0
  fi
fi

# Show outputs
echo ""
echo "========================================"
echo "Deployment complete! Outputs:"
echo "========================================"
terraform output

# Clean up plan file
rm -f "${ENV_NAME}.tfplan"
