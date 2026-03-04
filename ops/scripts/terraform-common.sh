#!/usr/bin/env bash
# =============================================================================
# terraform-common.sh — shared helpers for LeaseBase deploy scripts
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (disabled when not a TTY, e.g. CI)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}══════════════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}  $*${NC}"; echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}\n"; }

# ---------------------------------------------------------------------------
# die — print error and exit
# ---------------------------------------------------------------------------
die() {
  fail "$@"
  exit 1
}

# ---------------------------------------------------------------------------
# require_var — check a single env var is set (never prints the value)
# ---------------------------------------------------------------------------
require_var() {
  local var_name="$1"
  local description="${2:-}"
  if [[ -z "${!var_name:-}" ]]; then
    fail "Missing required env var: ${var_name}"
    [[ -n "$description" ]] && fail "  → $description"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# check_required_vars — validate a set of vars, report ALL missing at once
#   Usage: check_required_vars "VAR1:description" "VAR2:description" ...
# ---------------------------------------------------------------------------
check_required_vars() {
  local missing=0
  for entry in "$@"; do
    local var_name="${entry%%:*}"
    local desc="${entry#*:}"
    if ! require_var "$var_name" "$desc" 2>/dev/null; then
      fail "Missing: ${var_name} — ${desc}"
      missing=$((missing + 1))
    fi
  done
  if [[ $missing -gt 0 ]]; then
    die "$missing required variable(s) not set. See above."
  fi
}

# ---------------------------------------------------------------------------
# tf_init — terraform init with optional backend config
#   Usage: tf_init /path/to/env [backend.hcl]
# ---------------------------------------------------------------------------
tf_init() {
  local dir="$1"
  local backend_config="${2:-}"
  info "terraform init in ${dir} ..."
  if [[ -n "$backend_config" && -f "${dir}/${backend_config}" ]]; then
    terraform -chdir="$dir" init -input=false -backend-config="$backend_config"
  else
    terraform -chdir="$dir" init -input=false
  fi
}

# ---------------------------------------------------------------------------
# tf_validate — terraform validate
# ---------------------------------------------------------------------------
tf_validate() {
  local dir="$1"
  info "terraform validate in ${dir} ..."
  terraform -chdir="$dir" validate
}

# ---------------------------------------------------------------------------
# tf_plan — terraform plan, save plan file
# ---------------------------------------------------------------------------
tf_plan() {
  local dir="$1"
  local plan_file="${2:-tfplan}"
  info "terraform plan in ${dir} ..."
  terraform -chdir="$dir" plan -input=false -out="$plan_file"
}

# ---------------------------------------------------------------------------
# tf_apply — terraform apply (auto-approve for dev, interactive otherwise)
# ---------------------------------------------------------------------------
tf_apply() {
  local dir="$1"
  local env="${2:-dev}"
  local plan_file="${3:-tfplan}"

  if [[ "$env" == "dev" ]]; then
    info "terraform apply (auto-approve) in ${dir} ..."
    terraform -chdir="$dir" apply -input=false -auto-approve "$plan_file"
  else
    warn "Non-dev environment: manual approval required."
    terraform -chdir="$dir" apply -input=false "$plan_file"
  fi
}

# ---------------------------------------------------------------------------
# tf_output_safe — print a terraform output (skip sensitive)
# ---------------------------------------------------------------------------
tf_output_safe() {
  local dir="$1"
  local key="$2"
  local value
  value=$(terraform -chdir="$dir" output -raw "$key" 2>/dev/null) || true
  if [[ -n "$value" ]]; then
    echo "  $key = $value"
  fi
}

# ---------------------------------------------------------------------------
# tf_fmt_check — best-effort format check (non-fatal)
# ---------------------------------------------------------------------------
tf_fmt_check() {
  info "Running terraform fmt -check -recursive ..."
  if ! terraform fmt -check -recursive >/dev/null 2>&1; then
    warn "Formatting issues found. Run: terraform fmt -recursive"
  else
    ok "Terraform formatting OK."
  fi
}

# ---------------------------------------------------------------------------
# check_terraform — verify terraform is installed
# ---------------------------------------------------------------------------
check_terraform() {
  if ! command -v terraform &>/dev/null; then
    die "terraform not found. Install Terraform >= 1.6: https://developer.hashicorp.com/terraform/downloads"
  fi
  local ver
  ver=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | head -1)
  info "Terraform version: ${ver}"
}

# ---------------------------------------------------------------------------
# check_aws — verify AWS credentials work
# ---------------------------------------------------------------------------
check_aws() {
  if ! command -v aws &>/dev/null; then
    die "aws CLI not found. Install AWS CLI v2."
  fi
  info "Verifying AWS identity ..."
  local identity
  identity=$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null) || die "AWS credentials not configured or expired."
  ok "AWS identity: ${identity}"
}
