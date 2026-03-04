# Troubleshooting

## Common Issues

### Jira webhook not triggering
1. Verify webhook is enabled at **Jira Settings → System → WebHooks**
2. Check that the JQL filter matches your project keys
3. Confirm the issue was actually transitioned to status "Ready" (not just edited)
4. Check Jira webhook delivery logs (click on the webhook → Recent Deliveries)

### Lambda receives webhook but doesn't dispatch
1. Check CloudWatch logs:
   ```bash
   aws logs tail /aws/lambda/leasebase-automation-dev-jira-webhook --follow
   ```
2. Common causes:
   - **"Invalid webhook secret"**: Header mismatch — verify `X-LeaseBase-Webhook-Secret` matches Secrets Manager value
   - **"No trigger condition met"**: Issue status didn't transition to "Ready" and no "ai-build" label
   - **"GitHub dispatch failed: 404"**: Workflow file doesn't exist in target repo, or repo name is wrong in mapping
   - **"GitHub dispatch failed: 403"**: GitHub token lacks `repo` + `workflow` permissions

### GitHub Actions workflow not running
1. Verify the workflow file exists at `.github/workflows/ai-implement-jira.yml` in the target repo
2. Check the repo has Actions enabled (Settings → Actions → General)
3. Ensure `GH_PAT` secret is set with `repo` and `workflow` scopes
4. Check Actions tab for failed runs

### AI code generation fails
1. Check the GitHub Actions run logs in the repo
2. Common causes:
   - **ANTHROPIC_API_KEY** not set or invalid
   - Rate limit hit on Anthropic API
   - Generated diff doesn't apply cleanly (will retry up to 2 times)
3. The workflow will still create a PR with whatever partial work was done

### PR not created
1. Check `GH_PAT` has `repo` scope
2. Check the Actions log for the "Create PR" step
3. Verify the branch was pushed (check repo branches)

## Viewing Logs

### Lambda (CloudWatch)
```bash
# Tail live logs
aws logs tail /aws/lambda/leasebase-automation-dev-jira-webhook --follow

# Search logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/leasebase-automation-dev-jira-webhook \
  --filter-pattern "ERROR"
```

### API Gateway (CloudWatch)
```bash
aws logs tail /aws/apigateway/leasebase-automation-dev-webhook-api --follow
```

### GitHub Actions
Go to the repo → Actions tab → select the workflow run

## Testing the Pipeline Manually

### 1. Test Lambda directly
```bash
aws lambda invoke \
  --function-name leasebase-automation-dev-jira-webhook \
  --payload file://test-event.json \
  /dev/stdout
```

### 2. Test webhook endpoint with curl
```bash
WEBHOOK_URL=$(cd automation/infra/envs/dev && terraform output -raw webhook_url)
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-LeaseBase-Webhook-Secret: $TF_VAR_webhook_secret" \
  -d '{"issue":{"key":"BFF-1","fields":{"summary":"Test","status":{"name":"Ready"},"project":{"key":"BFF"},"labels":[]}}}'
```

### 3. Trigger workflow_dispatch directly
```bash
gh workflow run ai-implement-jira.yml \
  --repo motart/leasebase-bff-gateway \
  -f jira_issue_key=BFF-1 \
  -f jira_project_key=BFF \
  -f mode=implement
```
