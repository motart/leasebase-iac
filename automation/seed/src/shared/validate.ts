import { Pool } from 'pg';
import { logger } from './logger.js';

export interface ConnectionError {
  type: 'dns' | 'timeout' | 'auth' | 'ssl' | 'network' | 'unknown';
  message: string;
  suggestion: string;
}

/**
 * Categorize a database connection error and provide helpful suggestions
 */
export function categorizeError(error: Error & { code?: string }): ConnectionError {
  const message = error.message.toLowerCase();
  const code = error.code?.toLowerCase() ?? '';

  // DNS / Host not found
  if (message.includes('getaddrinfo') || message.includes('enotfound') || code === 'enotfound') {
    return {
      type: 'dns',
      message: 'DNS resolution failed - host not found',
      suggestion: 'Check the database hostname. If using private DNS, ensure you have VPC connectivity.',
    };
  }

  // Connection timeout
  if (message.includes('timeout') || message.includes('etimedout') || code === 'etimedout') {
    return {
      type: 'timeout',
      message: 'Connection timed out',
      suggestion:
        'Database may be in a private subnet. Try: 1) SSM port forwarding, 2) Run seeder as ECS task in VPC, 3) Use a bastion host.',
    };
  }

  // Network unreachable
  if (
    message.includes('econnrefused') ||
    message.includes('enetunreach') ||
    code === 'econnrefused' ||
    code === 'enetunreach'
  ) {
    return {
      type: 'network',
      message: 'Connection refused or network unreachable',
      suggestion:
        'Database port may be blocked. Check security groups and ensure inbound access from your IP or VPC.',
    };
  }

  // Authentication failed
  if (
    message.includes('password authentication failed') ||
    message.includes('authentication failed') ||
    code === '28p01'
  ) {
    return {
      type: 'auth',
      message: 'Authentication failed',
      suggestion: 'Check database username and password. Ensure the secret in AWS Secrets Manager is correct.',
    };
  }

  // SSL required
  if (message.includes('ssl') || message.includes('sslmode') || code === '08006') {
    return {
      type: 'ssl',
      message: 'SSL connection required',
      suggestion: 'Enable SSL in connection settings or set ssl: { rejectUnauthorized: false } for dev.',
    };
  }

  return {
    type: 'unknown',
    message: error.message,
    suggestion: 'Check database logs and connection parameters.',
  };
}

/**
 * Test database connectivity with timeout
 */
export async function testConnection(
  pool: Pool,
  timeoutMs: number = 3000
): Promise<{ success: boolean; error?: ConnectionError }> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      resolve({
        success: false,
        error: {
          type: 'timeout',
          message: `Connection timed out after ${timeoutMs}ms`,
          suggestion:
            'Database may be in a private subnet. Try SSM port forwarding or run seeder within the VPC.',
        },
      });
    }, timeoutMs);

    pool
      .query('SELECT 1')
      .then(() => {
        clearTimeout(timeout);
        resolve({ success: true });
      })
      .catch((err: Error & { code?: string }) => {
        clearTimeout(timeout);
        resolve({ success: false, error: categorizeError(err) });
      });
  });
}

/**
 * Print network troubleshooting instructions
 */
export function printNetworkTroubleshooting(): void {
  logger.info('');
  logger.warn('Database is not reachable. Common solutions:');
  logger.info('');
  logger.info('1. SSM Port Forwarding (if DB is in private subnet):');
  logger.info('   aws ssm start-session --target <instance-id> \\');
  logger.info('     --document-name AWS-StartPortForwardingSessionToRemoteHost \\');
  logger.info('     --parameters \'{"host":["<rds-endpoint>"],"portNumber":["5432"],"localPortNumber":["5432"]}\'');
  logger.info('');
  logger.info('2. Run seeder as ECS task (in the same VPC):');
  logger.info('   aws ecs run-task --cluster <cluster> --task-definition seed-task ...');
  logger.info('');
  logger.info('3. Use a bastion host:');
  logger.info('   ssh -L 5432:<rds-endpoint>:5432 ec2-user@<bastion-ip>');
  logger.info('');
}
