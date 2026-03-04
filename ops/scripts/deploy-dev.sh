#!/usr/bin/env bash
# =============================================================================
# deploy-dev.sh — Deploy BOTH LeaseBase stacks to the dev environment
#
# Stacks (applied in order):
#   1. Core infrastructure   (envs/dev)
#   2. Automation pipeline   (automation/infra/envs/dev)
#
# Usage:
#   export TF_VAR_webhook_secret="your-jira-shared-secret"
#   export TF_VAR_github_token="ghp_..."
#   ./ops/scripts/deploy-dev.sh
#
# Optional env vars:
#   AWS_REGION    — defaults to us-west-2
#   AWS_PROFILE   — if using named profiles
#   PLAN_ONLY     — set to "true" to plan without applying
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=terraform-common.sh
source "$SCRIPT_DIR/terraform-common.sh"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
CORE_DIR="$REPO_ROOT/envs/dev"
AUTO_DIR="$REPO_ROOT/automation/infra/envs/dev"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
export AWS_REGION="${AWS_REGION:-us-west-2}"
PLAN_ONLY="${PLAN_ONLY:-false}"

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
header "Preflight checks"

check_terraform
check_aws

# Core stack env vars: all have defaults in variables.tf, no required env vars.
# Automation stack requires two sensitive vars:
check_required_vars \
  "TF_VAR_webhook_secret:Shared secret for Jira webhook header validation (export TF_VAR_webhook_secret=...)" \
  "TF_VAR_github_token:GitHub PAT for dispatching Actions workflows (export TF_VAR_github_token=...)"

ok "All required variables set."

# ---------------------------------------------------------------------------
# Best-effort formatting check
# ---------------------------------------------------------------------------
header "Format check"
(cd "$REPO_ROOT" && tf_fmt_check)

# ===========================================================================
# STACK 1: Core Infrastructure (envs/dev)
# ===========================================================================
header "Stack 1/2: Core Infrastructure (envs/dev)"

# Check for backend.hcl — required for remote state
if [[ -f "$CORE_DIR/backend.hcl" ]]; then
  tf_init "$CORE_DIR" "backend.hcl"
else
  warn "No backend.hcl found — initializing without remote backend."
  warn "For remote state, copy envs/dev/backend.hcl.example → backend.hcl"
  terraform -chdir="$CORE_DIR" init -input=false -backend=false
fi

tf_validate "$CORE_DIR"
tf_plan "$CORE_DIR" "dev-core.tfplan"

if [[ "$PLAN_ONLY" == "true" ]]; then
  ok "Core stack plan complete (PLAN_ONLY=true, skipping apply)."
else
  tf_apply "$CORE_DIR" "dev" "dev-core.tfplan"
  ok "Core stack applied."
fi

# Print core outputs
info "Core stack outputs:"
for key in alb_dns_name api_endpoint cloudfront_domain \
           cognito_user_pool_id cognito_web_client_id cognito_mobile_client_id \
           documents_bucket ecs_cluster_name event_bus_name vpc_id; do
  tf_output_safe "$CORE_DIR" "$key"
done

# ECR repos (map output)
info "ECR repository URLs:"
terraform -chdir="$CORE_DIR" output -json ecr_repository_urls 2>/dev/null \
  | grep -oP '"[^"]+": "[^"]+"' \
  | sed 's/^/  /' || true

# ===========================================================================
# STACK 2: Automation Pipeline (automation/infra/envs/dev)
# ===========================================================================
header "Stack 2/2: Automation Pipeline (automation/infra/envs/dev)"

# Build Lambda if source exists
LAMBDA_DIR="$REPO_ROOT/automation/lambda"
LAMBDA_DIST="$LAMBDA_DIR/dist"
if [[ -f "$LAMBDA_DIR/package.json" ]]; then
  if [[ ! -d "$LAMBDA_DIST" ]] || [[ "$LAMBDA_DIR/src/index.ts" -nt "$LAMBDA_DIST/index.js" ]]; then
    info "Building Lambda bundle ..."
    (cd "$LAMBDA_DIR" && npm ci --ignore-scripts 2>/dev/null && npm run build 2>/dev/null) || {
      warn "Lambda build failed — if dist/ already exists, continuing anyway."
    }
  else
    info "Lambda dist/ is up to date, skipping build."
  fi
fi

if [[ ! -d "$LAMBDA_DIST" ]]; then
  warn "Lambda dist/ not found at $LAMBDA_DIST."
  warn "Build it first: cd automation/lambda && npm install && npm run build"
  warn "Continuing — Terraform may fail if the Lambda source is required."
fi

tf_init "$AUTO_DIR"
tf_validate "$AUTO_DIR"
tf_plan "$AUTO_DIR" "dev-automation.tfplan"

if [[ "$PLAN_ONLY" == "true" ]]; then
  ok "Automation stack plan complete (PLAN_ONLY=true, skipping apply)."
else
  tf_apply "$AUTO_DIR" "dev" "dev-automation.tfplan"
  ok "Automation stack applied."
fi

# Print automation outputs
info "Automation stack outputs:"
for key in webhook_url api_endpoint lambda_function_name lambda_log_group; do
  tf_output_safe "$AUTO_DIR" "$key"
done

# ===========================================================================
# Summary
# ===========================================================================
header "DEV READY"

WEBHOOK_URL=$(terraform -chdir="$AUTO_DIR" output -raw webhook_url 2>/dev/null || echo "(not available — run apply first)")
CF_DOMAIN=$(terraform -chdir="$CORE_DIR" output -raw cloudfront_domain 2>/dev/null || echo "(not available)")
API_ENDPOINT=$(terraform -chdir="$CORE_DIR" output -raw api_endpoint 2>/dev/null || echo "(not available)")
LAMBDA_LOG=$(terraform -chdir="$AUTO_DIR" output -raw lambda_log_group 2>/dev/null || echo "/aws/lambda/leasebase-automation-dev-jira-webhook")

echo -e "  ${BOLD}Web frontend${NC}:  https://dev.leasebase.co  (CloudFront: ${CF_DOMAIN})"
echo -e "  ${BOLD}API endpoint${NC}:  ${API_ENDPOINT}"
echo -e "  ${BOLD}Webhook URL${NC}:   ${WEBHOOK_URL}"
echo -e ""
echo -e "  ${BOLD}CloudWatch logs${NC}:"
echo -e "    Lambda:      ${LAMBDA_LOG}"
echo -e "    API Gateway:  /aws/apigateway/leasebase-automation-dev-webhook-api"
echo -e ""
echo -e "  ${BOLD}Next steps${NC}:"
echo -e "    1. Register the webhook URL in Jira:"
echo -e "       → see automation/docs/register-jira-webhook.md"
echo -e "    2. Set up GitHub secrets in each microservice repo:"
echo -e "       → see automation/docs/github-secrets-setup.md"
echo -e "    3. Test with a curl:"
echo -e "       curl -X POST \"\${WEBHOOK_URL}\" \\"
echo -e "         -H 'Content-Type: application/json' \\"
echo -e "         -H 'X-LeaseBase-Webhook-Secret: {{your-secret}}' \\"
echo -e "         -d '{\"issue\":{\"key\":\"BFF-1\",\"fields\":{\"summary\":\"Test\",\"status\":{\"name\":\"Ready\"},\"project\":{\"key\":\"BFF\"},\"labels\":[]}}}'"
echo ""

if [[ "$PLAN_ONLY" == "true" ]]; then
  ok "Plan-only run complete. No changes were applied."
else
  ok "All stacks deployed. Dev environment is ready."
fi
