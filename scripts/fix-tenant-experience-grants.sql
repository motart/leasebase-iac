--------------------------------------------------------------------------------
-- fix-tenant-experience-grants.sql — Grant fixes for tenant experience
--
-- Addresses cross-schema access gaps introduced by:
--   Phase 1: maintenance-service tenant lease validation (lease_service.leases + tenant_profiles)
--   Phase 2: payments-service checkout endpoint (lease_service.leases)
--
-- Idempotent: GRANT is safe to re-run.
-- Run as leasebase_admin:
--   psql -h <host> -U leasebase_admin -d leasebase \
--        -f scripts/fix-tenant-experience-grants.sql
--------------------------------------------------------------------------------

\set ON_ERROR_STOP on
\echo '=== Tenant experience grant fixes: starting ==='

--------------------------------------------------------------------------------
-- FIX 1: maintenance_user — needs SELECT on lease_service + tenant_profiles
--
-- Phase 1 changed the tenant lease validation query in maintenance-service
-- from Prisma "Lease"/"TenantProfile" tables to canonical lease_service.leases
-- + tenant_profiles compat view.
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 1: maintenance_user — lease_service + tenant_profiles ---'

-- lease_service schema access
GRANT USAGE ON SCHEMA lease_service TO maintenance_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO maintenance_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service
  GRANT SELECT ON TABLES TO maintenance_user;

-- tenant_profiles compat view
GRANT SELECT ON public.tenant_profiles TO maintenance_user;

\echo '  ✓ Fix 1 complete'

--------------------------------------------------------------------------------
-- FIX 2: payments_user — needs SELECT on lease_service
--
-- Phase 2 added POST /checkout which resolves tenant's active lease by
-- querying lease_service.leases via tenant_profiles (already granted).
--------------------------------------------------------------------------------

\echo ''
\echo '--- Fix 2: payments_user — lease_service ---'

-- lease_service schema access
GRANT USAGE ON SCHEMA lease_service TO payments_user;
GRANT SELECT ON ALL TABLES IN SCHEMA lease_service TO payments_user;
ALTER DEFAULT PRIVILEGES FOR ROLE leasebase_admin IN SCHEMA lease_service
  GRANT SELECT ON TABLES TO payments_user;

\echo '  ✓ Fix 2 complete'

--------------------------------------------------------------------------------
\echo ''
\echo '=== All tenant experience grant fixes applied ==='
\echo ''
\echo 'Verification: run validate-privileges.sql to confirm all grants are correct.'
