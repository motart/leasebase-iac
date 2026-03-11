# ⚠️ DEPRECATED — Legacy v1 Infrastructure

**Status**: Retired as of 2026-03-10.
**Do not run `terraform apply` from this directory.**

## What this was

The original LeaseBase infrastructure-as-code, which provisioned:
- A single ECS cluster per environment (`leasebase-{env}-cluster`)
- Two ECS services: `leasebase-{env}-api` and `leasebase-{env}-web`
- Standalone RDS PostgreSQL, ALB, VPC, etc.

## Why it was retired

The platform was re-architected to a microservices model (v2) with:
- 10+ ECS Fargate services (one per domain)
- Aurora PostgreSQL Serverless v2 + RDS Proxy
- API Gateway + CloudFront
- Per-service ECR repos, task definitions, and autoscaling
- Modular Terraform under `envs/` and `modules/`

All v2 resources use the `leasebase-{env}-v2-*` naming convention.

## What happened to the v1 AWS resources

Rogue v1 resources were found in `us-east-1` (created during early experimentation on 2026-02-08) and fully cleaned up on 2026-03-10:
- ECS cluster `leasebase-dev-cluster` — deleted
- ECS services `leasebase-dev-api-service`, `leasebase-dev-web-service` — deleted
- Task definitions `leasebase-dev-api-task`, `leasebase-dev-web-task`, `leasebase-dev-api-migrate` — deregistered

## Where to go instead

- **IaC**: `envs/dev/`, `envs/qa/`, `envs/prod/` + `modules/`
- **CI/CD**: `leasebase_all/.github/workflows/dev-deploy.yml`
- **Deploy scripts**: `leasebase_all/scripts/build_push.sh` + `deploy_ecs.sh`
- **Standards**: `docs/DEPLOYMENT_STANDARDS.md`

## Why this directory is kept

Retained as a historical reference for the migration. The `.terraform/` directories and plan files have been removed. The `terraform.tfstate` is empty.
