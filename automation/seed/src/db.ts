import { Pool, PoolConfig } from 'pg';
import type { DbSecret } from './awsSecrets.js';
import { parseDatabaseUrl, DEFAULT_CONNECTION_TIMEOUT } from './config.js';

export interface ConnectionParams {
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
  ssl: boolean | { rejectUnauthorized: boolean };
  schema?: string;
}

/**
 * Create connection params from a DATABASE_URL
 */
export function paramsFromUrl(url: string, schema?: string): ConnectionParams {
  const parsed = parseDatabaseUrl(url);
  return {
    host: parsed.host,
    port: parsed.port,
    user: parsed.user,
    password: parsed.password,
    database: parsed.database,
    ssl: parsed.ssl ? { rejectUnauthorized: false } : false,
    schema,
  };
}

/**
 * Create connection params from an AWS secret
 */
export function paramsFromSecret(secret: DbSecret, schemaOverride?: string): ConnectionParams {
  return {
    host: secret.host,
    port: secret.port,
    user: secret.username,
    password: secret.password,
    database: secret.dbname,
    ssl: secret.ssl ? { rejectUnauthorized: false } : false,
    schema: schemaOverride ?? secret.schema,
  };
}

/**
 * Create a pg Pool with the given connection params
 */
export function createPool(params: ConnectionParams, timeoutMs: number = DEFAULT_CONNECTION_TIMEOUT): Pool {
  const config: PoolConfig = {
    host: params.host,
    port: params.port,
    user: params.user,
    password: params.password,
    database: params.database,
    ssl: params.ssl,
    connectionTimeoutMillis: timeoutMs,
    idleTimeoutMillis: 10000,
    max: 5,
  };

  const pool = new Pool(config);

  // Set search_path if schema is specified
  if (params.schema) {
    pool.on('connect', async (client) => {
      await client.query(`SET search_path TO ${params.schema}, public`);
    });
  }

  return pool;
}

/**
 * Execute a callback with a pool, ensuring cleanup
 */
export async function withPool<T>(
  params: ConnectionParams,
  callback: (pool: Pool) => Promise<T>,
  timeoutMs: number = DEFAULT_CONNECTION_TIMEOUT
): Promise<T> {
  const pool = createPool(params, timeoutMs);
  try {
    return await callback(pool);
  } finally {
    await pool.end();
  }
}
