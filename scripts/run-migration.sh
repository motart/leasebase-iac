#!/usr/bin/env bash
set -euo pipefail

# Run Prisma database migrations via ECS Fargate one-off task.
#
# Usage:
#   scripts/run-migration.sh \
#     --profile iamadmin-master \
#     --env dev \
#     [--wait]

PROFILE=""
ENV_NAME=""
REGION="us-east-1"
WAIT=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2;;
    --env)
      ENV_NAME="$2"; shift 2;;
    --region)
      REGION="$2"; shift 2;;
    --no-wait)
      WAIT=false; shift;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1;;
  esac
done

if [[ -z "$PROFILE" || -z "$ENV_NAME" ]]; then
  echo "ERROR: --profile and --env are required" >&2
  echo "Usage: $0 --profile <aws-profile> --env <dev|qa|prod> [--no-wait]" >&2
  exit 1
fi

export AWS_PROFILE="$PROFILE"
ENV_DIR="${ROOT_DIR}/envs/${ENV_NAME}"

echo "========================================"
echo "Leasebase Database Migration"
echo "========================================"
echo "Profile:     $PROFILE"
echo "Environment: $ENV_NAME"
echo "Region:      $REGION"
echo "========================================"

# Get Terraform outputs
cd "$ENV_DIR"

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
TASK_DEF_ARN=$(terraform output -raw api_migrate_task_definition_arn 2>/dev/null || echo "")

if [[ -z "$CLUSTER_NAME" || -z "$TASK_DEF_ARN" ]]; then
  echo "ERROR: Could not get cluster name or task definition from Terraform outputs." >&2
  echo "Make sure infrastructure is deployed first." >&2
  exit 1
fi

# Get VPC details from Terraform
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
SUBNET_IDS=$(terraform output -json public_subnet_ids 2>/dev/null | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP_ID=$(terraform output -raw ecs_security_group_id 2>/dev/null || echo "")

if [[ -z "$VPC_ID" || -z "$SUBNET_IDS" || -z "$SECURITY_GROUP_ID" ]]; then
  echo "ERROR: Could not get network configuration from Terraform outputs." >&2
  exit 1
fi

echo ""
echo "Cluster:      $CLUSTER_NAME"
echo "Task Def:     $TASK_DEF_ARN"
echo "Subnets:      $SUBNET_IDS"
echo "Security Grp: $SECURITY_GROUP_ID"
echo ""

# Run the migration task
echo "Starting migration task..."
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEF_ARN" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS}],securityGroups=[${SECURITY_GROUP_ID}],assignPublicIp=ENABLED}" \
  --region "$REGION" \
  --query 'tasks[0].taskArn' \
  --output text)

if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
  echo "ERROR: Failed to start migration task" >&2
  exit 1
fi

TASK_ID=$(echo "$TASK_ARN" | rev | cut -d'/' -f1 | rev)
echo "Migration task started: $TASK_ID"

if [[ "$WAIT" == "false" ]]; then
  echo "Task started (not waiting for completion)."
  echo "Task ARN: $TASK_ARN"
  exit 0
fi

# Wait for task to complete
echo ""
echo "Waiting for migration to complete..."

while true; do
  STATUS=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    --query 'tasks[0].lastStatus' \
    --output text)

  echo "  Status: $STATUS"

  if [[ "$STATUS" == "STOPPED" ]]; then
    break
  fi

  sleep 10
done

# Check exit code
EXIT_CODE=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --region "$REGION" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)

STOP_REASON=$(aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --region "$REGION" \
  --query 'tasks[0].stoppedReason' \
  --output text)

echo ""
echo "========================================"
if [[ "$EXIT_CODE" == "0" ]]; then
  echo "Migration completed successfully!"
else
  echo "Migration FAILED!"
  echo "Exit Code: $EXIT_CODE"
  echo "Reason: $STOP_REASON"
  echo ""
  echo "Check CloudWatch Logs for details:"
  echo "  Log Group: /ecs/leasebase-${ENV_NAME}-api"
  echo "  Log Stream: migrate/${TASK_ID}"
  exit 1
fi
echo "========================================"
