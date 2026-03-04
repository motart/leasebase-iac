import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'notification_service';

export async function seedNotificationService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('notification_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  // Seed notification templates (if table exists)
  if (await tableExists(pool, SCHEMA, 'notification_templates')) {
    const templates = [
      {
        id: DEMO_IDS.NOTIF_TEMPLATE_RENT_DUE,
        org_id: DEMO_IDS.ORG,
        name: 'Rent Due Reminder',
        type: 'EMAIL',
        subject: 'Rent Payment Due - {{property_name}} Unit {{unit_number}}',
        body: 'Dear {{tenant_name}},\n\nThis is a friendly reminder that your rent payment of ${{amount}} is due on {{due_date}}.\n\nProperty: {{property_name}}\nUnit: {{unit_number}}\n\nPlease log in to your tenant portal to make a payment.\n\nThank you,\nLeaseBase',
        variables: JSON.stringify(['tenant_name', 'amount', 'due_date', 'property_name', 'unit_number']),
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        id: DEMO_IDS.NOTIF_TEMPLATE_MAINT_UPDATE,
        org_id: DEMO_IDS.ORG,
        name: 'Maintenance Request Update',
        type: 'EMAIL',
        subject: 'Maintenance Update - {{request_title}}',
        body: 'Dear {{tenant_name}},\n\nYour maintenance request has been updated.\n\nRequest: {{request_title}}\nStatus: {{status}}\n\n{{notes}}\n\nThank you,\nLeaseBase',
        variables: JSON.stringify(['tenant_name', 'request_title', 'status', 'notes']),
        is_active: true,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const templateCount = await upsertMany(pool, `${SCHEMA}.notification_templates`, templates);
    logger.seeded('notification_service', 'notification_templates', templateCount);
  }

  // Seed notifications (if table exists)
  if (await tableExists(pool, SCHEMA, 'notifications')) {
    const now = new Date();

    const notifications = [
      {
        id: DEMO_IDS.NOTIF_EVENT_1,
        org_id: DEMO_IDS.ORG,
        template_id: DEMO_IDS.NOTIF_TEMPLATE_RENT_DUE,
        recipient_id: DEMO_IDS.TENANT_SMITH,
        recipient_email: 'john.smith@email.com',
        channel: 'EMAIL',
        subject: 'Rent Payment Due - Carro Drive 4-Plex Unit 101',
        body: 'Dear John Smith,\n\nThis is a friendly reminder that your rent payment of $2,200 is due on April 1, 2024.\n\nProperty: Carro Drive 4-Plex\nUnit: 101\n\nPlease log in to your tenant portal to make a payment.\n\nThank you,\nLeaseBase',
        status: 'SENT',
        sent_at: new Date(now.getFullYear(), now.getMonth(), 1, 9, 0),
        created_at: new Date(now.getFullYear(), now.getMonth(), 1, 9, 0),
        updated_at: new Date(now.getFullYear(), now.getMonth(), 1, 9, 0),
      },
      {
        id: DEMO_IDS.NOTIF_EVENT_2,
        org_id: DEMO_IDS.ORG,
        template_id: DEMO_IDS.NOTIF_TEMPLATE_MAINT_UPDATE,
        recipient_id: DEMO_IDS.TENANT_SMITH,
        recipient_email: 'john.smith@email.com',
        channel: 'EMAIL',
        subject: 'Maintenance Update - Leaky faucet in kitchen',
        body: 'Dear John Smith,\n\nYour maintenance request has been updated.\n\nRequest: Leaky faucet in kitchen\nStatus: COMPLETED\n\nThe repair has been completed. Please let us know if you have any issues.\n\nThank you,\nLeaseBase',
        status: 'SENT',
        sent_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
        created_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
        updated_at: new Date(now.getFullYear(), now.getMonth(), now.getDate() - 5),
      },
      {
        id: DEMO_IDS.NOTIF_EVENT_3,
        org_id: DEMO_IDS.ORG,
        template_id: DEMO_IDS.NOTIF_TEMPLATE_RENT_DUE,
        recipient_id: DEMO_IDS.TENANT_JOHNSON,
        recipient_email: 'sarah.johnson@email.com',
        channel: 'EMAIL',
        subject: 'Rent Payment Due - Gibbons Dr Duplex Unit A',
        body: 'Dear Sarah Johnson,\n\nThis is a friendly reminder that your rent payment of $2,800 is due on April 1, 2024.\n\nProperty: Gibbons Dr Duplex\nUnit: A\n\nPlease log in to your tenant portal to make a payment.\n\nThank you,\nLeaseBase',
        status: 'QUEUED',
        sent_at: null,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];

    const notifCount = await upsertMany(pool, `${SCHEMA}.notifications`, notifications);
    logger.seeded('notification_service', 'notifications', notifCount);
  } else {
    logger.skip('notification_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  return true;
}
