import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'reporting_service';

export async function seedReportingService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('reporting_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'report_definitions'))) {
    logger.skip('reporting_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  const now = new Date();
  const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);

  // Seed report definitions
  const reportDefinitions = [
    {
      id: DEMO_IDS.REPORT_JOB_DEF,
      org_id: DEMO_IDS.ORG,
      name: 'Monthly Property Summary',
      description: 'Monthly summary report including occupancy, rent collection, and maintenance metrics',
      report_type: 'PROPERTY_SUMMARY',
      parameters: JSON.stringify({
        include_occupancy: true,
        include_rent_collection: true,
        include_maintenance: true,
        group_by: 'property',
      }),
      schedule: 'MONTHLY',
      schedule_day: 1,
      schedule_time: '06:00',
      is_active: true,
      recipients: JSON.stringify(['owner@demo.leasebase', 'pm@demo.leasebase']),
      output_format: 'PDF',
      created_by: DEMO_IDS.OWNER_USER,
      created_at: new Date(now.getFullYear(), 0, 1),
      updated_at: new Date(),
    },
  ];

  const defCount = await upsertMany(pool, `${SCHEMA}.report_definitions`, reportDefinitions);
  logger.seeded('reporting_service', 'report_definitions', defCount);

  // Seed report runs (if table exists)
  if (await tableExists(pool, SCHEMA, 'report_runs')) {
    const reportRuns = [
      {
        id: DEMO_IDS.REPORT_JOB_RUN,
        definition_id: DEMO_IDS.REPORT_JOB_DEF,
        org_id: DEMO_IDS.ORG,
        status: 'COMPLETED',
        parameters: JSON.stringify({
          include_occupancy: true,
          include_rent_collection: true,
          include_maintenance: true,
          group_by: 'property',
          period_start: new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1),
          period_end: new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 0),
        }),
        started_at: new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 1, 6, 0),
        completed_at: new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 1, 6, 5),
        s3_bucket: 'leasebase-dev-reports',
        s3_key: `reports/${DEMO_IDS.ORG}/${lastMonth.getFullYear()}/${String(lastMonth.getMonth() + 1).padStart(2, '0')}/monthly_summary.pdf`,
        file_size_bytes: 156789,
        row_count: 2,
        error_message: null,
        created_at: new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 1, 6, 0),
        updated_at: new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 1, 6, 5),
      },
    ];

    const runCount = await upsertMany(pool, `${SCHEMA}.report_runs`, reportRuns);
    logger.seeded('reporting_service', 'report_runs', runCount);
  }

  return true;
}
