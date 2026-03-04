import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'payments_service';

export async function seedPaymentsService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('payments_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'payments'))) {
    logger.skip('payments_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  const now = new Date();
  const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 3);
  const thisMonth = new Date(now.getFullYear(), now.getMonth(), 5);

  // Seed payments
  const payments = [
    {
      id: DEMO_IDS.PAYMENT_SUCCESS,
      org_id: DEMO_IDS.ORG,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      lease_id: DEMO_IDS.LEASE_CARRO_101,
      amount: 2200,
      currency: 'USD',
      payment_type: 'RENT',
      payment_method: 'ACH',
      status: 'COMPLETED',
      external_transaction_id: 'txn_demo_success_001',
      processor: 'stripe',
      processed_at: lastMonth,
      description: 'Rent payment for March 2024',
      created_at: lastMonth,
      updated_at: lastMonth,
    },
    {
      id: DEMO_IDS.PAYMENT_FAILED,
      org_id: DEMO_IDS.ORG,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      lease_id: DEMO_IDS.LEASE_CARRO_101,
      amount: 2200,
      currency: 'USD',
      payment_type: 'RENT',
      payment_method: 'ACH',
      status: 'FAILED',
      external_transaction_id: 'txn_demo_failed_001',
      processor: 'stripe',
      processed_at: thisMonth,
      failure_reason: 'Insufficient funds',
      description: 'Rent payment for April 2024 - Failed',
      created_at: thisMonth,
      updated_at: thisMonth,
    },
    {
      id: DEMO_IDS.PAYMENT_PENDING,
      org_id: DEMO_IDS.ORG,
      tenant_id: DEMO_IDS.TENANT_SMITH,
      lease_id: DEMO_IDS.LEASE_CARRO_101,
      amount: 1100,
      currency: 'USD',
      payment_type: 'RENT',
      payment_method: 'CARD',
      status: 'PENDING',
      external_transaction_id: 'txn_demo_pending_001',
      processor: 'stripe',
      processed_at: null,
      description: 'Partial rent payment for April 2024',
      created_at: new Date(thisMonth.getFullYear(), thisMonth.getMonth(), thisMonth.getDate() + 2),
      updated_at: new Date(thisMonth.getFullYear(), thisMonth.getMonth(), thisMonth.getDate() + 2),
    },
  ];

  const paymentCount = await upsertMany(pool, `${SCHEMA}.payments`, payments);
  logger.seeded('payments_service', 'payments', paymentCount);

  // Seed payment methods (if table exists)
  if (await tableExists(pool, SCHEMA, 'payment_methods')) {
    const paymentMethods = [
      {
        id: DEMO_IDS.TENANT_SMITH + '-ach',
        tenant_id: DEMO_IDS.TENANT_SMITH,
        type: 'ACH',
        is_default: true,
        last_four: '6789',
        bank_name: 'Chase Bank',
        processor_token: 'pm_demo_ach_001',
        is_verified: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: DEMO_IDS.TENANT_SMITH + '-card',
        tenant_id: DEMO_IDS.TENANT_SMITH,
        type: 'CARD',
        is_default: false,
        last_four: '4242',
        card_brand: 'visa',
        processor_token: 'pm_demo_card_001',
        is_verified: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const methodCount = await upsertMany(pool, `${SCHEMA}.payment_methods`, paymentMethods);
    logger.seeded('payments_service', 'payment_methods', methodCount);
  }

  return true;
}
