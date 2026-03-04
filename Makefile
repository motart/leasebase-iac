# LeaseBase IaC v2 - Makefile
# ============================

.PHONY: help init plan apply destroy validate fmt fmt-check clean output lint bootstrap

ENV ?=
ENV_DIR = envs/$(ENV)

help:
	@echo "LeaseBase IaC v2"
	@echo "================"
	@echo ""
	@echo "Usage: make <target> ENV=<dev|qa|uat|prod>"
	@echo ""
	@echo "Targets:"
	@echo "  init       Initialize Terraform for environment"
	@echo "  plan       Plan infrastructure changes"
	@echo "  apply      Apply infrastructure changes"
	@echo "  destroy    Destroy infrastructure (with safety)"
	@echo "  output     Show Terraform outputs"
	@echo "  validate   Validate all environments"
	@echo "  fmt        Format all Terraform code"
	@echo "  fmt-check  Check formatting (CI mode)"
	@echo "  clean      Remove .terraform directories"
	@echo "  bootstrap  Bootstrap remote state backend"

check-env:
ifndef ENV
	$(error ENV is required. Usage: make <target> ENV=dev|qa|uat|prod)
endif
ifeq ($(filter $(ENV),dev qa uat prod),)
	$(error ENV must be one of: dev, qa, uat, prod)
endif

bootstrap: check-env
	@echo "Bootstrapping remote state for $(ENV)..."
	@cd bootstrap && terraform init && terraform apply -var="environment=$(ENV)"

init: check-env
	@echo "Initializing $(ENV)..."
	@if [ ! -f "$(ENV_DIR)/backend.hcl" ]; then \
		echo "ERROR: $(ENV_DIR)/backend.hcl not found."; \
		echo "Copy $(ENV_DIR)/backend.hcl.example and fill in values."; \
		exit 1; \
	fi
	@cd $(ENV_DIR) && terraform init -backend-config=backend.hcl

plan: check-env
	@echo "Planning $(ENV)..."
	@cd $(ENV_DIR) && terraform plan -out=$(ENV).tfplan

apply: check-env
	@echo "Applying $(ENV)..."
	@if [ "$(ENV)" = "prod" ]; then \
		echo ""; \
		echo "WARNING: PRODUCTION deployment!"; \
		read -p "Type 'prod' to confirm: " confirm && [ "$$confirm" = "prod" ] || exit 1; \
	fi
	@if [ -f "$(ENV_DIR)/$(ENV).tfplan" ]; then \
		cd $(ENV_DIR) && terraform apply $(ENV).tfplan; \
	else \
		cd $(ENV_DIR) && terraform apply; \
	fi

destroy: check-env
	@echo "Destroying $(ENV)..."
	@if [ "$(ENV)" = "prod" ]; then \
		echo "BLOCKED: Cannot destroy prod from Makefile."; \
		exit 1; \
	fi
	@read -p "Type '$(ENV)' to confirm destroy: " confirm && [ "$$confirm" = "$(ENV)" ] || exit 1
	@cd $(ENV_DIR) && terraform destroy

output: check-env
	@cd $(ENV_DIR) && terraform output

validate:
	@echo "Validating all environments..."
	@for env in dev qa uat prod; do \
		if [ -d "envs/$$env" ]; then \
			echo "Validating $$env..."; \
			(cd envs/$$env && terraform init -backend=false && terraform validate) || exit 1; \
		fi; \
	done
	@echo "All environments validated."

validate-env: check-env
	@cd $(ENV_DIR) && terraform init -backend=false && terraform validate

fmt:
	@terraform fmt -recursive
	@echo "Formatted."

fmt-check:
	@terraform fmt -check -recursive

clean:
	@find . -type d -name ".terraform" -not -path "*/legacy-v1/*" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -not -path "*/legacy-v1/*" -delete 2>/dev/null || true
	@echo "Cleaned."

lint: fmt-check validate

# ---------------------------------------------------------------------------
# Unified dev deploy (core + automation)
# ---------------------------------------------------------------------------

deploy-dev:
	@bash ops/scripts/deploy-dev.sh

plan-dev:
	@PLAN_ONLY=true bash ops/scripts/deploy-dev.sh
