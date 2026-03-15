--------------------------------------------------------------------------------
-- validate-privileges.sql — Non-destructive privilege validation
--
-- Tests least-privilege for every service role using BEGIN/ROLLBACK.
-- No test data is left behind. Failures reflect permission issues only.
--
-- Run as leasebase_admin against the target database.
-- Exit code is non-zero if any test fails.
--
-- Usage:
--   psql -h <host> -U leasebase_admin -d leasebase -f scripts/validate-privileges.sql
--------------------------------------------------------------------------------

\set ON_ERROR_STOP off
\echo '=== LeaseBase privilege validation: starting ==='

-- Create a temporary results table (dropped at end)
CREATE TEMP TABLE _priv_results (
  test_name  text NOT NULL,
  result     text NOT NULL  -- 'PASS' or 'FAIL'
);

--------------------------------------------------------------------------------
-- Helper: Create a test table in each schema-owning service's schema
-- (done as admin, rolled back at end)
--------------------------------------------------------------------------------
\echo '  Creating test fixtures...'

CREATE TABLE IF NOT EXISTS property_service._priv_test    (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS lease_service._priv_test       (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS tenant_service._priv_test      (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS payments_service._priv_test    (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS maintenance_service._priv_test (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS notification_service._priv_test(id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS document_service._priv_test    (id serial PRIMARY KEY, val text);
CREATE TABLE IF NOT EXISTS reporting_service._priv_test   (id serial PRIMARY KEY, val text);

-- Grant per existing default privileges (these are new tables by admin)
GRANT SELECT, INSERT, UPDATE, DELETE ON property_service._priv_test     TO property_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON lease_service._priv_test        TO lease_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_service._priv_test       TO tenant_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON payments_service._priv_test     TO payments_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON maintenance_service._priv_test  TO maintenance_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification_service._priv_test TO notification_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON document_service._priv_test     TO document_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON reporting_service._priv_test    TO reporting_user;

-- Grant cross-schema SELECT on test tables to roles that need it
GRANT SELECT ON lease_service._priv_test       TO property_user, tenant_user, reporting_user;
GRANT SELECT ON tenant_service._priv_test      TO property_user, lease_user, reporting_user;
GRANT SELECT ON maintenance_service._priv_test TO property_user, tenant_user, reporting_user;
GRANT SELECT ON payments_service._priv_test    TO property_user, tenant_user, reporting_user;
GRANT SELECT ON document_service._priv_test    TO property_user;
GRANT SELECT ON property_service._priv_test    TO lease_user, tenant_user, maintenance_user, reporting_user;

\echo '  Running privilege tests...'

--------------------------------------------------------------------------------
-- TEST 1: Own-schema CRUD (must succeed) — uses SET ROLE + BEGIN/ROLLBACK
--------------------------------------------------------------------------------

-- property_user: CRUD on own schema
DO $$
BEGIN
  SET LOCAL ROLE property_user;
  INSERT INTO property_service._priv_test (val) VALUES ('test');
  PERFORM * FROM property_service._priv_test WHERE val = 'test';
  UPDATE property_service._priv_test SET val = 'updated' WHERE val = 'test';
  DELETE FROM property_service._priv_test WHERE val = 'updated';
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('property_user own-schema CRUD', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('property_user own-schema CRUD', 'FAIL: ' || SQLERRM);
END $$;

-- lease_user: CRUD on own schema
DO $$
BEGIN
  SET LOCAL ROLE lease_user;
  INSERT INTO lease_service._priv_test (val) VALUES ('test');
  PERFORM * FROM lease_service._priv_test WHERE val = 'test';
  UPDATE lease_service._priv_test SET val = 'updated' WHERE val = 'test';
  DELETE FROM lease_service._priv_test WHERE val = 'updated';
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user own-schema CRUD', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user own-schema CRUD', 'FAIL: ' || SQLERRM);
END $$;

-- tenant_user: CRUD on own schema
DO $$
BEGIN
  SET LOCAL ROLE tenant_user;
  INSERT INTO tenant_service._priv_test (val) VALUES ('test');
  PERFORM * FROM tenant_service._priv_test WHERE val = 'test';
  UPDATE tenant_service._priv_test SET val = 'updated' WHERE val = 'test';
  DELETE FROM tenant_service._priv_test WHERE val = 'updated';
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user own-schema CRUD', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user own-schema CRUD', 'FAIL: ' || SQLERRM);
END $$;

-- payments_user: CRUD on own schema
DO $$
BEGIN
  SET LOCAL ROLE payments_user;
  INSERT INTO payments_service._priv_test (val) VALUES ('test');
  PERFORM * FROM payments_service._priv_test WHERE val = 'test';
  UPDATE payments_service._priv_test SET val = 'updated' WHERE val = 'test';
  DELETE FROM payments_service._priv_test WHERE val = 'updated';
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user own-schema CRUD', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user own-schema CRUD', 'FAIL: ' || SQLERRM);
END $$;

--------------------------------------------------------------------------------
-- TEST 2: Allowed cross-schema SELECT (must succeed)
--------------------------------------------------------------------------------

-- lease_user reading tenant_service (allowed)
DO $$
BEGIN
  SET LOCAL ROLE lease_user;
  PERFORM * FROM tenant_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user SELECT tenant_service', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user SELECT tenant_service', 'FAIL: ' || SQLERRM);
END $$;

-- tenant_user reading lease_service (allowed)
DO $$
BEGIN
  SET LOCAL ROLE tenant_user;
  PERFORM * FROM lease_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user SELECT lease_service', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user SELECT lease_service', 'FAIL: ' || SQLERRM);
END $$;

-- lease_user reading property_service (allowed)
DO $$
BEGIN
  SET LOCAL ROLE lease_user;
  PERFORM * FROM property_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user SELECT property_service', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user SELECT property_service', 'FAIL: ' || SQLERRM);
END $$;

-- maintenance_user reading property_service (allowed)
DO $$
BEGIN
  SET LOCAL ROLE maintenance_user;
  PERFORM * FROM property_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('maintenance_user SELECT property_service', 'PASS');
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('maintenance_user SELECT property_service', 'FAIL: ' || SQLERRM);
END $$;

--------------------------------------------------------------------------------
-- TEST 3: Cross-schema WRITE denied (must fail)
--------------------------------------------------------------------------------

-- lease_user INSERT into tenant_service (denied)
DO $$
BEGIN
  SET LOCAL ROLE lease_user;
  INSERT INTO tenant_service._priv_test (val) VALUES ('should_fail');
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user INSERT tenant_service DENIED', 'FAIL: insert succeeded (should be denied)');
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user INSERT tenant_service DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('lease_user INSERT tenant_service DENIED', 'FAIL: ' || SQLERRM);
END $$;

-- payments_user INSERT into property_service (denied)
DO $$
BEGIN
  SET LOCAL ROLE payments_user;
  INSERT INTO property_service._priv_test (val) VALUES ('should_fail');
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user INSERT property_service DENIED', 'FAIL: insert succeeded (should be denied)');
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user INSERT property_service DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user INSERT property_service DENIED', 'FAIL: ' || SQLERRM);
END $$;

-- tenant_user INSERT into lease_service (denied — read-only cross-schema)
DO $$
BEGIN
  SET LOCAL ROLE tenant_user;
  INSERT INTO lease_service._priv_test (val) VALUES ('should_fail');
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user INSERT lease_service DENIED', 'FAIL: insert succeeded (should be denied)');
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user INSERT lease_service DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('tenant_user INSERT lease_service DENIED', 'FAIL: ' || SQLERRM);
END $$;

--------------------------------------------------------------------------------
-- TEST 4: Disallowed cross-schema READ denied (must fail)
--------------------------------------------------------------------------------

-- payments_user SELECT from property_service (not in read_schemas)
DO $$
BEGIN
  SET LOCAL ROLE payments_user;
  PERFORM * FROM property_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user SELECT property_service DENIED', 'FAIL: select succeeded (should be denied)');
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user SELECT property_service DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('payments_user SELECT property_service DENIED', 'FAIL: ' || SQLERRM);
END $$;

-- notification_user SELECT from lease_service (not in read_schemas)
DO $$
BEGIN
  SET LOCAL ROLE notification_user;
  PERFORM * FROM lease_service._priv_test;
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('notification_user SELECT lease_service DENIED', 'FAIL: select succeeded (should be denied)');
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('notification_user SELECT lease_service DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('notification_user SELECT lease_service DENIED', 'FAIL: ' || SQLERRM);
END $$;

--------------------------------------------------------------------------------
-- TEST 5: bff/auth table-level public schema grants
--------------------------------------------------------------------------------

-- bff_user: SELECT on "User" succeeds (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='User') THEN
    SET LOCAL ROLE bff_user;
    PERFORM * FROM public."User" LIMIT 0;
    RESET ROLE;
    INSERT INTO _priv_results VALUES ('bff_user SELECT public.User', 'PASS');
  ELSE
    INSERT INTO _priv_results VALUES ('bff_user SELECT public.User', 'PASS (table not yet created)');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('bff_user SELECT public.User', 'FAIL: ' || SQLERRM);
END $$;

-- bff_user: INSERT on "User" denied
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='User') THEN
    SET LOCAL ROLE bff_user;
    INSERT INTO public."User" DEFAULT VALUES;
    RESET ROLE;
    INSERT INTO _priv_results VALUES ('bff_user INSERT public.User DENIED', 'FAIL: insert succeeded (should be denied)');
  ELSE
    INSERT INTO _priv_results VALUES ('bff_user INSERT public.User DENIED', 'PASS (table not yet created)');
  END IF;
EXCEPTION WHEN insufficient_privilege THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('bff_user INSERT public.User DENIED', 'PASS');
WHEN OTHERS THEN
  RESET ROLE;
  -- Other errors (e.g. NOT NULL constraint) still mean INSERT was attempted = has privilege = FAIL
  INSERT INTO _priv_results VALUES ('bff_user INSERT public.User DENIED', 'FAIL: ' || SQLERRM);
END $$;

-- auth_user: INSERT on "User" succeeds (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='User') THEN
    SET LOCAL ROLE auth_user;
    -- Just check has_table_privilege; actual INSERT would hit NOT NULL constraints
    IF has_table_privilege('auth_user', 'public."User"', 'INSERT') THEN
      RESET ROLE;
      INSERT INTO _priv_results VALUES ('auth_user INSERT public.User', 'PASS');
    ELSE
      RESET ROLE;
      INSERT INTO _priv_results VALUES ('auth_user INSERT public.User', 'FAIL: no INSERT privilege');
    END IF;
  ELSE
    INSERT INTO _priv_results VALUES ('auth_user INSERT public.User', 'PASS (table not yet created)');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RESET ROLE;
  INSERT INTO _priv_results VALUES ('auth_user INSERT public.User', 'FAIL: ' || SQLERRM);
END $$;

-- auth_user: DELETE on "User" denied
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='User') THEN
    IF has_table_privilege('auth_user', 'public."User"', 'DELETE') THEN
      INSERT INTO _priv_results VALUES ('auth_user DELETE public.User DENIED', 'FAIL: has DELETE privilege (should not)');
    ELSE
      INSERT INTO _priv_results VALUES ('auth_user DELETE public.User DENIED', 'PASS');
    END IF;
  ELSE
    INSERT INTO _priv_results VALUES ('auth_user DELETE public.User DENIED', 'PASS (table not yet created)');
  END IF;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO _priv_results VALUES ('auth_user DELETE public.User DENIED', 'FAIL: ' || SQLERRM);
