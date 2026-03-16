#!/usr/bin/env bash
###############################################################################
# check-runtime-drift.sh — Detect drift between Terraform config and running
# ECS services in a LeaseBase cluster.
#
# Usage:
#   AWS_REGION=us-west-2 CLUSTER=leasebase-dev-v2-cluster ./scripts/check-runtime-drift.sh
#   # or with defaults:
#   ./scripts/check-runtime-drift.sh
#
# Optional:
#   TF_DIR  — path to the envs/<env> directory (for Terraform-based comparison)
#   VERBOSE — set to "true" for detailed per-var output
#
# Exit codes:
#   0 — no drift detected
#   1 — drift detected
#   2 — script error
###############################################################################
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER="${CLUSTER:-leasebase-dev-v2-cluster}"
TF_DIR="${TF_DIR:-}"
VERBOSE="${VERBOSE:-false}"

# ── Colors ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[DRIFT]${NC} $*"; }

DRIFT_COUNT=0
SERVICES_CHECKED=0

# ── Preflight ────────────────────────────────────────────────────────────────
for cmd in aws jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not installed." >&2
    exit 2
  fi
done

info "Cluster: ${CLUSTER}"
info "Region:  ${AWS_REGION}"
echo ""

# ── Enumerate services ───────────────────────────────────────────────────────
SERVICE_ARNS=$(aws ecs list-services \
  --cluster "$CLUSTER" \
  --region "$AWS_REGION" \
  --query 'serviceArns[]' \
  --output json 2>/dev/null)

if [[ "$SERVICE_ARNS" == "[]" || -z "$SERVICE_ARNS" ]]; then
  warn "No services found in cluster ${CLUSTER}"
  exit 0
fi

SERVICE_COUNT=$(echo "$SERVICE_ARNS" | jq -r 'length')
info "Found ${SERVICE_COUNT} services"
echo ""

# ── Header ───────────────────────────────────────────────────────────────────
printf "${BOLD}%-35s | %-15s | %-12s | %-6s${NC}\n" "Service" "Image Tag" "Task Rev" "Drift?"
printf "%-35s-+-%-15s-+-%-12s-+-%-6s\n" \
  "-----------------------------------" \
  "---------------" \
  "------------" \
  "------"

