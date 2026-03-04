import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'document_service';

export async function seedDocumentService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('document_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  if (!(await tableExists(pool, SCHEMA, 'documents'))) {
    logger.skip('document_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  const now = new Date();

  // Seed documents (metadata only - no actual file upload)
  const documents = [
    {
      id: DEMO_IDS.DOC_LEASE_PDF,
      org_id: DEMO_IDS.ORG,
      entity_type: 'LEASE',
      entity_id: DEMO_IDS.LEASE_CARRO_101,
      filename: 'lease_agreement_carro_101.pdf',
      original_filename: 'Lease Agreement - 123 Carro Drive Unit 101.pdf',
      mime_type: 'application/pdf',
      size_bytes: 245678,
      s3_bucket: 'leasebase-dev-documents',
      s3_key: `leases/${DEMO_IDS.LEASE_CARRO_101}/lease_agreement_carro_101.pdf`,
      category: 'LEASE_AGREEMENT',
      description: 'Signed lease agreement for Unit 101',
      uploaded_by: DEMO_IDS.PM_USER,
      is_signed: true,
      signed_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
      created_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
      updated_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
    },
    {
      id: DEMO_IDS.DOC_MOVEIN_CHECKLIST,
      org_id: DEMO_IDS.ORG,
      entity_type: 'LEASE',
      entity_id: DEMO_IDS.LEASE_CARRO_101,
      filename: 'movein_checklist_carro_101.pdf',
      original_filename: 'Move-In Checklist - 123 Carro Drive Unit 101.pdf',
      mime_type: 'application/pdf',
      size_bytes: 123456,
      s3_bucket: 'leasebase-dev-documents',
      s3_key: `leases/${DEMO_IDS.LEASE_CARRO_101}/movein_checklist_carro_101.pdf`,
      category: 'MOVE_IN_CHECKLIST',
      description: 'Move-in inspection checklist with photos',
      uploaded_by: DEMO_IDS.PM_USER,
      is_signed: true,
      signed_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
      created_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
      updated_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
    },
  ];

  const docCount = await upsertMany(pool, `${SCHEMA}.documents`, documents);
  logger.seeded('document_service', 'documents', docCount);

  // Seed document signatures (if table exists)
  if (await tableExists(pool, SCHEMA, 'document_signatures')) {
    const signatures = [
      {
        id: DEMO_IDS.DOC_LEASE_PDF + '-sig-tenant',
        document_id: DEMO_IDS.DOC_LEASE_PDF,
        signer_id: DEMO_IDS.TENANT_SMITH,
        signer_name: 'John Smith',
        signer_email: 'john.smith@email.com',
        signer_role: 'TENANT',
        status: 'SIGNED',
        signed_at: new Date(now.getFullYear() - 1, now.getMonth(), 1, 14, 30),
        ip_address: '192.168.1.100',
        created_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
        updated_at: new Date(now.getFullYear() - 1, now.getMonth(), 1, 14, 30),
      },
      {
        id: DEMO_IDS.DOC_LEASE_PDF + '-sig-pm',
        document_id: DEMO_IDS.DOC_LEASE_PDF,
        signer_id: DEMO_IDS.PM_USER,
        signer_name: 'Property Manager',
        signer_email: 'pm@demo.leasebase',
        signer_role: 'PROPERTY_MANAGER',
        status: 'SIGNED',
        signed_at: new Date(now.getFullYear() - 1, now.getMonth(), 1, 10, 0),
        ip_address: '192.168.1.50',
        created_at: new Date(now.getFullYear() - 1, now.getMonth(), 1),
        updated_at: new Date(now.getFullYear() - 1, now.getMonth(), 1, 10, 0),
      },
    ];

    const sigCount = await upsertMany(pool, `${SCHEMA}.document_signatures`, signatures);
    logger.seeded('document_service', 'document_signatures', sigCount);
  }

  return true;
}
