# =============================================================================
# LeaseBase Ops — Unified deploy and plan targets
# =============================================================================
.PHONY: help deploy-dev plan-dev validate-all fmt fmt-check

REPO_ROOT := $(shell cd .. && pwd)
SCRIPTS   := $(REPO_ROOT)/ops/scripts

help:
	@echo "LeaseBase Ops"
	@echo "============="
	@echo ""
	@echo "Targets:"
	@echo "  deploy-dev     Deploy core + automation stacks to dev (auto-approve)"
	@echo "  plan-dev       Plan only (no apply) for both stacks"
	@echo "  validate-all   Validate all environments + automation"
	@echo "  fmt            Format all Terraform code"
	@echo "  fmt-check      Check formatting (CI mode)"
	@echo ""
	@echo "Required env vars for deploy-dev:"
	@echo "  TF_VAR_webhook_secret  — Jira webhook shared secret"
	@echo "  TF_VAR_github_token    — GitHub PAT for workflow dispatch"
	@echo ""
	@echo "Optional env vars:"
	@echo "  AWS_REGION    — defaults to us-west-2"
	@echo "  AWS_PROFILE   — if using named profiles"

deploy-dev:
	@bash $(SCRIPTS)/deploy-dev.sh

plan-dev:
	@PLAN_ONLY=true bash $(SCRIPTS)/deploy-dev.sh

validate-all:
	@echo "Validating core environments..."
	@for env in dev qa uat prod; do \
		if [ -d "$(REPO_ROOT)/envs/$$env" ]; then \
			echo "  Validating envs/$$env ..."; \
			(cd $(REPO_ROOT)/envs/$$env && terraform init -backend=false -input=false >/dev/null 2>&1 && terraform validate) || exit 1; \
		fi; \
	done
	@echo "Validating automation environments..."
	@for env in dev prod; do \
		if [ -d "$(REPO_ROOT)/automation/infra/envs/$$env" ]; then \
			echo "  Validating automation/infra/envs/$$env ..."; \
			(cd $(REPO_ROOT)/automation/infra/envs/$$env && terraform init -backend=false -input=false >/dev/null 2>&1 && terraform validate) || exit 1; \
		fi; \
	done
	@echo "All environments validated."

fmt:
	@cd $(REPO_ROOT) && terraform fmt -recursive
	@echo "Formatted."

fmt-check:
	@cd $(REPO_ROOT) && terraform fmt -check -recursive
