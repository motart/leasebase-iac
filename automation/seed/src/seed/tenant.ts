import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'tenant_service';

export async function seedTenantService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('tenant_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'tenants'))) {
    logger.skip('tenant_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  // Seed tenants
  const tenants = [
    {
      id: DEMO_IDS.TENANT_SMITH,
      org_id: DEMO_IDS.ORG,
      user_id: DEMO_IDS.TENANT_USER,
      first_name: 'John',
      last_name: 'Smith',
      email: 'john.smith@email.com',
      phone: '+1-408-555-0101',
      date_of_birth: new Date('1985-03-15'),
      ssn_last_four: '1234',
      status: 'ACTIVE',
      emergency_contact_name: 'Jane Smith',
      emergency_contact_phone: '+1-408-555-0102',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.TENANT_JOHNSON,
      org_id: DEMO_IDS.ORG,
      user_id: null,
      first_name: 'Sarah',
      last_name: 'Johnson',
      email: 'sarah.johnson@email.com',
      phone: '+1-408-555-0201',
      date_of_birth: new Date('1990-07-22'),
      ssn_last_four: '5678',
      status: 'ACTIVE',
      emergency_contact_name: 'Mike Johnson',
      emergency_contact_phone: '+1-408-555-0202',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.TENANT_WILLIAMS,
      org_id: DEMO_IDS.ORG,
      user_id: null,
      first_name: 'Mike',
      last_name: 'Williams',
      email: 'mike.williams@email.com',
      phone: '+1-408-555-0301',
      date_of_birth: new Date('1978-11-08'),
      ssn_last_four: '9012',
      status: 'PROSPECTIVE',
      emergency_contact_name: 'Lisa Williams',
      emergency_contact_phone: '+1-408-555-0302',
      created_at: new Date(),
      updated_at: new Date(),
    },
  ];

  const tenantCount = await upsertMany(pool, `${SCHEMA}.tenants`, tenants);
  logger.seeded('tenant_service', 'tenants', tenantCount);

  // Seed household members (if table exists)
  if (await tableExists(pool, SCHEMA, 'household_members')) {
    const householdMembers = [
      {
        id: DEMO_IDS.HOUSEHOLD_SMITH_SPOUSE,
        tenant_id: DEMO_IDS.TENANT_SMITH,
        first_name: 'Jane',
        last_name: 'Smith',
        relationship: 'SPOUSE',
        date_of_birth: new Date('1987-06-20'),
        is_occupant: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const householdCount = await upsertMany(pool, `${SCHEMA}.household_members`, householdMembers);
    logger.seeded('tenant_service', 'household_members', householdCount);
  }

  // Seed employment info (if table exists)
  if (await tableExists(pool, SCHEMA, 'tenant_employment')) {
    const employment = [
      {
        id: DEMO_IDS.TENANT_SMITH + '-emp',
        tenant_id: DEMO_IDS.TENANT_SMITH,
        employer_name: 'Tech Corp Inc',
        job_title: 'Software Engineer',
        monthly_income: 12000,
        start_date: new Date('2020-01-15'),
        is_current: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: DEMO_IDS.TENANT_JOHNSON + '-emp',
        tenant_id: DEMO_IDS.TENANT_JOHNSON,
        employer_name: 'Healthcare Partners',
        job_title: 'Registered Nurse',
        monthly_income: 8500,
        start_date: new Date('2018-06-01'),
        is_current: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const empCount = await upsertMany(pool, `${SCHEMA}.tenant_employment`, employment);
    logger.seeded('tenant_service', 'tenant_employment', empCount);
  }

  return true;
}
