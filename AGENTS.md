# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project overview

This repository contains Terraform-based infrastructure-as-code and CI/CD configuration for deploying the Leasebase application into multiple AWS accounts/environments (`dev`, `qa`, `uat`, `prod`). The primary application region is `us-west-2`; CloudFront and web TLS certificates live in `us-east-1`. See `README.md` and `docs/` for narrative documentation.

High-level architecture (as implemented in Terraform):
- **Single reusable Terraform module** under `envs/common` defines the shared stack:
  - VPC, public subnets, internet gateway, and public route table.
  - Security groups for ALB, ECS services, and RDS.
  - RDS PostgreSQL instance for the backend.
  - Application Load Balancer (ALB) fronting the API.
  - ECS Fargate cluster, task definition, and service for the API.
  - S3 bucket + website configuration and CloudFront distribution for the web frontend.
  - Outputs exposing VPC, subnets, RDS endpoint, ALB DNS, ECS cluster/service, web bucket, and CloudFront domain.
- **Environment-specific roots** in `envs/dev`, `envs/qa`, and `envs/prod`:
  - Each folder defines its own `provider "aws"` and `variables.tf` with env-specific defaults (CIDR ranges, DB sizes, ECS capacity, etc.).
  - Each root instantiates the `../common` module with `environment` fixed to that env and wires all variables through.
  - Each env defines minimal outputs that re-expose key values from the common module.
- **Bootstrap and operations docs** in `docs/`:
  - `ACCOUNT_BOOTSTRAP.md` – how to prepare each AWS account (remote state S3/Dynamo, GitHub OIDC roles, DNS ownership patterns).
  - `DEPLOYMENT.md` – CI/CD model via GitHub Actions, plus how to run Terraform locally per environment.
  - `DNS_AND_CERTS.md` – DNS/Route53 options and ACM certificate layout for API and web endpoints.
- **Remote state bootstrap script** in `scripts/bootstrap_remote_state.sh` creates the S3 bucket + DynamoDB table per account/env and prints the backend configuration to plug into your Terraform backends.
- **GitHub Actions quality workflow** in `.github/workflows/quality.yml` enforces Terraform fmt/validate (and a dev plan) on pull requests against `main`. Additional deploy workflows (`deploy-*.yml`) are described in `docs/DEPLOYMENT.md` even if not all are present in this snapshot.

When extending the infrastructure for new services or environments, prefer to:
- Add new variables/outputs in `envs/common` so the shared module remains the single source of truth.
- Keep environment-specific differences (capacity, instance sizes, deletion protection) in the env roots’ `variables.tf` and tfvars files.

## Common commands

All commands assume you are in the repo root (`leasebase-iac`) unless stated otherwise.

### Prerequisites

- Terraform **1.6+** installed.
- AWS CLI v2 installed and configured with profiles that can assume admin in each Leasebase account (`leasebase-dev`, `leasebase-qa`, `leasebase-uat`, `leasebase-prod`).

### 1. Bootstrap remote state for an account/env

Use the helper script to create the S3 bucket and DynamoDB table used by Terraform backends:

```bash path=null start=null
scripts/bootstrap_remote_state.sh \
  --profile leasebase-dev \
  --region us-west-2 \
  --env dev \
  --bucket-prefix leasebase-tfstate
```

Repeat for `qa`, `uat`, and `prod` with the appropriate `--profile` and `--env`. The script prints the `bucket`, `key`, `region`, and `dynamodb_table` values you should plug into each env’s backend configuration.

### 2. Format Terraform code

From the repo root, run recursive fmt (this matches the CI "Terraform fmt" step):

```bash path=null start=null
terraform fmt -recursive
```

To run the same check locally that CI uses (non-mutating):

```bash path=null start=null
terraform fmt -check -recursive
```

### 3. Validate Terraform for a single environment ("single test")

To validate only one environment (e.g. `dev`) without contacting a remote backend:

```bash path=null start=null
cd envs/dev
terraform init -backend=false
terraform validate
```

