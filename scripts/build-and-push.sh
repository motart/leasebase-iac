#!/usr/bin/env bash
set -euo pipefail

# Build and push Docker images to ECR for Leasebase API and Web.
#
# Usage:
#   scripts/build-and-push.sh \
#     --profile iamadmin-master \
#     --region us-east-1 \
#     --env dev \
#     [--api-only | --web-only] \
#     [--tag latest]

PROFILE=""
REGION="us-east-1"
ENV_NAME=""
TAG="latest"
BUILD_API=true
BUILD_WEB=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LEASEBASE_ROOT="$(dirname "$ROOT_DIR")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"; shift 2;;
    --region)
      REGION="$2"; shift 2;;
    --env)
      ENV_NAME="$2"; shift 2;;
    --tag)
      TAG="$2"; shift 2;;
    --api-only)
      BUILD_WEB=false; shift;;
    --web-only)
      BUILD_API=false; shift;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1;;
  esac
done

if [[ -z "$PROFILE" || -z "$ENV_NAME" ]]; then
  echo "ERROR: --profile and --env are required" >&2
  echo "Usage: $0 --profile <aws-profile> --env <dev|qa|prod> [--tag <image-tag>]" >&2
  exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "========================================"
echo "Leasebase Docker Build & Push"
echo "========================================"
echo "Profile:    $PROFILE"
echo "Account:    $ACCOUNT_ID"
echo "Region:     $REGION"
echo "Environment: $ENV_NAME"
echo "Tag:        $TAG"
echo "ECR Base:   $ECR_BASE"
echo "========================================"

# Authenticate Docker to ECR
echo ""
echo "Authenticating Docker to ECR..."
aws ecr get-login-password --profile "$PROFILE" --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

# Build and push API
if [[ "$BUILD_API" == "true" ]]; then
  API_REPO="leasebase-${ENV_NAME}-api"
  API_IMAGE="${ECR_BASE}/${API_REPO}:${TAG}"
  API_DIR="${LEASEBASE_ROOT}/leasebase"

  echo ""
  echo "========================================"
  echo "Building API image: $API_IMAGE"
  echo "========================================"

  if [[ ! -d "$API_DIR" ]]; then
    echo "ERROR: API directory not found at $API_DIR" >&2
    exit 1
  fi

  # Check if Dockerfile exists, if not create a default one
  if [[ ! -f "${API_DIR}/Dockerfile" ]]; then
    echo "Creating default Dockerfile for API..."
    cat > "${API_DIR}/Dockerfile" << 'DOCKERFILE'
# Multi-stage Dockerfile for Leasebase API (NestJS + Prisma)

# 1) Builder stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache libc6-compat openssl

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/

# Install all dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build the NestJS application
RUN npm run build

# 2) Production stage
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000

# Install runtime dependencies
RUN apk add --no-cache libc6-compat openssl

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

# Copy built application
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/prisma ./prisma

# Switch to non-root user
USER nestjs

EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/healthz || exit 1

# Start the application
CMD ["node", "dist/main.js"]
DOCKERFILE
  fi

  docker build -t "$API_IMAGE" "$API_DIR"
  docker push "$API_IMAGE"

  echo "API image pushed: $API_IMAGE"
fi

# Build and push Web
if [[ "$BUILD_WEB" == "true" ]]; then
  WEB_REPO="leasebase-${ENV_NAME}-web"
  WEB_IMAGE="${ECR_BASE}/${WEB_REPO}:${TAG}"
  WEB_DIR="${LEASEBASE_ROOT}/leasebase-web"

  echo ""
  echo "========================================"
  echo "Building Web image: $WEB_IMAGE"
  echo "========================================"

  if [[ ! -d "$WEB_DIR" ]]; then
    echo "ERROR: Web directory not found at $WEB_DIR" >&2
    exit 1
  fi

  if [[ ! -f "${WEB_DIR}/Dockerfile" ]]; then
    echo "ERROR: Dockerfile not found at ${WEB_DIR}/Dockerfile" >&2
    exit 1
  fi

  docker build -t "$WEB_IMAGE" "$WEB_DIR"
  docker push "$WEB_IMAGE"

  echo "Web image pushed: $WEB_IMAGE"
fi

echo ""
echo "========================================"
echo "Build and push complete!"
echo "========================================"
if [[ "$BUILD_API" == "true" ]]; then
  echo "API:  ${ECR_BASE}/leasebase-${ENV_NAME}-api:${TAG}"
fi
if [[ "$BUILD_WEB" == "true" ]]; then
  echo "Web:  ${ECR_BASE}/leasebase-${ENV_NAME}-web:${TAG}"
fi
