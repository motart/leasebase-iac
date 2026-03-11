#!/usr/bin/env bash
# =============================================================================
# run-schema-init.sh — Execute schema-init.sql against a LeaseBase environment
#
# Reads the service inventory from `terraform output -json service_db_config`
# (single canonical source — no duplicated service list).
#
# Usage:
#   ./scripts/run-schema-init.sh --env dev
#   ./scripts/run-schema-init.sh --env dev --plan   # dry-run: show what would run
#
# Required:
#   - AWS CLI configured with appropriate credentials
#   - psql available on PATH
#   - Terraform state accessible for the target environment
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
ENV=""
PLAN_ONLY="false"
DB_NAME="leasebase"
DB_USER="leasebase_admin"
AWS_REGION="${AWS_DEFAULT_REGION:-us-west-2}"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)    ENV="$2"; shift 2 ;;
    --plan)   PLAN_ONLY="true"; shift ;;
    --db)     DB_NAME="$2"; shift 2 ;;
    --user)   DB_USER="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    *)        echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$ENV" ]]; then
  echo "ERROR: --env is required (dev|qa|uat|prod)"
  exit 1
fi

ENV_DIR="$REPO_ROOT/envs/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  echo "ERROR: Environment directory not found: $ENV_DIR"
  exit 1
fi

echo "=== LeaseBase schema-init: env=$ENV ==="

# ── 1. Read service inventory from Terraform ──────────────────────────────────
echo "Reading service_db_config from Terraform state..."
SERVICE_DB_CONFIG=$(terraform -chdir="$ENV_DIR" output -json service_db_config 2>/dev/null || echo "{}")

if [[ "$SERVICE_DB_CONFIG" == "{}" ]]; then
  echo "ERROR: Could not read service_db_config from Terraform. Is the state initialized?"
  exit 1
fi

# Read secret names from Terraform output
SECRET_NAMES=$(terraform -chdir="$ENV_DIR" output -json service_secret_names 2>/dev/null || echo "{}")

# Read the proxy endpoint for the DB host
DB_HOST=$(terraform -chdir="$ENV_DIR" output -raw proxy_endpoint 2>/dev/null || echo "")
if [[ -z "$DB_HOST" ]]; then
  echo "ERROR: Could not read proxy_endpoint from Terraform."
  exit 1
fi

# ── 2. Fetch passwords from Secrets Manager ───────────────────────────────────
echo "Fetching service passwords from Secrets Manager..."

# Extract DB-using services from the config
DB_SERVICES=$(echo "$SERVICE_DB_CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
for k, v in config.items():
    if v.get('needs_db', False):
        print(k)
")

PSQL_VARS=""

for svc in $DB_SERVICES; do
  secret_name=$(echo "$SECRET_NAMES" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$svc',''))")
  if [[ -z "$secret_name" ]]; then
    echo "  WARN: No secret name found for $svc, skipping"
    continue
  fi

  pw=$(aws secretsmanager get-secret-value \
    --region "$AWS_REGION" \
    --secret-id "$secret_name" \
    --query 'SecretString' --output text 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])" 2>/dev/null || echo "")

  if [[ -z "$pw" ]]; then
    echo "  WARN: Could not fetch password for $svc ($secret_name)"
    continue
  fi

  echo "  ✓ $svc"
  PSQL_VARS="$PSQL_VARS -v ${svc}_pw='$pw'"
done

# ── 3. Run schema-init.sql ────────────────────────────────────────────────────
SQL_FILE="$SCRIPT_DIR/schema-init.sql"
if [[ ! -f "$SQL_FILE" ]]; then
  echo "ERROR: $SQL_FILE not found"
  exit 1
fi

if [[ "$PLAN_ONLY" == "true" ]]; then
  echo ""
  echo "=== DRY RUN (--plan) ==="
  echo "Would execute:"
  echo "  psql -h $DB_HOST -U $DB_USER -d $DB_NAME $PSQL_VARS -f $SQL_FILE"
  echo ""
  echo "Services: $(echo $DB_SERVICES | tr '\n' ' ')"
  exit 0
fi

echo ""
echo "Executing schema-init.sql against $DB_HOST..."
eval psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" $PSQL_VARS -f "$SQL_FILE"

echo ""
echo "=== schema-init complete ==="

# ── 4. Quick verification ─────────────────────────────────────────────────────
echo ""
echo "Verifying roles and schemas..."
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT rolname FROM pg_roles
  WHERE rolname IN (
    'property_user','lease_user','tenant_user','payments_user',
    'maintenance_user','notification_user','document_user','reporting_user',
    'bff_user','auth_user'
  )
  ORDER BY rolname;
"

psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT schema_name FROM information_schema.schemata
  WHERE schema_name IN (
    'property_service','lease_service','tenant_service','payments_service',
    'maintenance_service','notification_service','document_service','reporting_service'
  )
  ORDER BY schema_name;
"

echo "=== verification complete ==="
