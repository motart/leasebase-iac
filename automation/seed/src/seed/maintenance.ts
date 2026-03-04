import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'maintenance_service';

export async function seedMaintenanceService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('maintenance_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'maintenance_requests'))) {
    logger.skip('maintenance_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  const now = new Date();

  // Seed vendors (if table exists)
  if (await tableExists(pool, SCHEMA, 'vendors')) {
    const vendors = [
      {
        id: DEMO_IDS.VENDOR_PLUMBER,
        org_id: DEMO_IDS.ORG,
        name: 'Ace Plumbing Services',
        email: 'contact@aceplumbing.com',
        phone: '+1-408-555-9000',
        specialty: 'PLUMBING',
        hourly_rate: 85,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const vendorCount = await upsertMany(pool, `${SCHEMA}.vendors`, vendors);
    logger.seeded('maintenance_service', 'vendors', vendorCount);
  }

  // Seed maintenance requests
  const maintenanceRequests = [
    {
      id: DEMO_IDS.MAINTENANCE_1,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_id: DEMO_IDS.UNIT_CARRO_101,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      title: 'Leaky faucet in kitchen',
      description: 'The kitchen sink faucet has been dripping constantly for the past week.',
      category: 'PLUMBING',
      priority: 'MEDIUM',
      status: 'COMPLETED',
      vendor_id: DEMO_IDS.VENDOR_PLUMBER,
      estimated_cost: 150,
      actual_cost: 125,
      scheduled_date: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7),
      completed_date: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
      created_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 10),
      updated_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
    },
    {
      id: DEMO_IDS.MAINTENANCE_2,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_GIBBONS,
      unit_id: DEMO_IDS.UNIT_GIBBONS_A,
      tenant_id: DEMO_IDS.TENANT_JOHNSON,
      title: 'HVAC not cooling properly',
      description: 'AC unit is running but not cooling the apartment. Temperature stays around 78°F.',
      category: 'HVAC',
      priority: 'HIGH',
      status: 'IN_PROGRESS',
      vendor_id: null,
      estimated_cost: 300,
      actual_cost: null,
      scheduled_date: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2),
      completed_date: null,
      created_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 2),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.MAINTENANCE_3,
      org_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_id: DEMO_IDS.UNIT_CARRO_102,
      tenant_id: null,
      title: 'Paint touch-up needed in vacant unit',
      description: 'Walls need touch-up painting before next tenant move-in.',
      category: 'GENERAL',
      priority: 'LOW',
      status: 'NEW',
      vendor_id: null,
      estimated_cost: 200,
      actual_cost: null,
      scheduled_date: null,
      completed_date: null,
      created_at: new Date(),
      updated_at: new Date(),
    },
  ];

  const requestCount = await upsertMany(pool, `${SCHEMA}.maintenance_requests`, maintenanceRequests);
  logger.seeded('maintenance_service', 'maintenance_requests', requestCount);

  // Seed work orders (if table exists)
  if (await tableExists(pool, SCHEMA, 'work_orders')) {
    const workOrders = [
      {
        id: DEMO_IDS.MAINTENANCE_1 + '-wo',
        request_id: DEMO_IDS.MAINTENANCE_1,
        vendor_id: DEMO_IDS.VENDOR_PLUMBER,
        status: 'COMPLETED',
        notes: 'Replaced faucet washer and tightened connections.',
        labor_hours: 1.5,
        parts_cost: 25,
        labor_cost: 100,
        created_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7),
        updated_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
      },
    ];

    const woCount = await upsertMany(pool, `${SCHEMA}.work_orders`, workOrders);
    logger.seeded('maintenance_service', 'work_orders', woCount);
  }

  return true;
}
