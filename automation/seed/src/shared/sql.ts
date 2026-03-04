import type { Pool } from 'pg';

/**
 * Build an upsert query using INSERT ... ON CONFLICT DO UPDATE
 * @param table - Full table name including schema (e.g., 'property_service.properties')
 * @param data - Object with column names as keys
 * @param conflictColumns - Columns to use for conflict detection (usually ['id'])
 * @param updateColumns - Columns to update on conflict (if empty, updates all non-conflict columns)
 */
export function buildUpsertQuery(
  table: string,
  data: Record<string, unknown>,
  conflictColumns: string[] = ['id'],
  updateColumns?: string[]
): { query: string; values: unknown[] } {
  const columns = Object.keys(data);
  const values = Object.values(data);
  const placeholders = columns.map((_, i) => `$${i + 1}`);

  // Determine which columns to update
  const columnsToUpdate = updateColumns ?? columns.filter((c) => !conflictColumns.includes(c));

  const updateClause = columnsToUpdate.map((col) => `${col} = EXCLUDED.${col}`).join(', ');

  const query = `
    INSERT INTO ${table} (${columns.join(', ')})
    VALUES (${placeholders.join(', ')})
    ON CONFLICT (${conflictColumns.join(', ')})
    DO UPDATE SET ${updateClause || 'id = EXCLUDED.id'}
  `.trim();

  return { query, values };
}

/**
 * Execute an upsert and return affected row count
 */
export async function upsert(
  pool: Pool,
  table: string,
  data: Record<string, unknown>,
  conflictColumns: string[] = ['id']
): Promise<number> {
  const { query, values } = buildUpsertQuery(table, data, conflictColumns);
  const result = await pool.query(query, values);
  return result.rowCount ?? 0;
}

/**
 * Execute multiple upserts in a transaction
 */
export async function upsertMany(
  pool: Pool,
  table: string,
  dataArray: Record<string, unknown>[],
  conflictColumns: string[] = ['id']
): Promise<number> {
  if (dataArray.length === 0) return 0;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    let totalCount = 0;

    for (const data of dataArray) {
      const { query, values } = buildUpsertQuery(table, data, conflictColumns);
      const result = await client.query(query, values);
      totalCount += result.rowCount ?? 0;
    }

    await client.query('COMMIT');
    return totalCount;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Check if a table exists in the database
 */
export async function tableExists(pool: Pool, schema: string, table: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_schema = $1 AND table_name = $2
    )`,
    [schema, table]
  );
  return result.rows[0]?.exists ?? false;
}

/**
 * Check if a schema exists in the database
 */
export async function schemaExists(pool: Pool, schema: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT EXISTS (
      SELECT FROM information_schema.schemata 
      WHERE schema_name = $1
    )`,
    [schema]
  );
  return result.rows[0]?.exists ?? false;
}
