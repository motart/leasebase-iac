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

## Zero-to-Dev: Flawless Terraform Run From 0

This is the recommended first-time bootstrap flow for `envs/dev`. It includes the DNS/TLS checks required for a clean apply when using `app.dev.leasebase.ai`.

### 1) Bootstrap remote state (first time per account/env)

```bash
make bootstrap ENV=dev
```

### 2) Configure backend

```bash
cp envs/dev/backend.hcl.example envs/dev/backend.hcl
# Edit envs/dev/backend.hcl with the bucket/table/account values from bootstrap output
```

### 3) Create `terraform.tfvars` for dev

```bash
cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

At minimum, set these values in `envs/dev/terraform.tfvars`:

```hcl
aws_region                     = "us-west-2"
domain_name                    = "app.dev.leasebase.ai"
api_domain_name                = "api.dev.leasebase.ai"
root_domain_name               = "leasebase.ai"
old_root_domain_name           = "leasebase.co"
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:<account-id>:certificate/<certificate-id>"

# If OIDC provider already exists in the account:
create_github_oidc_provider       = false
existing_github_oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
```

Notes:
- `cloudfront_acm_certificate_arn` **must** be in `us-east-1` and in `ISSUED` status.
- `domain_name` must be set, otherwise Route53 alias creation is skipped.
- `old_root_domain_name` enables 301 redirects from `*.leasebase.co` to `leasebase.ai`.

### 4) DNS preflight (required)

Before apply, ensure there is exactly **one** public Route53 hosted zone for `leasebase.ai` in the target account:

```bash
aws route53 list-hosted-zones \
  --query "HostedZones[?Name==\`leasebase.ai.\`].[Id,Name,ResourceRecordSetCount]" \
  --output table
```

If multiple zones exist, remove duplicates before apply, or Terraform may fail with:
`multiple Route 53 Hosted Zones matched`.

Also ensure the domain registrar nameservers match the hosted zone delegation set.

### 5) Init, plan, apply (from `envs/dev`)

```bash
cd envs/dev
terraform init -reconfigure -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars -out dev.tfplan
terraform apply dev.tfplan
```

### 6) Post-apply verification

```bash
terraform output
curl -i "$(terraform output -raw api_gateway_endpoint)/health"
dig +short app.dev.leasebase.ai
```

Expected:
- ECS services become healthy (`runningCount == desiredCount`)
- API health endpoint responds
- `app.dev.leasebase.ai` resolves to CloudFront or ALB alias target

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

## Deploy Dev (Core + Automation)

A single command deploys **both** Terraform stacks to the dev environment:

1. **Core infrastructure** (`envs/dev`) — VPC, ECS, ALB, API Gateway, RDS, Redis, Cognito, CloudFront, S3, EventBridge, SQS
2. **Automation pipeline** (`automation/infra/envs/dev`) — Jira webhook API Gateway, Lambda, Secrets Manager, CloudWatch

### Prerequisites

- Terraform >= 1.6.0
- AWS CLI v2 with credentials configured (profile or env vars)
- Node.js 20+ (for Lambda build)
- Two env vars for the automation stack:
  ```bash
  export TF_VAR_webhook_secret="your-jira-shared-secret"
  export TF_VAR_github_token="$(gh auth token)"   # or a PAT with repo+workflow scope
  ```

### Local Deploy

```bash
# Option 1: Makefile (from repo root)
make deploy-dev

# Option 2: Script directly
./ops/scripts/deploy-dev.sh

# Option 3: Plan only (no apply)
make plan-dev
# or: PLAN_ONLY=true ./ops/scripts/deploy-dev.sh
```

### What Gets Deployed

| Stack | Directory | Resources |
|-------|-----------|----------|
| Core | `envs/dev` | VPC, ALB, API Gateway, 10 ECS services + ECR repos, Aurora PostgreSQL, Redis, Cognito, CloudFront, WAF, S3, EventBridge, SQS, KMS, Observability |
| Automation | `automation/infra/envs/dev` | API Gateway HTTP API, Lambda (Jira webhook handler), Secrets Manager (webhook secret + GitHub token), CloudWatch log groups, IAM roles |

### Expected Outputs

After a successful deploy, the script prints a **DEV READY** summary:

```
  Web frontend:  https://app.dev.leasebase.ai  (CloudFront: d1234567.cloudfront.net)
  API endpoint:  https://api.dev.leasebase.ai
  Webhook URL:   https://xyz789.execute-api.us-west-2.amazonaws.com/automation/jira/webhook

  CloudWatch logs:
    Lambda:       /aws/lambda/leasebase-automation-dev-jira-webhook
    API Gateway:  /aws/apigateway/leasebase-automation-dev-webhook-api
```

### Verify the Deployment

1. **Web frontend**: open `https://app.dev.leasebase.ai` (or the CloudFront domain from outputs)
2. **API health**: `curl https://<api_endpoint>/health`
3. **Lambda logs**: `aws logs tail /aws/lambda/leasebase-automation-dev-jira-webhook --follow`
4. **Test Jira webhook**:
   ```bash
   WEBHOOK_URL=$(cd automation/infra/envs/dev && terraform output -raw webhook_url)
   curl -X POST "$WEBHOOK_URL" \
     -H 'Content-Type: application/json' \
     -H 'X-LeaseBase-Webhook-Secret: {{your-secret}}' \
     -d '{"issue":{"key":"BFF-1","fields":{"summary":"Test","status":{"name":"Ready"},"project":{"key":"BFF"},"labels":[]}}}'
   ```

### GitHub Actions (One-Click Deploy)

- **[Deploy Dev](.github/workflows/deploy-dev.yml)** — `workflow_dispatch`: deploys both stacks with auto-approve
- **[Plan Dev](.github/workflows/plan-dev.yml)** — runs on PRs: fmt, validate, and plan for both stacks

Required GitHub secrets: `JIRA_WEBHOOK_SECRET`, `GH_AUTOMATION_TOKEN`
Required GitHub environment variable: `AWS_ROLE_ARN` (on the `dev` environment)

### Related Docs

- [Register Jira Webhook](automation/docs/register-jira-webhook.md)
- [GitHub Secrets Setup](automation/docs/github-secrets-setup.md)
- [Troubleshooting](automation/docs/troubleshooting.md)
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

- **plan-dev.yml** - Runs on PRs: fmt check, validate all envs + automation, plan dev (both stacks)
- **deploy-dev.yml** - Manual dispatch: deploy both stacks to dev (auto-approve)
- **terraform-apply.yml** - Manual dispatch: plan + apply with prod approval gate
- **docker-build-push.yml** - Build/push Docker images + trigger ECS deployment
