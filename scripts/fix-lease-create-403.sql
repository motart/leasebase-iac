--------------------------------------------------------------------------------
-- fix-lease-create-403.sql — Fix lease creation 403 "Unit does not belong to
-- your organization" error
--
-- Root cause:
--   1. lease_user has no cross-schema READ on property_service — the lease
--      create endpoint validates unit ownership via a JOIN against
--      property_service.properties, which fails with a permission error.
--   2. Service roles missing SELECT on public."User" — the requireAuth DB
--      enrichment (service-common v2.0.1+) cannot resolve user.orgId from
--      the User table, so orgId falls back to the JWT custom:orgId claim
--      which may be empty or stale, causing the org mismatch.
--
-- Both issues are also fixed in schema-init.sql for future environments.
-- This script is the one-time DEV hotfix.
--
-- Idempotent: safe to re-run.
-- Run as leasebase_admin:
--   psql -h <host> -U leasebase_admin -d leasebase -f scripts/fix-lease-create-403.sql
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on
\echo '=== fix-lease-create-403: starting ==='

--------------------------------------------------------------------------------
-- FIX 1: lease_user cross-schema READ on property_service
-- The lease-service validates unit ownership by JOINing
-- property_service.units + property_service.properties.
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 1: lease_user → property_service cross-schema read ---'

GRANT USAGE ON SCHEMA property_service TO lease_user;
GRANT SELECT ON ALL TABLES IN SCHEMA property_service TO lease_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service
  GRANT SELECT ON TABLES TO lease_user;

\echo '  ✓ lease_user granted SELECT on property_service'

--------------------------------------------------------------------------------
-- FIX 2: All service roles → SELECT on public."User"
-- requireAuth DB enrichment (service-common v2.0.1+) queries:
--   SELECT "id","organizationId","email","name","role"
--   FROM "User" WHERE "cognitoSub" = $1
-- Without this grant, enrichment fails silently and user.orgId is empty.
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 2: service roles → public."User" SELECT ---'

DO $$
DECLARE
  svc_role text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'User'
  ) THEN
    RAISE NOTICE 'public."User" does not exist — skipping grants';
    RETURN;
  END IF;

  FOREACH svc_role IN ARRAY ARRAY[
    'property_user',
    'lease_user',
    'tenant_user',
    'payments_user',
    'maintenance_user',
    'notification_user',
    'document_user',
    'reporting_user'
  ]
  LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = svc_role) THEN
      EXECUTE format('GRANT SELECT ON public."User" TO %I', svc_role);
      RAISE NOTICE '  ✓ GRANT SELECT ON public."User" TO %', svc_role;
    ELSE
      RAISE NOTICE '  ⚠ role % does not exist — skipping', svc_role;
    END IF;
  END LOOP;
END $$;

\echo '  ✓ Fix 2 complete'

--------------------------------------------------------------------------------
\echo ''
\echo '=== fix-lease-create-403: complete ==='
\echo 'Test: create a lease via POST /api/leases as OWNER. Should return 201.'