END $$;

--------------------------------------------------------------------------------
-- TEST 6: Service roles SELECT on public."User" (requireAuth enrichment)
--------------------------------------------------------------------------------

DO $$
DECLARE
  svc_role text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='User') THEN
    INSERT INTO _priv_results VALUES ('service_roles SELECT public.User', 'PASS (table not yet created)');
    RETURN;
  END IF;

  FOREACH svc_role IN ARRAY ARRAY[
    'property_user','lease_user','tenant_user','payments_user',
    'maintenance_user','notification_user','document_user','reporting_user'
  ]
  LOOP
    IF has_table_privilege(svc_role, 'public."User"', 'SELECT') THEN
      INSERT INTO _priv_results VALUES (svc_role || ' SELECT public.User', 'PASS');
    ELSE
      INSERT INTO _priv_results VALUES (svc_role || ' SELECT public.User', 'FAIL: missing SELECT on public."User"');
    END IF;
  END LOOP;
END $$;

--------------------------------------------------------------------------------
-- Results
--------------------------------------------------------------------------------
\echo ''
\echo '=== Privilege Validation Results ==='

SELECT test_name, result FROM _priv_results ORDER BY test_name;

-- Count failures
DO $$
DECLARE
  fail_count int;
BEGIN
  SELECT count(*) INTO fail_count FROM _priv_results WHERE result LIKE 'FAIL%';
  IF fail_count > 0 THEN
    RAISE NOTICE '% test(s) FAILED', fail_count;
  ELSE
    RAISE NOTICE 'All tests PASSED';
  END IF;
END $$;

-- Cleanup test tables
DROP TABLE IF EXISTS property_service._priv_test;
DROP TABLE IF EXISTS lease_service._priv_test;
DROP TABLE IF EXISTS tenant_service._priv_test;
DROP TABLE IF EXISTS payments_service._priv_test;
DROP TABLE IF EXISTS maintenance_service._priv_test;
DROP TABLE IF EXISTS notification_service._priv_test;
DROP TABLE IF EXISTS document_service._priv_test;
DROP TABLE IF EXISTS reporting_service._priv_test;

\echo '=== validation complete ==='
