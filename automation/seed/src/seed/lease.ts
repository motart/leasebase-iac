import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'lease_service';

export async function seedLeaseService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('lease_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'leases'))) {
    logger.skip('lease_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  const now = new Date();
  const oneYearAgo = new Date(now.getFullYear() - 1, now.getMonth(), 1);
  const oneYearFromNow = new Date(now.getFullYear() + 1, now.getMonth(), 1);
  const twoYearsFromNow = new Date(now.getFullYear() + 2, now.getMonth(), 1);

  // Seed leases
  const leases = [
    {
      id: DEMO_IDS.LEASE_CARRO_101,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_id: DEMO_IDS.UNIT_CARRO_101,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      lease_type: 'FIXED_TERM',
      status: 'ACTIVE',
      start_date: oneYearAgo,
      end_date: oneYearFromNow,
      monthly_rent: 2200,
      security_deposit: 4400,
      lease_terms: JSON.stringify({ pets_allowed: false, parking_included: true }),
      signed_at: oneYearAgo,
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.LEASE_GIBBONS_A,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_GIBBONS,
      unit_id: DEMO_IDS.UNIT_GIBBONS_A,
      tenant_id: DEMO_IDS.TENANT_JOHNSON,
      lease_type: 'FIXED_TERM',
      status: 'ACTIVE',
      start_date: new Date(now.getFullYear(), now.getMonth() - 6, 1),
      end_date: new Date(now.getFullYear() + 1, now.getMonth() + 6, 1),
      monthly_rent: 2800,
      security_deposit: 5600,
      lease_terms: JSON.stringify({ pets_allowed: true, parking_included: true }),
      signed_at: new Date(now.getFullYear(), now.getMonth() - 6, 1),
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.LEASE_RENEWAL_CARRO_101,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_id: DEMO_IDS.UNIT_CARRO_101,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      lease_type: 'FIXED_TERM',
      status: 'PENDING',
      start_date: oneYearFromNow,
      end_date: twoYearsFromNow,
      monthly_rent: 2350,
      security_deposit: 4400,
      lease_terms: JSON.stringify({ pets_allowed: false, parking_included: true }),
      signed_at: null,
      created_at: new Date(),
      updated_at: new Date(),
    },
  ];

  const leaseCount = await upsertMany(pool, `${SCHEMA}.leases`, leases);
  logger.seeded('lease_service', 'leases', leaseCount);

  // Seed rent schedules (if table exists)
  if (await tableExists(pool, SCHEMA, 'rent_schedules')) {
    const currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    const rentSchedules = [
      {
        id: DEMO_IDS.RENT_SCHEDULE_1,
        lease_id: DEMO_IDS.LEASE_CARRO_101,
        due_date: lastMonth,
        amount_due: 2200,
        amount_paid: 2200,
        status: 'PAID',
        paid_at: new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 3),
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: DEMO_IDS.RENT_SCHEDULE_2,
        lease_id: DEMO_IDS.LEASE_CARRO_101,
        due_date: currentMonth,
        amount_due: 2200,
        amount_paid: 1100,
        status: 'PARTIAL',
        paid_at: new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 5),
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: DEMO_IDS.RENT_SCHEDULE_3,
        lease_id: DEMO_IDS.LEASE_CARRO_101,
        due_date: nextMonth,
        amount_due: 2200,
        amount_paid: 0,
        status: 'PENDING',
        paid_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const scheduleCount = await upsertMany(pool, `${SCHEMA}.rent_schedules`, rentSchedules);
    logger.seeded('lease_service', 'rent_schedules', scheduleCount);
  }

  // Seed lease tenants (if table exists - for multi-tenant leases)
  if (await tableExists(pool, SCHEMA, 'lease_tenants')) {
    const leaseTenants = [
      {
        id: DEMO_IDS.LEASE_CARRO_101 + '-tenant',
        lease_id: DEMO_IDS.LEASE_CARRO_101,
        tenant_id: DEMO_IDS.TENANT_SMITH,
        is_primary: true,
        created_at: new Date(),
      },
      {
        id: DEMO_IDS.LEASE_GIBBONS_A + '-tenant',
        lease_id: DEMO_IDS.LEASE_GIBBONS_A,
        tenant_id: DEMO_IDS.TENANT_JOHNSON,
        is_primary: true,
        created_at: new Date(),
      },
    ];

    const ltCount = await upsertMany(pool, `${SCHEMA}.lease_tenants`, leaseTenants);
    logger.seeded('lease_service', 'lease_tenants', ltCount);
  }

  return true;
}
