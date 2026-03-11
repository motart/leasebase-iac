--------------------------------------------------------------------------------
-- compat-views.sql — Temporary snake_case compatibility views (dev/UAT)
--
-- PURPOSE:
--   Microservices query snake_case table names (e.g. "users", "tenant_profiles")
--   but the public schema still contains PascalCase Prisma-managed tables
--   ("User", "TenantProfile"). These read-only views bridge the gap until
--   the full migration to per-service schemas is complete.
--
-- SCOPE:
--   Temporary compatibility layer for dev/UAT only.
--   Long-term fix: migrate data to per-service schemas with native snake_case
--   tables and retire these views.
--
-- Idempotent: uses CREATE OR REPLACE VIEW.
-- Run as leasebase_admin:
--   psql -h <host> -U leasebase_admin -d leasebase -f scripts/compat-views.sql
--
-- IMPORTANT: These views are NOT the long-term architecture. They exist to
-- unblock microservice queries that reference legacy Prisma table names
-- using snake_case conventions. Do not add business logic to these views.
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on
\echo '=== Compatibility views: starting ==='

-- ── public.users ────────────────────────────────────────────────────────────
-- Referenced by: property-service (pm-dashboard, pm-routes), maintenance-service
-- Maps from: public."User" (Prisma-managed)

\echo '  → public.users'
CREATE OR REPLACE VIEW public.users AS
SELECT
  "id"               AS id,
  "organizationId"   AS organization_id,
  "email"            AS email,
  "name"             AS name,
  "cognitoSub"       AS cognito_sub,
  "role"::TEXT        AS role,
  "status"           AS status,
  "createdAt"        AS created_at,
  "updatedAt"        AS updated_at
FROM public."User";

-- Grant SELECT to roles that need cross-schema user lookups
GRANT SELECT ON public.users TO property_user;
GRANT SELECT ON public.users TO maintenance_user;
GRANT SELECT ON public.users TO bff_user;
GRANT SELECT ON public.users TO reporting_user;

-- ── public.tenant_profiles ──────────────────────────────────────────────────
-- Referenced by: property-service (pm-dashboard, pm-routes)
-- Maps from: public."TenantProfile" (Prisma-managed)

\echo '  → public.tenant_profiles'
CREATE OR REPLACE VIEW public.tenant_profiles AS
SELECT
  "id"         AS id,
  "userId"     AS user_id,
  "leaseId"    AS lease_id,
  "phone"      AS phone,
  "createdAt"  AS created_at,
  "updatedAt"  AS updated_at
FROM public."TenantProfile";

-- Grant SELECT to roles that need tenant profile lookups
GRANT SELECT ON public.tenant_profiles TO property_user;
GRANT SELECT ON public.tenant_profiles TO lease_user;
GRANT SELECT ON public.tenant_profiles TO reporting_user;

\echo '=== Compatibility views: complete ==='
