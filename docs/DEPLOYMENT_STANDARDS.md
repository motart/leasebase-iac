# LeaseBase Deployment Standards

This document defines the authoritative deployment conventions, region policy, and guardrails for the LeaseBase platform.

## AWS Region Policy

### Runtime region: `us-west-2` (Oregon)

All ECS services, ECS clusters, ECR repositories, task definitions, ALBs, VPCs, Aurora databases, Redis clusters, SQS queues, S3 buckets, Cognito user pools, and API Gateways **must** be deployed in `us-west-2`.

### Exceptions

- **CloudFront ACM certificates** must be in `us-east-1` (AWS requirement for CloudFront).
- **Terraform remote state** S3 bucket is in `us-west-2`.

### Why us-east-1 is not allowed for ECS runtime

On 2026-02-08, early experimentation created rogue ECS resources in `us-east-1`. These were discovered and cleaned up on 2026-03-10:

- Cluster: `leasebase-dev-cluster`
- Services: `leasebase-dev-api-service`, `leasebase-dev-web-service`
- Task definitions: `leasebase-dev-api-task`, `leasebase-dev-web-task`, `leasebase-dev-api-migrate`

Root cause: manual deployments before IaC was established, combined with a misconfigured local AWS CLI default region.

## Naming Convention

All v2 resources follow: `leasebase-{env}-v2-{resource}`

Examples:
- Cluster: `leasebase-dev-v2-cluster`
- Service: `leasebase-dev-v2-bff-gateway`
- ECR repo: `leasebase-dev-v2-auth-service`
- Task family: `leasebase-dev-v2-property-service`

Tags on every resource: `App=LeaseBase`, `Env={env}`, `Stack=v2`, `ManagedBy=Terraform`

The legacy v1 naming (`leasebase-{env}-*` without `-v2-`) is retired. Do not create resources with v1 names.

## Canonical Deployment Path

### Backend microservices (monorepo)

1. **Trigger**: Push to `develop` or manual `workflow_dispatch`
2. **Workflow**: `leasebase_all/.github/workflows/dev-deploy.yml`
3. **Service config**: `services/<service>/service.yaml` (defines ECR repo, cluster, service, task family, region)
4. **Build**: `scripts/build_push.sh <service.yaml> <git_sha>`
5. **Deploy**: `scripts/deploy_ecs.sh <service.yaml> <image_uri>`

### Web frontend

1. **Trigger**: Push to `develop` or manual `workflow_dispatch`
2. **Workflow**: `leasebase-web/.github/workflows/dev-deploy.yml`
3. **Deploy config**: `deploy.dev.json` (defines ECR repo, cluster, service, task family, region)
4. **Build**: `leasebase-web/scripts/build_push.sh`
5. **Deploy**: `leasebase-web/scripts/deploy_ecs.sh`

### Infrastructure (Terraform)

1. **Code**: `leasebase-iac/envs/{env}/` + `leasebase-iac/modules/`
2. **Apply**: `make deploy-dev` or `ops/scripts/deploy-dev.sh`
3. **CI**: `leasebase-iac/.github/workflows/quality.yml` (fmt, validate, plan on PRs)

## Region Guardrails

### Script-level: `assert_region()`

All four deployment scripts contain an `assert_region()` function that validates the resolved AWS region before any AWS API call:

- `scripts/build_push.sh` (monorepo)
- `scripts/deploy_ecs.sh` (monorepo)
- `leasebase-web/scripts/build_push.sh`
- `leasebase-web/scripts/deploy_ecs.sh`

If the region is not `us-west-2`, the script exits with an error. To override (for intentional multi-region use), set:

```bash
export LEASEBASE_ALLOW_REGION=us-east-1  # or whatever region
```

### CI-level: "Verify deploy region" step

Both CI deploy workflows include a region verification step that fails the build if the AWS session region is not `us-west-2`.

### Terraform-level

The AWS provider region is set via `var.aws_region`, which defaults to `us-west-2` in every environment's `variables.tf` and is explicitly set in every `terraform.tfvars`.

## Retired Deployment Paths

### `leasebase-schema-dev/.github/workflows/deploy.yml`

**Status**: Disabled (2026-03-10). The workflow file is preserved with `if: false` for audit trail. It used v1 naming and targeted resources that no longer exist. The monorepo workflow replaces it entirely. (Repo was renamed from `leasebase-backend` to `leasebase-schema-dev` on 2026-03-10.)

### `leasebase-iac/legacy-v1/`

**Status**: Deprecated (2026-03-10). Kept as historical reference only. All `.terraform/` directories and plan files have been removed. The `terraform.tfstate` is empty. See `legacy-v1/DEPRECATED.md`.

## How to Deploy Safely

1. **Always use the canonical deployment paths** listed above.
2. **Never run `aws ecs register-task-definition` or `aws ecs update-service` manually** without `--region us-west-2`.
3. **Verify your local AWS CLI region** before any manual operations:
   ```bash
   aws configure get region  # should print us-west-2
   ```
4. **Do not create ECS resources outside us-west-2** unless explicitly documented and approved.
5. **Use the monorepo workflow** for all service deployments — do not deploy from individual service repos.