# ── Check each service ───────────────────────────────────────────────────────
for ARN in $(echo "$SERVICE_ARNS" | jq -r '.[]'); do
  SERVICE_NAME=$(echo "$ARN" | sed 's|.*/||')

  # Get running task definition
  SERVICE_JSON=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0]' \
    --output json 2>/dev/null)

  RUNNING_TASK_DEF=$(echo "$SERVICE_JSON" | jq -r '.taskDefinition // "unknown"')
  RUNNING_COUNT=$(echo "$SERVICE_JSON" | jq -r '.runningCount // 0')
  DESIRED_COUNT=$(echo "$SERVICE_JSON" | jq -r '.desiredCount // 0')

  # Get task definition details
  if [[ "$RUNNING_TASK_DEF" != "unknown" && "$RUNNING_TASK_DEF" != "null" ]]; then
    TASK_DEF_JSON=$(aws ecs describe-task-definition \
      --task-definition "$RUNNING_TASK_DEF" \
      --region "$AWS_REGION" \
      --query 'taskDefinition' \
      --output json 2>/dev/null)

    REVISION=$(echo "$TASK_DEF_JSON" | jq -r '.revision // "?"')
    IMAGE=$(echo "$TASK_DEF_JSON" | jq -r '.containerDefinitions[0].image // "unknown"')
    IMAGE_TAG=$(echo "$IMAGE" | sed 's/.*://')

    # Extract environment variables
    ENV_VARS=$(echo "$TASK_DEF_JSON" | jq -r \
      '.containerDefinitions[0].environment // [] | sort_by(.name) | .[] | "\(.name)=\(.value)"')
    ENV_VAR_COUNT=$(echo "$TASK_DEF_JSON" | jq -r '.containerDefinitions[0].environment // [] | length')

    # Detect drift conditions
    SERVICE_DRIFT="false"
    DRIFT_REASONS=()

    # Check 1: Running count matches desired count
    if [[ "$RUNNING_COUNT" != "$DESIRED_COUNT" ]]; then
      SERVICE_DRIFT="true"
      DRIFT_REASONS+=("running=${RUNNING_COUNT} != desired=${DESIRED_COUNT}")
    fi

    # Check 2: Image tag is "latest" (should be a SHA)
    if [[ "$IMAGE_TAG" == "latest" || "$IMAGE_TAG" == "dev-latest" ]]; then
      SERVICE_DRIFT="true"
      DRIFT_REASONS+=("image tag is '${IMAGE_TAG}' (expected SHA)")
    fi

    # Check 3: Essential env vars present
    EXPECTED_VARS=("PORT" "NODE_ENV" "SERVICE_NAME")
    for VAR in "${EXPECTED_VARS[@]}"; do
      if ! echo "$ENV_VARS" | grep -q "^${VAR}="; then
        SERVICE_DRIFT="true"
        DRIFT_REASONS+=("missing env var: ${VAR}")
      fi
    done

    # Check 4: Task definition revision is not 0 (should be positive)
    if [[ "$REVISION" == "0" || "$REVISION" == "?" ]]; then
      SERVICE_DRIFT="true"
      DRIFT_REASONS+=("invalid task definition revision: ${REVISION}")
    fi

    if [[ "$SERVICE_DRIFT" == "true" ]]; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      printf "${RED}%-35s | %-15s | %-12s | %-6s${NC}\n" \
        "$SERVICE_NAME" "$IMAGE_TAG" "rev:${REVISION}" "YES"
      for reason in "${DRIFT_REASONS[@]}"; do
        echo -e "  ${RED}→ ${reason}${NC}"
      done
    else
      printf "${GREEN}%-35s | %-15s | %-12s | %-6s${NC}\n" \
        "$SERVICE_NAME" "$IMAGE_TAG" "rev:${REVISION}" "NO"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
      echo "  Env vars (${ENV_VAR_COUNT}):"
      echo "$ENV_VARS" | sed 's/^/    /'
      echo ""
    fi
  else
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    printf "${RED}%-35s | %-15s | %-12s | %-6s${NC}\n" \
      "$SERVICE_NAME" "N/A" "N/A" "YES"
    echo -e "  ${RED}→ No running task definition${NC}"
  fi

  SERVICES_CHECKED=$((SERVICES_CHECKED + 1))
done

# ── Terraform state comparison (optional) ────────────────────────────────────
if [[ -n "$TF_DIR" && -d "$TF_DIR" ]]; then
  echo ""
  info "Comparing against Terraform state in ${TF_DIR}..."

  # Get expected ECR repository URLs from Terraform
  TF_ECR_URLS=$(terraform -chdir="$TF_DIR" output -json ecr_repository_urls 2>/dev/null || echo "{}")

  if [[ "$TF_ECR_URLS" != "{}" ]]; then
    for SERVICE_KEY in $(echo "$TF_ECR_URLS" | jq -r 'keys[]'); do
      EXPECTED_ECR=$(echo "$TF_ECR_URLS" | jq -r ".[\"${SERVICE_KEY}\"]")
      info "  ${SERVICE_KEY}: ECR = ${EXPECTED_ECR}"
    done
  else
    warn "  Could not read Terraform ECR outputs (state may not be initialized)"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${BOLD}  Services checked: ${SERVICES_CHECKED}${NC}"
if [[ $DRIFT_COUNT -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}Drift detected:    0 — ALL CLEAN${NC}"
  echo "════════════════════════════════════════════════════════════════"
  exit 0
else
  echo -e "  ${RED}${BOLD}Drift detected:    ${DRIFT_COUNT}${NC}"
  echo "════════════════════════════════════════════════════════════════"
  exit 1
fi
