# Register Jira Webhook

## Prerequisites
- Jira Cloud admin access
- Deployed automation stack (webhook URL from `terraform output webhook_url`)
- Shared secret value (same as `TF_VAR_webhook_secret` used during deploy)

## Steps

### 1. Get your webhook URL
```bash
cd automation/infra/envs/dev
terraform output webhook_url
# Example: https://abc123.execute-api.us-west-2.amazonaws.com/automation/jira/webhook
```

### 2. Register in Jira
1. Go to **Jira Settings → System → WebHooks** (https://leasebase.atlassian.net/plugins/servlet/webhooks)
2. Click **Create a WebHook**
3. Fill in:
   - **Name**: `LeaseBase AI Automation`
   - **Status**: Enabled
   - **URL**: paste the webhook URL from step 1
   - **Headers**: Add `X-LeaseBase-Webhook-Secret` = your shared secret
4. Under **Events**, select:
   - **Issue**: updated
5. **JQL Filter** (optional, recommended):
   - `project in (BFF, LEASE, PROP, TEN, MAINT, PAY, NOTIF, DOC, RPT)`
6. Click **Create**

### 3. Test
1. In any of the 9 projects, create a test issue
2. Transition it to status **Ready**
3. Check CloudWatch logs:
   ```bash
   aws logs tail /aws/lambda/leasebase-automation-dev-jira-webhook --follow
   ```
4. Verify a GitHub Actions workflow was dispatched in the target repo

## Troubleshooting
- If webhook isn't firing, check Jira webhook admin page for delivery status
- Lambda always returns HTTP 200 to avoid Jira retry storms
- See [troubleshooting.md](./troubleshooting.md) for more
