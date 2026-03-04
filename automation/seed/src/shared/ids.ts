import { v5 as uuidv5 } from 'uuid';

// Namespace UUID for LeaseBase seed data (generated once, stable)
const LEASEBASE_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

/**
 * Generate a deterministic UUID based on service, entity type, and identifier.
 * This ensures idempotent seeding - the same inputs always produce the same UUID.
 */
export function deterministicId(service: string, entity: string, identifier: string): string {
  const input = `${service}:${entity}:${identifier}`;
  return uuidv5(input, LEASEBASE_NAMESPACE);
}

/**
 * Pre-generated IDs for demo data.
 * Using deterministic generation ensures consistency across runs.
 */
export const DEMO_IDS = {
  // Organization
  ORG: deterministicId('org', 'organization', 'demo-org'),

  // Users
  OWNER_USER: deterministicId('user', 'user', 'owner@demo.leasebase'),
  PM_USER: deterministicId('user', 'user', 'pm@demo.leasebase'),
  TENANT_USER: deterministicId('user', 'user', 'tenant@demo.leasebase'),
  VENDOR_USER: deterministicId('user', 'user', 'vendor@demo.leasebase'),

  // Properties
  PROPERTY_CARRO: deterministicId('property', 'property', 'carro-drive-4plex'),
  PROPERTY_GIBBONS: deterministicId('property', 'property', 'gibbons-dr-duplex'),

  // Units - Carro Drive
  UNIT_CARRO_101: deterministicId('property', 'unit', 'carro-101'),
  UNIT_CARRO_102: deterministicId('property', 'unit', 'carro-102'),
  UNIT_CARRO_201: deterministicId('property', 'unit', 'carro-201'),
  UNIT_CARRO_202: deterministicId('property', 'unit', 'carro-202'),

  // Units - Gibbons Dr
  UNIT_GIBBONS_A: deterministicId('property', 'unit', 'gibbons-a'),
  UNIT_GIBBONS_B: deterministicId('property', 'unit', 'gibbons-b'),

  // Tenants
  TENANT_SMITH: deterministicId('tenant', 'tenant', 'john-smith'),
  TENANT_JOHNSON: deterministicId('tenant', 'tenant', 'sarah-johnson'),
  TENANT_WILLIAMS: deterministicId('tenant', 'tenant', 'mike-williams'),

  // Household member
  HOUSEHOLD_SMITH_SPOUSE: deterministicId('tenant', 'household', 'smith-spouse'),

  // Leases
  LEASE_CARRO_101: deterministicId('lease', 'lease', 'lease-carro-101'),
  LEASE_GIBBONS_A: deterministicId('lease', 'lease', 'lease-gibbons-a'),
  LEASE_RENEWAL_CARRO_101: deterministicId('lease', 'lease', 'renewal-carro-101'),

  // Rent schedules
  RENT_SCHEDULE_1: deterministicId('lease', 'rent_schedule', 'rent-1'),
  RENT_SCHEDULE_2: deterministicId('lease', 'rent_schedule', 'rent-2'),
  RENT_SCHEDULE_3: deterministicId('lease', 'rent_schedule', 'rent-3'),

  // Maintenance requests
  MAINTENANCE_1: deterministicId('maintenance', 'request', 'maint-1'),
  MAINTENANCE_2: deterministicId('maintenance', 'request', 'maint-2'),
  MAINTENANCE_3: deterministicId('maintenance', 'request', 'maint-3'),

  // Vendor
  VENDOR_PLUMBER: deterministicId('maintenance', 'vendor', 'ace-plumbing'),

  // Payments
  PAYMENT_SUCCESS: deterministicId('payments', 'payment', 'pay-success-1'),
  PAYMENT_FAILED: deterministicId('payments', 'payment', 'pay-failed-1'),
  PAYMENT_PENDING: deterministicId('payments', 'payment', 'pay-pending-1'),

  // Notification templates
  NOTIF_TEMPLATE_RENT_DUE: deterministicId('notification', 'template', 'rent-due'),
  NOTIF_TEMPLATE_MAINT_UPDATE: deterministicId('notification', 'template', 'maintenance-update'),

  // Notification events
  NOTIF_EVENT_1: deterministicId('notification', 'event', 'notif-1'),
  NOTIF_EVENT_2: deterministicId('notification', 'event', 'notif-2'),
  NOTIF_EVENT_3: deterministicId('notification', 'event', 'notif-3'),

  // Documents
  DOC_LEASE_PDF: deterministicId('document', 'document', 'lease-pdf-1'),
  DOC_MOVEIN_CHECKLIST: deterministicId('document', 'document', 'movein-checklist-1'),

  // Reporting
  REPORT_JOB_DEF: deterministicId('reporting', 'job_definition', 'monthly-summary'),
  REPORT_JOB_RUN: deterministicId('reporting', 'job_run', 'run-2024-01'),
} as const;

export type DemoIdKey = keyof typeof DEMO_IDS;
