import { z } from 'zod';

export const SERVICES = [
  'property_service',
  'tenant_service',
  'lease_service',
  'maintenance_service',
  'payments_service',
  'notification_service',
  'document_service',
  'reporting_service',
] as const;

export type ServiceName = (typeof SERVICES)[number];

export const EnvironmentSchema = z.enum(['dev', 'qa', 'uat', 'prod']);
export type Environment = z.infer<typeof EnvironmentSchema>;

export interface SeedOptions {
  env: Environment;
  only?: ServiceName[];
  skip?: ServiceName[];
  databaseUrl?: string;
  forceProd: boolean;
  json: boolean;
  ssmTunnel: boolean;
  connectionTimeout: number;
}

export interface ServiceConfig {
  name: ServiceName;
  schema: string;
  secretPatterns: string[];
}

/**
 * Get service configuration with schema name and secret patterns to try
 */
export function getServiceConfig(env: Environment): ServiceConfig[] {
  return SERVICES.map((name) => ({
    name,
    schema: name,
    secretPatterns: [
      `leasebase/${env}/${name}/db`,
      `leasebase/${name}-db`,
      `leasebase/${name}/db`,
    ],
  }));
}

/**
 * Parse DATABASE_URL into connection components
 */
export function parseDatabaseUrl(url: string): {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  ssl: boolean;
} {
  const parsed = new URL(url);
  return {
    host: parsed.hostname,
    port: parseInt(parsed.port || '5432', 10),
    user: decodeURIComponent(parsed.username),
    password: decodeURIComponent(parsed.password),
    database: parsed.pathname.slice(1),
    ssl: parsed.searchParams.get('sslmode') !== 'disable',
  };
}

export const DEFAULT_CONNECTION_TIMEOUT = 3000;
