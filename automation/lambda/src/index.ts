/**
 * LeaseBase Jira Webhook Lambda
 *
 * Receives Jira webhook payloads, detects "Ready" status transitions
 * (or "ai-build" label), and dispatches GitHub Actions workflow_dispatch
 * events to the appropriate microservice repo.
 */

import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";

// ── Types ───────────────────────────────────────────────────────────────────

interface APIGatewayEvent {
  headers: Record<string, string | undefined>;
  body?: string;
  isBase64Encoded?: boolean;
  requestContext: { http: { method: string; path: string } };
}

interface JiraWebhookPayload {
  webhookEvent?: string;
  issue_event_type_name?: string;
  issue?: {
    key: string;
    fields: {
      summary?: string;
      status?: { name: string };
      labels?: string[];
      project?: { key: string };
    };
  };
  changelog?: {
    items?: Array<{
      field: string;
      fieldtype: string;
      fromString?: string;
      toString?: string;
    }>;
  };
}

interface RepoMap {
  [projectKey: string]: string; // e.g. "BFF" -> "leasebase-bff-gateway"
}

// ── Secrets cache ───────────────────────────────────────────────────────────

const smClient = new SecretsManagerClient({});
const secretCache: Record<string, string> = {};

async function getSecret(name: string): Promise<string> {
  if (secretCache[name]) return secretCache[name];
  const cmd = new GetSecretValueCommand({ SecretId: name });
  const res = await smClient.send(cmd);
  const val = res.SecretString ?? "";
  secretCache[name] = val;
  return val;
}

// ── Repo mapping (bundled at deploy time) ───────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-var-requires
let repoMap: RepoMap;
try {
  repoMap = require("./jira-to-repo-map.json");
} catch {
  repoMap = {};
}

// ── Env ─────────────────────────────────────────────────────────────────────

const WEBHOOK_SECRET_NAME  = process.env.WEBHOOK_SECRET_NAME  ?? "";
const GH_TOKEN_SECRET_NAME = process.env.GH_TOKEN_SECRET_NAME ?? "";
const GITHUB_OWNER         = process.env.GITHUB_OWNER         ?? "motart";
const LOG_LEVEL            = process.env.LOG_LEVEL             ?? "info";

function log(level: string, msg: string, data?: Record<string, unknown>) {
  if (level === "debug" && LOG_LEVEL !== "debug") return;
  const entry = { level, msg, ...data, ts: new Date().toISOString() };
  console.log(JSON.stringify(entry));
}

// ── Core logic ──────────────────────────────────────────────────────────────

function shouldTrigger(payload: JiraWebhookPayload): boolean {
  const issue = payload.issue;
  if (!issue) return false;

  // Check 1: label contains "ai-build"
  const labels = issue.fields?.labels ?? [];
  if (labels.some((l) => l.toLowerCase().includes("ai-build"))) {
    log("info", "Trigger: ai-build label detected", { key: issue.key });
    return true;
  }

  // Check 2: status transitioned to "Ready" via changelog
  const items = payload.changelog?.items ?? [];
  for (const item of items) {
    if (
      item.field.toLowerCase() === "status" &&
      item.toString?.toLowerCase() === "ready"
    ) {
      log("info", "Trigger: status transitioned to Ready", { key: issue.key });
      return true;
    }
  }

  // Check 3: current status is "Ready" (fallback if no changelog)
  if (issue.fields?.status?.name?.toLowerCase() === "ready" && items.length === 0) {
    log("info", "Trigger: current status is Ready (no changelog)", { key: issue.key });
    return true;
  }

  return false;
}

