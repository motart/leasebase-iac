#!/usr/bin/env bash
# =============================================================================
# check-mutable-tags.sh — Detect mutable Docker image tags in running ECS tasks
#
# Scans all services in the given ECS cluster and fails if any running task
# uses a mutable tag (e.g. :latest, :dev-latest) instead of an immutable
# Git SHA tag.
#
# Usage:
#   export AWS_REGION=us-west-2
#   ./ops/scripts/check-mutable-tags.sh <cluster-name>
#
# Exit codes:
#   0 — all services use immutable (SHA) tags
#   1 — one or more services use mutable tags
# =============================================================================
set -euo pipefail

CLUSTER="${1:?Usage: $0 <ecs-cluster-name>}"
REGION="${AWS_REGION:-us-west-2}"

# Mutable tag patterns to reject
MUTABLE_PATTERN=':(latest|dev-latest|staging-latest|prod-latest|main|develop)$'

FAIL=0
CHECKED=0

echo "🔍 Checking ECS cluster: ${CLUSTER} (region: ${REGION})"
echo ""

# List all services in the cluster
SERVICES=$(aws ecs list-services \
  --cluster "$CLUSTER" \
  --region "$REGION" \
  --query 'serviceArns[*]' \
  --output text)

if [[ -z "$SERVICES" ]]; then
  echo "⚠️  No services found in cluster ${CLUSTER}"
  exit 0
fi

for SERVICE_ARN in $SERVICES; do
  SERVICE_NAME=$(basename "$SERVICE_ARN")

  # Get the task definition ARN from the service
  TASK_DEF=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE_ARN" \
    --region "$REGION" \
    --query 'services[0].taskDefinition' \
    --output text)

  # Get the image from the task definition
  IMAGE=$(aws ecs describe-task-definition \
    --task-definition "$TASK_DEF" \
    --region "$REGION" \
    --query 'taskDefinition.containerDefinitions[0].image' \
    --output text)

  CHECKED=$((CHECKED + 1))

  if echo "$IMAGE" | grep -qE "$MUTABLE_PATTERN"; then
    TAG=$(echo "$IMAGE" | grep -oE ':[^:]+$')
    echo "❌ ${SERVICE_NAME}: mutable tag ${TAG}"
    echo "   image: ${IMAGE}"
    FAIL=$((FAIL + 1))
  else
    TAG=$(echo "$IMAGE" | grep -oE ':[^:]+$')
    echo "✅ ${SERVICE_NAME}: ${TAG}"
  fi
done

echo ""
echo "Checked ${CHECKED} services."

if [[ $FAIL -gt 0 ]]; then
  echo "❌ ${FAIL} service(s) using mutable tags. Deploy with SHA tags to fix."
  exit 1
else
  echo "✅ All services use immutable image tags."
  exit 0
fi
