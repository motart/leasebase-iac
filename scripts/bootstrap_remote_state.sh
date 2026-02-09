#!/usr/bin/env bash
set -euo pipefail

# Bootstrap S3 + DynamoDB backend for Terraform remote state per account/env.
#
# Usage:
#   scripts/bootstrap_remote_state.sh \
#     --profile leasebase-dev \
#     --region us-west-2 \
#     --env dev \
#     --bucket-prefix leasebase-tfstate

PROFILE=""
REGION="us-west-2"
ENV_NAME=""
BUCKET_PREFIX="leasebase-tfstate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2;;
    --region)
      REGION="$2"; shift 2;;
    --env)
      ENV_NAME="$2"; shift 2;;
    --bucket-prefix)
      BUCKET_PREFIX="$2"; shift 2;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1;;
  esac
done

if [[ -z "$PROFILE" || -z "$ENV_NAME" ]]; then
  echo "ERROR: --profile and --env are required" >&2
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text)
BUCKET_NAME="${BUCKET_PREFIX}-${ENV_NAME}-${ACCOUNT_ID}"
TABLE_NAME="terraform-locks-${ENV_NAME}"

echo "Using account: $ACCOUNT_ID"
echo "Creating/validating S3 bucket: $BUCKET_NAME in $REGION"

# us-east-1 doesn't support LocationConstraint
if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --profile "$PROFILE" \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    2>/dev/null || echo "Bucket may already exist, continuing..."
else
  aws s3api create-bucket \
    --profile "$PROFILE" \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    2>/dev/null || echo "Bucket may already exist, continuing..."
fi

aws s3api put-bucket-versioning \
  --profile "$PROFILE" \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --profile "$PROFILE" \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Creating/validating DynamoDB table: $TABLE_NAME"

if ! aws dynamodb describe-table --profile "$PROFILE" --table-name "$TABLE_NAME" >/dev/null 2>&1; then
  aws dynamodb create-table \
    --profile "$PROFILE" \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
  echo "Waiting for DynamoDB table to become ACTIVE..."
  aws dynamodb wait table-exists --profile "$PROFILE" --table-name "$TABLE_NAME"
fi

echo "Remote state backend bootstrap complete. Configure your backend as:"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  key            = \"envs/${ENV_NAME}/terraform.tfstate\""
echo "  region         = \"$REGION\""
echo "  dynamodb_table = \"$TABLE_NAME\""