function resolveRepo(payload: JiraWebhookPayload): string | null {
  const issue = payload.issue!;
  const projectKey = issue.fields?.project?.key ?? "";

  // 1. Direct project-key mapping
  if (repoMap[projectKey]) {
    return repoMap[projectKey];
  }

  // 2. Fallback: "service:<slug>" label
  const labels = issue.fields?.labels ?? [];
  for (const label of labels) {
    const match = label.match(/^service:(.+)$/i);
    if (match) {
      return `leasebase-${match[1]}`;
    }
  }

  // 3. Ultimate fallback: bff-gateway (plan-only PR)
  log("info", "No repo mapping found, falling back to bff-gateway", {
    projectKey,
    key: issue.key,
  });
  return "leasebase-bff-gateway";
}

async function dispatchWorkflow(
  repo: string,
  issueKey: string,
  projectKey: string,
  mode: string
): Promise<void> {
  const ghToken = await getSecret(GH_TOKEN_SECRET_NAME);
  const url = `https://api.github.com/repos/${GITHUB_OWNER}/${repo}/actions/workflows/ai-implement-jira.yml/dispatches`;

  const body = JSON.stringify({
    ref: "main",
    inputs: {
      jira_issue_key: issueKey,
      jira_project_key: projectKey,
      mode,
    },
  });

  log("info", "Dispatching workflow", { repo, issueKey, projectKey, mode });

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ghToken}`,
      Accept: "application/vnd.github.v3+json",
      "Content-Type": "application/json",
      "User-Agent": "LeaseBase-Automation-Lambda",
    },
    body,
  });

  if (res.status === 204) {
    log("info", "Workflow dispatched successfully", { repo, issueKey });
  } else {
    const text = await res.text();
    log("error", "Workflow dispatch failed", {
      repo,
      issueKey,
      status: res.status,
      response: text.substring(0, 500),
    });
    throw new Error(`GitHub dispatch failed: ${res.status}`);
  }
}

// ── Handler ─────────────────────────────────────────────────────────────────

export async function handler(event: APIGatewayEvent) {
  const ok = (msg: string) => ({
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ ok: true, message: msg }),
  });

  try {
    // Validate webhook secret
    const expectedSecret = await getSecret(WEBHOOK_SECRET_NAME);
    const receivedSecret =
      event.headers["x-leasebase-webhook-secret"] ??
      event.headers["X-LeaseBase-Webhook-Secret"] ??
      "";

    if (receivedSecret !== expectedSecret) {
      log("warn", "Invalid webhook secret");
      return ok("unauthorized — invalid secret");
    }

    // Parse body
    let rawBody = event.body ?? "";
    if (event.isBase64Encoded) {
      rawBody = Buffer.from(rawBody, "base64").toString("utf-8");
    }

    let payload: JiraWebhookPayload;
    try {
      payload = JSON.parse(rawBody);
    } catch {
      log("warn", "Invalid JSON body");
      return ok("ignored — invalid JSON");
    }

    log("debug", "Received webhook", {
      event: payload.webhookEvent,
      issueKey: payload.issue?.key,
    });

    // Check trigger conditions
    if (!shouldTrigger(payload)) {
      log("info", "Event does not meet trigger conditions, ignoring", {
        issueKey: payload.issue?.key,
        status: payload.issue?.fields?.status?.name,
      });
      return ok("ignored — no trigger condition met");
    }

    // Resolve target repo
    const repo = resolveRepo(payload);
    if (!repo) {
      log("warn", "Could not resolve repo");
      return ok("ignored — no repo mapping");
    }

    const issueKey = payload.issue!.key;
    const projectKey = payload.issue!.fields?.project?.key ?? "";

    // Determine mode: if no direct mapping, mode is plan-only
    const hasDirectMapping =
      !!repoMap[projectKey] ||
      (payload.issue!.fields?.labels ?? []).some((l) =>
        l.match(/^service:.+$/i)
      );
    const mode = hasDirectMapping ? "implement" : "plan";

    await dispatchWorkflow(repo, issueKey, projectKey, mode);

    return ok(`dispatched to ${repo} (mode=${mode})`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    log("error", "Unhandled error", { error: message });
    // Always return 200 to Jira (avoid retry storms)
    return ok(`error (logged): ${message}`);
  }
}
