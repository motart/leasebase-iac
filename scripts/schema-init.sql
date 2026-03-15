--------------------------------------------------------------------------------
-- schema-init.sql — LeaseBase platform database bootstrap
--
-- Idempotent. Safe to rerun. Run as the master/admin role (leasebase_admin).
-- Passwords are injected via psql variables: -v property_pw='...' etc.
--
-- Usage (via run-schema-init.sh):
--   psql -h <host> -U leasebase_admin -d leasebase \
--     -v property_pw="'...'" -v lease_pw="'...'" ... \
--     -f scripts/schema-init.sql
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on
\echo '=== LeaseBase schema-init: starting ==='

--------------------------------------------------------------------------------
-- 1. Schema-owning services: role + schema + owned grants + default privileges
--------------------------------------------------------------------------------

-- Helper: create role if not exists, or update password if it does.
-- This supports both initial creation and password rotation on rerun.

-- ── property_service ────────────────────────────────────────────────────────
\echo '  → property_user / property_service'
\o /dev/null
SELECT set_config('app.property_pw', :'property_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE property_user LOGIN PASSWORD %L', current_setting('app.property_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE property_user PASSWORD %L', current_setting('app.property_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS property_service;

GRANT USAGE ON SCHEMA property_service TO property_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA property_service TO property_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA property_service TO property_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service
  GRANT USAGE, SELECT ON SEQUENCES TO property_user;

-- ── lease_service ───────────────────────────────────────────────────────────
\echo '  → lease_user / lease_service'
\o /dev/null
SELECT set_config('app.lease_pw', :'lease_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE lease_user LOGIN PASSWORD %L', current_setting('app.lease_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE lease_user PASSWORD %L', current_setting('app.lease_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS lease_service;

GRANT USAGE ON SCHEMA lease_service TO lease_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lease_service TO lease_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA lease_service TO lease_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lease_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service
  GRANT USAGE, SELECT ON SEQUENCES TO lease_user;

-- ── tenant_service ──────────────────────────────────────────────────────────
\echo '  → tenant_user / tenant_service'
\o /dev/null
SELECT set_config('app.tenant_pw', :'tenant_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE tenant_user LOGIN PASSWORD %L', current_setting('app.tenant_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE tenant_user PASSWORD %L', current_setting('app.tenant_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS tenant_service;

GRANT USAGE ON SCHEMA tenant_service TO tenant_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant_service TO tenant_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA tenant_service TO tenant_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA tenant_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tenant_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA tenant_service
  GRANT USAGE, SELECT ON SEQUENCES TO tenant_user;

-- ── payments_service ────────────────────────────────────────────────────────
\echo '  → payments_user / payments_service'
\o /dev/null
SELECT set_config('app.payments_pw', :'payments_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE payments_user LOGIN PASSWORD %L', current_setting('app.payments_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE payments_user PASSWORD %L', current_setting('app.payments_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS payments_service;

GRANT USAGE ON SCHEMA payments_service TO payments_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA payments_service TO payments_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA payments_service TO payments_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA payments_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO payments_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA payments_service
  GRANT USAGE, SELECT ON SEQUENCES TO payments_user;

-- ── maintenance_service ─────────────────────────────────────────────────────
\echo '  → maintenance_user / maintenance_service'
\o /dev/null
SELECT set_config('app.maintenance_pw', :'maintenance_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE maintenance_user LOGIN PASSWORD %L', current_setting('app.maintenance_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE maintenance_user PASSWORD %L', current_setting('app.maintenance_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS maintenance_service;

GRANT USAGE ON SCHEMA maintenance_service TO maintenance_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA maintenance_service TO maintenance_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA maintenance_service TO maintenance_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA maintenance_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO maintenance_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA maintenance_service
  GRANT USAGE, SELECT ON SEQUENCES TO maintenance_user;

-- ── notification_service ────────────────────────────────────────────────────
\echo '  → notification_user / notification_service'
\o /dev/null
SELECT set_config('app.notification_pw', :'notification_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE notification_user LOGIN PASSWORD %L', current_setting('app.notification_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE notification_user PASSWORD %L', current_setting('app.notification_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS notification_service;

GRANT USAGE ON SCHEMA notification_service TO notification_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA notification_service TO notification_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA notification_service TO notification_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA notification_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO notification_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA notification_service
  GRANT USAGE, SELECT ON SEQUENCES TO notification_user;

-- ── document_service ────────────────────────────────────────────────────────
\echo '  → document_user / document_service'
\o /dev/null
SELECT set_config('app.document_pw', :'document_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE document_user LOGIN PASSWORD %L', current_setting('app.document_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE document_user PASSWORD %L', current_setting('app.document_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS document_service;

GRANT USAGE ON SCHEMA document_service TO document_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA document_service TO document_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA document_service TO document_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA document_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO document_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA document_service
  GRANT USAGE, SELECT ON SEQUENCES TO document_user;

-- ── reporting_service ───────────────────────────────────────────────────────
\echo '  → reporting_user / reporting_service'
\o /dev/null
SELECT set_config('app.reporting_pw', :'reporting_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE reporting_user LOGIN PASSWORD %L', current_setting('app.reporting_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE reporting_user PASSWORD %L', current_setting('app.reporting_pw'));
END $$;

CREATE SCHEMA IF NOT EXISTS reporting_service;

GRANT USAGE ON SCHEMA reporting_service TO reporting_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA reporting_service TO reporting_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA reporting_service TO reporting_user;

ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA reporting_service
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA reporting_service
  GRANT USAGE, SELECT ON SEQUENCES TO reporting_user;

--------------------------------------------------------------------------------
-- 2. Public-schema services: role only (table-level grants, no owned schema)
--------------------------------------------------------------------------------

\echo '  → bff_user (public schema, SELECT on "User" only)'
\o /dev/null
SELECT set_config('app.bff_pw', :'bff_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE bff_user LOGIN PASSWORD %L', current_setting('app.bff_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE bff_user PASSWORD %L', current_setting('app.bff_pw'));
END $$;

-- bff_user: SELECT only on specific public tables
DO $$
BEGIN
  -- Grant only if the table exists (idempotent for fresh DBs)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'User') THEN
    EXECUTE 'GRANT SELECT ON public."User" TO bff_user';
  END IF;
END $$;

\echo '  → auth_user (public schema, SELECT+INSERT on User/Organization/Subscription)'
\o /dev/null
SELECT set_config('app.auth_pw', :'auth_pw', false);
\o
DO $$ BEGIN
  EXECUTE format('CREATE ROLE auth_user LOGIN PASSWORD %L', current_setting('app.auth_pw'));
EXCEPTION WHEN duplicate_object THEN
  EXECUTE format('ALTER ROLE auth_user PASSWORD %L', current_setting('app.auth_pw'));
END $$;

-- auth_user: SELECT + INSERT on specific public tables
DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['Organization', 'User', 'Subscription']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('GRANT SELECT, INSERT ON public.%I TO auth_user', tbl);
    END IF;
  END LOOP;
END $$;

--------------------------------------------------------------------------------
-- 3. Cross-schema read grants (SELECT only, per service_db_config.read_schemas)
--    ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin ensures future tables
--    created by the admin role are also readable.
--------------------------------------------------------------------------------

\echo '=== Cross-schema read grants ==='

-- property_user reads: lease_service, tenant_service, maintenance_service, payments_service, document_service
\echo '  → property_user cross-schema reads'
GRANT USAGE ON SCHEMA lease_service TO property_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service GRANT SELECT ON TABLES TO property_user;

GRANT USAGE ON SCHEMA tenant_service TO property_user;
GRANT SELECT ON ALL TABLES IN SCHEMA tenant_service TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA tenant_service GRANT SELECT ON TABLES TO property_user;

GRANT USAGE ON SCHEMA maintenance_service TO property_user;
GRANT SELECT ON ALL TABLES IN SCHEMA maintenance_service TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA maintenance_service GRANT SELECT ON TABLES TO property_user;

GRANT USAGE ON SCHEMA payments_service TO property_user;
GRANT SELECT ON ALL TABLES IN SCHEMA payments_service TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA payments_service GRANT SELECT ON TABLES TO property_user;

GRANT USAGE ON SCHEMA document_service TO property_user;
GRANT SELECT ON ALL TABLES IN SCHEMA document_service TO property_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA document_service GRANT SELECT ON TABLES TO property_user;

-- lease_user reads: tenant_service
\echo '  → lease_user cross-schema reads'
GRANT USAGE ON SCHEMA tenant_service TO lease_user;
GRANT SELECT ON ALL TABLES IN SCHEMA tenant_service TO lease_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA tenant_service GRANT SELECT ON TABLES TO lease_user;

-- tenant_user reads: lease_service, property_service, payments_service, maintenance_service
-- tenant_user writes: lease_service.leases (invitation acceptance creates leases),
--                     property_service.units (invitation acceptance sets unit to OCCUPIED)
\echo '  → tenant_user cross-schema reads + targeted writes'
GRANT USAGE ON SCHEMA lease_service TO tenant_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO tenant_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service GRANT SELECT ON TABLES TO tenant_user;

GRANT USAGE ON SCHEMA property_service TO tenant_user;
GRANT SELECT ON ALL TABLES IN SCHEMA property_service TO tenant_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service GRANT SELECT ON TABLES TO tenant_user;

-- Targeted write grants for invitation acceptance flow
-- NOTE: public."User" writes are owned by auth-service (auth_user role).
-- tenant-service creates TenantProfile, leases, and updates unit status.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'lease_service' AND table_name = 'leases') THEN
    EXECUTE 'GRANT INSERT ON lease_service.leases TO tenant_user';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'property_service' AND table_name = 'units') THEN
    EXECUTE 'GRANT UPDATE ON property_service.units TO tenant_user';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'TenantProfile') THEN
    EXECUTE 'GRANT INSERT ON public."TenantProfile" TO tenant_user';
  END IF;
END $$;

GRANT USAGE ON SCHEMA payments_service TO tenant_user;
GRANT SELECT ON ALL TABLES IN SCHEMA payments_service TO tenant_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA payments_service GRANT SELECT ON TABLES TO tenant_user;

GRANT USAGE ON SCHEMA maintenance_service TO tenant_user;
GRANT SELECT ON ALL TABLES IN SCHEMA maintenance_service TO tenant_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA maintenance_service GRANT SELECT ON TABLES TO tenant_user;

-- maintenance_user reads: property_service, lease_service, public.TenantProfile
\echo '  → maintenance_user cross-schema reads'
GRANT USAGE ON SCHEMA property_service TO maintenance_user;
GRANT SELECT ON ALL TABLES IN SCHEMA property_service TO maintenance_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service GRANT SELECT ON TABLES TO maintenance_user;

GRANT USAGE ON SCHEMA lease_service TO maintenance_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO maintenance_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service GRANT SELECT ON TABLES TO maintenance_user;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'TenantProfile') THEN
    EXECUTE 'GRANT SELECT ON public."TenantProfile" TO maintenance_user';
  END IF;
END $$;

-- reporting_user reads: property_service, lease_service, tenant_service, payments_service, maintenance_service
\echo '  → reporting_user cross-schema reads'
GRANT USAGE ON SCHEMA property_service TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA property_service TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA property_service GRANT SELECT ON TABLES TO reporting_user;

GRANT USAGE ON SCHEMA lease_service TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service GRANT SELECT ON TABLES TO reporting_user;

GRANT USAGE ON SCHEMA tenant_service TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA tenant_service TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA tenant_service GRANT SELECT ON TABLES TO reporting_user;

GRANT USAGE ON SCHEMA payments_service TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA payments_service TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA payments_service GRANT SELECT ON TABLES TO reporting_user;

GRANT USAGE ON SCHEMA maintenance_service TO reporting_user;
GRANT SELECT ON ALL TABLES IN SCHEMA maintenance_service TO reporting_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA maintenance_service GRANT SELECT ON TABLES TO reporting_user;

-- payments_user, notification_user, document_user: no cross-schema reads

--------------------------------------------------------------------------------
-- 4. Public-schema "User" table: SELECT for service-common requireAuth
--    enrichment (resolves req.user.orgId from cognitoSub at middleware level).
--    All service roles that use @leasebase/service-common v2.0.1+ need this.
--------------------------------------------------------------------------------

\echo '=== public.User read grants (requireAuth enrichment) ==='

DO $$
DECLARE
  svc_role text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'User') THEN
    RAISE NOTICE 'public."User" does not exist yet — skipping service-role grants';
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
    END IF;
  END LOOP;
END $$;

\echo '=== LeaseBase schema-init: complete ==='
