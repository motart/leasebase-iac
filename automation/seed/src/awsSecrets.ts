import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { z } from 'zod';

const secretsClient = new SecretsManagerClient({});

const DbSecretSchema = z.object({
  host: z.string(),
  port: z.coerce.number().default(5432),
  username: z.string(),
  password: z.string(),
  dbname: z.string().optional().default('leasebase'),
  ssl: z.coerce.boolean().optional().default(true),
  schema: z.string().optional(),
});

export type DbSecret = z.infer<typeof DbSecretSchema>;

/**
 * Attempt to fetch a secret from AWS Secrets Manager
 */
export async function getSecret(secretName: string): Promise<DbSecret | null> {
  try {
    const response = await secretsClient.send(
      new GetSecretValueCommand({ SecretId: secretName })
    );

    if (!response.SecretString) {
      return null;
    }

    const parsed = JSON.parse(response.SecretString);
    return DbSecretSchema.parse(parsed);
  } catch (error) {
    // Secret not found or access denied
    return null;
  }
}

/**
 * Try multiple secret patterns and return the first one that works
 */
export async function getSecretFromPatterns(patterns: string[]): Promise<{
  secret: DbSecret | null;
  foundPattern: string | null;
  triedPatterns: string[];
}> {
  const triedPatterns: string[] = [];

  for (const pattern of patterns) {
    triedPatterns.push(pattern);
    const secret = await getSecret(pattern);
    if (secret) {
      return { secret, foundPattern: pattern, triedPatterns };
    }
  }

  return { secret: null, foundPattern: null, triedPatterns };
}