Replace `dev` with `qa` or `prod` as needed. This mirrors the loop in `.github/workflows/quality.yml`.

### 4. Validate all environments (as CI does)

To reproduce the CI validation loop locally from the repo root:

```bash path=null start=null
for d in envs/dev envs/qa envs/uat envs/prod; do
  if [ -d "$d" ]; then
    echo "Validating $d";
    (cd "$d" && terraform init -backend=false && terraform validate);
  fi
done
```

This is robust to environments that are not yet present (e.g. if `envs/uat` has not been created).

### 5. Plan and apply for a specific environment (local workflow)

Assuming backend configuration is set up for the environment and you have a real tfvars file (copied from the `*.tfvars.example` mentioned in `docs/DEPLOYMENT.md`):

```bash path=null start=null
cd envs/dev
terraform init
terraform plan -var-file="dev.tfvars" -out dev.plan
terraform apply dev.plan
```

Swap `dev` for `qa` or `prod` and use the corresponding tfvars file (`qa.tfvars`, `prod.tfvars`).

If you only want to inspect a plan without touching state (as in CI), you can add `-backend=false` to `terraform init` and point at the `*.tfvars.example` file instead.

## Terraform layout and extension points

### Environments and shared module

- `envs/common` acts as a reusable module that encapsulates the full Leasebase stack: networking, RDS, ECS, ALB, and web hosting.
- `envs/dev`, `envs/qa`, and `envs/prod` are thin roots that:
  - Configure the AWS provider (region + credentials via profile or env vars).
  - Declare environment-specific variables and sane defaults for capacity and sizing.
  - Instantiate the common module and pass through all variables.
  - Re-export a small set of outputs (ALB DNS, CloudFront domain).

When introducing new infrastructure that should exist in every environment (e.g. additional ECS services, queues, or buckets):
- Add resources and variables in `envs/common`.
- Update each env root to set any env-specific values via `variables.tf` and tfvars.

### Remote state and account setup

- Remote state per account/env is expected to use S3 + DynamoDB, with names derived from env and account ID (see `scripts/bootstrap_remote_state.sh` and `docs/ACCOUNT_BOOTSTRAP.md`).
- GitHub OIDC and IAM roles for CI/CD are described in `docs/ACCOUNT_BOOTSTRAP.md` and are intended to be managed via Terraform modules (e.g. a `gha_oidc` module) even if those modules are not present in this snapshot.

### DNS, TLS, and endpoints

Conceptually (per `docs/DNS_AND_CERTS.md`):
- Web frontends are served via CloudFront using ACM certificates in `us-east-1` for `dev.leasebase.io`, `qa.leasebase.io`, `uat.leasebase.io`, and `leasebase.io`.
- APIs are fronted by an ALB in `us-west-2` with ACM certificates for `api.<env>.leasebase.io`.
- Route53 hosted zone ownership can be either:
  - In the prod account (non-prod envs share the same zone), or
  - In a shared DNS account, with Terraform using an `aws.dns` provider alias.

While the current `envs/common` code uses CloudFront with the default certificate and does not explicitly manage Route53, the docs describe the intended model and submodules (e.g. `modules/route53-acm/*`) for a more complete DNS + ACM setup.

### CI/CD expectations

- `.github/workflows/quality.yml` is the authoritative reference for repo-wide quality checks (fmt, validate, and a dev plan).
- `docs/DEPLOYMENT.md` documents additional GitHub Actions workflows (`deploy-dev.yml`, `deploy-qa.yml`, `deploy-uat.yml`, `deploy-prod.yml`) that:
  - Assume per-environment IAM roles via GitHub OIDC.
  - Build and push Docker images for `leasebase-api` and `leasebase-web` from their respective repos.
  - Run Terraform `init/plan/apply` in the relevant `envs/<env>` folder.
  - Trigger Prisma DB migrations via an ECS one-off task.

When editing or adding workflows, keep behavior consistent with these docs so that environments remain deployable both via CI and via local Terraform.
