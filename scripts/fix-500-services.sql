--------------------------------------------------------------------------------
-- fix-500-services.sql — Fix 500 errors on tenant, maintenance, notification
--
-- Root causes:
--   1. tenant-service:       Missing columns on "TenantProfile" (migration never applied)
--   2. maintenance-service:  Missing GRANT on public-schema Prisma tables
--   3. notification-service: Missing "notifications" table (migration never created/applied)
--
-- Idempotent: safe to re-run.
-- Run as leasebase_admin from within the VPC:
--   psql -h <proxy-or-cluster-endpoint> -U leasebase_admin -d leasebase \
--        -f scripts/fix-500-services.sql
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on
\echo '=== Fix 500 services: starting ==='

--------------------------------------------------------------------------------
-- FIX 1: tenant-service — Add missing columns to "TenantProfile"
-- Error: column tp.status does not exist (PostgreSQL 42703)
-- Source migration: leasebase-tenant-service/db/migrations/004_tenant_profile_columns.sql
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 1: tenant-service — TenantProfile missing columns ---'

-- Add organizationId
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'organizationId'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "organizationId" TEXT;
    RAISE NOTICE 'Added column: TenantProfile.organizationId';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.organizationId';
  END IF;
END $$;

-- Add status
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'status'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'ACTIVE';
    RAISE NOTICE 'Added column: TenantProfile.status';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.status';
  END IF;
END $$;

-- Add emergency_contact
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'emergency_contact'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "emergency_contact" TEXT;
    RAISE NOTICE 'Added column: TenantProfile.emergency_contact';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.emergency_contact';
  END IF;
END $$;

-- Add move_in_date
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'move_in_date'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "move_in_date" DATE;
    RAISE NOTICE 'Added column: TenantProfile.move_in_date';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.move_in_date';
  END IF;
END $$;

-- Add move_out_date
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'move_out_date'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "move_out_date" DATE;
    RAISE NOTICE 'Added column: TenantProfile.move_out_date';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.move_out_date';
  END IF;
END $$;

-- Add notes
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'notes'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "notes" TEXT;
    RAISE NOTICE 'Added column: TenantProfile.notes';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.notes';
  END IF;
END $$;

-- Add notification_preferences
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'TenantProfile' AND column_name = 'notification_preferences'
  ) THEN
    ALTER TABLE public."TenantProfile" ADD COLUMN "notification_preferences" JSONB;
    RAISE NOTICE 'Added column: TenantProfile.notification_preferences';
  ELSE
    RAISE NOTICE 'Column already exists: TenantProfile.notification_preferences';
  END IF;
END $$;

-- Index on organizationId
CREATE INDEX IF NOT EXISTS idx_tenant_profile_org ON public."TenantProfile"("organizationId");

-- tenant_user needs CRUD on TenantProfile + SELECT on other public-schema Prisma tables
-- (permission error was masked by the missing-column error above)
DO $$
DECLARE
  tbl text;
BEGIN
  -- CRUD on TenantProfile (tenant-service owns this data)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'TenantProfile') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON public."TenantProfile" TO tenant_user';
    RAISE NOTICE 'Granted CRUD on public.TenantProfile to tenant_user';
  END IF;

  -- SELECT on tables used in JOINs
  FOREACH tbl IN ARRAY ARRAY['User', 'Property', 'Unit', 'Payment', 'WorkOrder', 'WorkOrderComment', 'Organization']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('GRANT SELECT ON public.%I TO tenant_user', tbl);
      RAISE NOTICE 'Granted SELECT on public.% to tenant_user', tbl;
    ELSE
      RAISE WARNING 'Table public.% does not exist — skipping grant', tbl;
    END IF;
  END LOOP;
END $$;

\echo '  ✓ Fix 1 complete'

--------------------------------------------------------------------------------
-- FIX 2: maintenance-service — Grant SELECT on public-schema Prisma tables
-- Error: permission denied for table WorkOrder (PostgreSQL 42501)
-- maintenance_user needs SELECT on "WorkOrder", "Unit", "WorkOrderComment", "User"
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 2: maintenance-service — public-schema table grants ---'

DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['WorkOrder', 'WorkOrderComment', 'Unit', 'User']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('GRANT SELECT ON public.%I TO maintenance_user', tbl);
      RAISE NOTICE 'Granted SELECT on public.% to maintenance_user', tbl;
    ELSE
      RAISE WARNING 'Table public.% does not exist — skipping grant', tbl;
    END IF;
  END LOOP;
END $$;

-- maintenance_user also needs SELECT + INSERT + UPDATE on "WorkOrder" and "WorkOrderComment"
-- since the code does INSERT/UPDATE operations on these tables
DO $$
DECLARE
  tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['WorkOrder', 'WorkOrderComment']
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO maintenance_user', tbl);
      RAISE NOTICE 'Granted INSERT/UPDATE/DELETE on public.% to maintenance_user', tbl;
    ELSE
      RAISE WARNING 'Table public.% does not exist — skipping grant', tbl;
    END IF;
  END LOOP;
END $$;

\echo '  ✓ Fix 2 complete'

--------------------------------------------------------------------------------
-- FIX 3: notification-service — Create notifications table
-- Error: relation "notifications" does not exist (PostgreSQL 42P01)
-- Table was never created — no migration existed for notification-service
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 3: notification-service — create notifications table ---'

SET search_path TO notification_service, public;

CREATE TABLE IF NOT EXISTS notifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id     TEXT NOT NULL,
  recipient_user_id   TEXT NOT NULL,
  sender_user_id      TEXT,
  title               TEXT NOT NULL,
  body                TEXT NOT NULL,
  type                TEXT NOT NULL DEFAULT 'general',
  related_type        TEXT,
  related_id          TEXT,
  read_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
  ON notifications(recipient_user_id, organization_id);
CREATE INDEX IF NOT EXISTS idx_notifications_org
  ON notifications(organization_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created
  ON notifications(created_at DESC);

-- Grant CRUD to notification_user (schema-init.sql handles DEFAULT PRIVILEGES
-- for future tables, but this table is new and needs explicit grants)
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO notification_user;

-- Also grant notification_user SELECT on public."User" for recipient validation
RESET search_path;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'User') THEN
    EXECUTE 'GRANT SELECT ON public."User" TO notification_user';
    RAISE NOTICE 'Granted SELECT on public."User" to notification_user';
  END IF;
END $$;

\echo '  ✓ Fix 3 complete'

--------------------------------------------------------------------------------
\echo ''
\echo '=== All fixes applied ==='
\echo 'Test endpoints:'
\echo '  curl -H "Authorization: Bearer <token>" https://api.dev.leasebase.ai/api/tenants'
\echo '  curl -H "Authorization: Bearer <token>" https://api.dev.leasebase.ai/api/maintenance'
\echo '  curl -H "Authorization: Bearer <token>" https://api.dev.leasebase.ai/api/notifications'
