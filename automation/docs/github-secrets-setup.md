# GitHub Secrets Setup

Each microservice repo needs these GitHub Actions secrets configured for the AI automation workflows.

## Required Secrets

| Secret Name | Description | Where to get it |
|---|---|---|
| `JIRA_BASE_URL` | Jira instance URL | `https://leasebase.atlassian.net` |
| `JIRA_EMAIL` | Jira API user email | Your Atlassian account email |
| `JIRA_API_TOKEN` | Jira API token | [Create at](https://id.atlassian.com/manage-profile/security/api-tokens) |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key | [Anthropic Console](https://console.anthropic.com/) |
| `GH_PAT` | GitHub PAT (repo + workflow scope) | [GitHub Settings → Tokens](https://github.com/settings/tokens) |

## Optional Secrets

| Secret Name | Description | Default |
|---|---|---|
| `ANTHROPIC_MODEL` | Claude model to use | `claude-sonnet-4-20250514` |

## Setup via gh CLI (recommended)

Run this for each microservice repo:

```bash
REPOS=(
  leasebase-bff-gateway
  leasebase-lease-service
  leasebase-property-service
  leasebase-tenant-service
  leasebase-maintenance-service
  leasebase-payments-service
  leasebase-notification-service
  leasebase-document-service
  leasebase-reporting-service
)

for repo in "${REPOS[@]}"; do
  echo "Setting secrets for motart/$repo..."
  gh secret set JIRA_BASE_URL   --repo "motart/$repo" --body "https://leasebase.atlassian.net"
  gh secret set JIRA_EMAIL       --repo "motart/$repo" --body "$JIRA_EMAIL"
  gh secret set JIRA_API_TOKEN   --repo "motart/$repo" --body "$JIRA_API_TOKEN"
  gh secret set ANTHROPIC_API_KEY --repo "motart/$repo" --body "$ANTHROPIC_API_KEY"
  gh secret set GH_PAT           --repo "motart/$repo" --body "$(gh auth token)"
done
```

## Setup via GitHub UI

1. Go to repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret listed above
4. Repeat for every microservice repo

## AWS Secrets Manager (Lambda)

The Lambda webhook handler reads secrets from AWS Secrets Manager:
- `leasebase-automation-{env}/webhook-secret` — shared secret for Jira webhook validation
- `leasebase-automation-{env}/github-token` — GitHub PAT for dispatching workflows

These are created by Terraform. Populate them during `terraform apply`:
```bash
export TF_VAR_webhook_secret="your-random-secret"
export TF_VAR_github_token="$(gh auth token)"
terraform apply
```
