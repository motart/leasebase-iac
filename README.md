# LeaseBase Infrastructure as Code (v2)

Terraform-based microservices infrastructure for LeaseBase on AWS.

## Architecture

See `architecture.mmd` for the full Mermaid diagram. Key components:

- **Edge**: Route53 -> CloudFront -> (optional WAF) -> API Gateway HTTP API
- **API Layer**: API Gateway -> VPC Link -> internal ALB -> ECS Fargate services
- **Compute**: 10 ECS Fargate microservices in private subnets (no public IPs)
- **Data**: Aurora PostgreSQL Serverless v2, ElastiCache Redis, OpenSearch (optional)
- **Async**: EventBridge bus + SQS queues (notifications, document-processing, reporting)
- **Auth**: Cognito User Pool with web + mobile clients
- **Storage**: S3 documents bucket (KMS-encrypted, lifecycle policies)
- **Security**: KMS keys, Secrets Manager, least-privilege IAM, tight SGs
- **Observability**: CloudWatch dashboard, alarms, SNS topic

## Directory Structure

```
leasebase-iac/
├── modules/                  # v2 Terraform modules
│   ├── vpc/                  # VPC, subnets, NAT GWs, VPC endpoints
│   ├── kms/                  # KMS encryption keys
│   ├── alb/                  # Internal ALB
│   ├── apigw/                # API Gateway HTTP API + VPC Link
│   ├── ecs-service/          # Reusable per-service (ECR, task def, TG, autoscaling)
│   ├── rds-aurora/           # Aurora PostgreSQL Serverless v2
│   ├── redis/                # ElastiCache Redis
│   ├── opensearch/           # OpenSearch Serverless (optional)
│   ├── eventbridge/          # EventBridge custom bus
│   ├── sqs/                  # SQS queues + DLQs
│   ├── lambda-worker/        # Lambda workers (optional)
│   ├── s3-docs/              # S3 documents bucket
│   ├── cognito/              # Cognito User Pool + clients
│   ├── cloudfront/           # CloudFront distribution
│   ├── waf/                  # WAF Web ACL (optional)
│   └── observability/        # CloudWatch dashboard + alarms
├── envs/
│   ├── dev/                  # Dev (CIDR: 10.110.0.0/16)
│   ├── qa/                   # QA  (CIDR: 10.120.0.0/16)
│   ├── uat/                  # UAT (CIDR: 10.130.0.0/16)
│   └── prod/                 # Prod (CIDR: 10.140.0.0/16)
├── bootstrap/                # Remote state S3/DynamoDB
├── legacy-v1/                # Old code (reference only)
├── .github/workflows/        # CI/CD
├── architecture.mmd          # Mermaid diagram
└── Makefile
```

## Microservices

10 ECS Fargate services, each with its own ECR repo, task definition, target group, and autoscaling:

- **bff-gateway** - API composition + auth middleware (/api/*)
- **auth-service** - Auth beyond Cognito (/internal/auth/*)
- **lease-service** - Lease management (/internal/leases/*)
- **property-service** - Property management (/internal/properties/*)
- **tenant-service** - Tenant management (/internal/tenants/*)
- **maintenance-service** - Work orders (/internal/maintenance/*)
- **payments-service** - Stripe integration (/internal/payments/*)
- **notification-service** - Notifications (/internal/notifications/*)
- **document-service** - Document management (/internal/documents/*)
- **reporting-service** - Async reports (/internal/reports/*)

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI v2 with profiles for each account
- Docker (for building service images)

## Quick Start (Deploy Dev v2)

### 1. Bootstrap Remote State (first time)

```bash
make bootstrap ENV=dev
```

### 2. Configure Backend

```bash
cp envs/dev/backend.hcl.example envs/dev/backend.hcl
# Edit backend.hcl with your account ID
```

### 3. Deploy

```bash
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

### 4. View Outputs

```bash
make output ENV=dev
```

## Common Commands

```bash
make plan ENV=dev          # Plan dev changes
make apply ENV=dev         # Apply dev changes
make validate              # Validate all envs
make fmt                   # Format all TF code
make lint                  # fmt-check + validate
make clean                 # Remove .terraform dirs
```

## Naming Convention

All resources: `leasebase-{env}-v2-*`
Tags on every resource: `App=LeaseBase, Env={env}, Stack=v2, Owner=motart`

## VPC CIDRs

- dev: 10.110.0.0/16
- qa: 10.120.0.0/16
- uat: 10.130.0.0/16
- prod: 10.140.0.0/16

(v1 used 10.10-40.0.0/16 — no overlap)

## Cost Controls (Non-Prod)

- Single NAT gateway (configurable)
- Aurora Serverless v2 min 0.5 ACU
- cache.t3.micro Redis
- OpenSearch disabled by default
- WAF disabled by default
- FARGATE_SPOT default capacity provider

## Migration / Cutover Plan

1. Deploy v2 stack alongside v1 (separate VPC, separate resources)
2. Push Docker images to v2 ECR repos
3. Validate services via API Gateway endpoint
4. Switch Route53/CloudFront to point to v2 API Gateway
5. Monitor for 24-48h
6. Decommission v1 stack (terraform destroy on legacy-v1 envs)

## Rollback Plan

1. Point Route53/CloudFront back to v1 ALB
2. v2 stack remains running but unused
3. Investigate and fix v2 issues
4. Re-attempt cutover

## Seeding Demo Data

After deployment, populate realistic sample data for testing:

### Prerequisites

- Node.js 20+
- AWS credentials configured
- Network access to database (or use SSM tunneling)

### Install & Build

```bash
cd automation/seed
npm install
npm run build
```

### Run Seeder

```bash
# Seed dev environment (default)
npm run seed

# Seed specific environment
npm run seed -- --env qa

# Use explicit database URL
DATABASE_URL="postgresql://user:pass@host:5432/leasebase" npm run seed

# Seed only specific services
npm run seed -- --only property_service,tenant_service,lease_service
```

### What Gets Seeded

- 2 properties with 6 total units
- 3 tenants with profiles and employment info
- 2 active leases with rent schedules
- 3 maintenance requests (NEW, IN_PROGRESS, COMPLETED)
- 3 payment transactions (success, failed, pending)
- Notification templates and sample events
- Document metadata (lease PDF, move-in checklist)
- Report definitions with sample run

All IDs are deterministic - re-running won't create duplicates.

### Troubleshooting

If database is in private subnet:

```bash
# Option 1: SSM Port Forwarding
aws ssm start-session --target <instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds-endpoint>"],"portNumber":["5432"],"localPortNumber":["5432"]}'

# Then in another terminal:
DATABASE_URL="postgresql://user:pass@localhost:5432/leasebase" npm run seed
```

See [automation/seed/docs/SEEDING.md](automation/seed/docs/SEEDING.md) for full documentation.

## CI/CD

- **terraform-plan.yml** - Runs on PRs: fmt check, validate all envs, plan dev
- **terraform-apply.yml** - Manual dispatch: plan + apply with prod approval gate
- **docker-build-push.yml** - Build/push Docker images + trigger ECS deployment
