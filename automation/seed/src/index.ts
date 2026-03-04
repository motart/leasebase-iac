#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import { Pool } from 'pg';

import {
  SERVICES,
  getServiceConfig,
  EnvironmentSchema,
  DEFAULT_CONNECTION_TIMEOUT,
  type SeedOptions,
  type ServiceName,
  type Environment,
} from './config.js';
import { getSecretFromPatterns } from './awsSecrets.js';
import { createPool, paramsFromUrl, paramsFromSecret, type ConnectionParams } from './db.js';
import { testConnection, printNetworkTroubleshooting } from './shared/validate.js';
import { logger } from './shared/logger.js';

// Import seeders
import { seedPropertyService } from './seed/property.js';
import { seedTenantService } from './seed/tenant.js';
import { seedLeaseService } from './seed/lease.js';
import { seedMaintenanceService } from './seed/maintenance.js';
import { seedPaymentsService } from './seed/payments.js';
import { seedNotificationService } from './seed/notification.js';
import { seedDocumentService } from './seed/document.js';
import { seedReportingService } from './seed/reporting.js';

// Map service names to seeder functions
const SEEDERS: Record<ServiceName, (pool: Pool) => Promise<boolean>> = {
  property_service: seedPropertyService,
  tenant_service: seedTenantService,
  lease_service: seedLeaseService,
  maintenance_service: seedMaintenanceService,
  payments_service: seedPaymentsService,
  notification_service: seedNotificationService,
  document_service: seedDocumentService,
  reporting_service: seedReportingService,
};

async function runSeed(options: SeedOptions): Promise<void> {
  logger.setJsonMode(options.json);
  logger.header(options.env);

  // Production safety check
  if (options.env === 'prod' && !options.forceProd) {
    logger.error('Production seeding requires --force-prod flag');
    logger.info('This is a safety measure to prevent accidental production data modification.');
    process.exit(1);
  }

  // Determine which services to seed
  const serviceConfigs = getServiceConfig(options.env);
  let servicesToSeed = serviceConfigs;

  if (options.only && options.only.length > 0) {
    servicesToSeed = serviceConfigs.filter((s) => options.only!.includes(s.name));
  }
  if (options.skip && options.skip.length > 0) {
    servicesToSeed = servicesToSeed.filter((s) => !options.skip!.includes(s.name));
  }

  if (servicesToSeed.length === 0) {
    logger.warn('No services selected for seeding');
    return;
  }

  // Check if using global DATABASE_URL
  const globalDbUrl = options.databaseUrl || process.env.DATABASE_URL;
  let globalPool: Pool | null = null;
  let globalConnected = false;

  if (globalDbUrl) {
    logger.info(`Using DATABASE_URL for all services`);
    const params = paramsFromUrl(globalDbUrl);

    globalPool = createPool(params, options.connectionTimeout);
    const connResult = await testConnection(globalPool, options.connectionTimeout);

    if (!connResult.success) {
      logger.error(`Failed to connect: ${connResult.error?.message}`);
      logger.info(connResult.error?.suggestion || '');
      printNetworkTroubleshooting();

      await globalPool.end();
      process.exit(1);
    }

    globalConnected = true;
    logger.success('Connected to database');
    logger.info('');
  }

  // Seed each service
  for (const serviceConfig of servicesToSeed) {
    logger.serviceStart(serviceConfig.name);

    let pool: Pool;
    let shouldClosePool = false;

    if (globalPool && globalConnected) {
      // Use global pool with schema search_path
      const params = paramsFromUrl(globalDbUrl!, serviceConfig.schema);
      pool = createPool(params, options.connectionTimeout);
      shouldClosePool = true;
    } else {
      // Try to get service-specific credentials from Secrets Manager
      logger.info('Looking for service credentials in Secrets Manager...');
      const { secret, foundPattern, triedPatterns } = await getSecretFromPatterns(serviceConfig.secretPatterns);

      if (!secret) {
        logger.skip(
          serviceConfig.name,
          `Secret not found (tried: ${triedPatterns.join(', ')})`,
          'Provide DATABASE_URL or create the secret in Secrets Manager'
        );
        logger.serviceComplete(serviceConfig.name, 'SKIPPED');
        continue;
      }

      logger.info(`Found secret: ${foundPattern}`);
      const params = paramsFromSecret(secret, serviceConfig.schema);
      pool = createPool(params, options.connectionTimeout);
      shouldClosePool = true;

      // Test connection
      const connResult = await testConnection(pool, options.connectionTimeout);
      if (!connResult.success) {
        logger.skip(serviceConfig.name, connResult.error?.message || 'Connection failed', connResult.error?.suggestion);
        logger.serviceComplete(serviceConfig.name, 'SKIPPED');
        if (shouldClosePool) await pool.end();
        continue;
      }
    }

    try {
      const seeder = SEEDERS[serviceConfig.name];
      const success = await seeder(pool);

      if (success) {
        logger.serviceComplete(serviceConfig.name, 'SEEDED');
      } else {
        logger.serviceComplete(serviceConfig.name, 'SKIPPED');
      }
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      logger.error(`Failed to seed: ${errMsg}`);
      logger.serviceComplete(serviceConfig.name, 'FAILED');
    } finally {
      if (shouldClosePool) {
        await pool.end();
      }
    }
  }

  // Cleanup global pool
  if (globalPool) {
    await globalPool.end();
  }

  logger.summary();
}

// CLI Setup
const program = new Command();

program
  .name('leasebase-seed')
  .description('Seed demo data for LeaseBase microservices')
  .version('1.0.0');

program
  .command('seed')
  .description('Seed demo data into the database')
  .option('-e, --env <environment>', 'Target environment (dev, qa, uat, prod)', 'dev')
  .option('--only <services>', 'Only seed these services (comma-separated)')
  .option('--skip <services>', 'Skip these services (comma-separated)')
  .option('--database-url <url>', 'Database connection URL (overrides secrets)')
  .option('--force-prod', 'Required flag to seed production environment', false)
  .option('--json', 'Output results in JSON format', false)
  .option('--ssm-tunnel', 'Use SSM port forwarding (not yet implemented)', false)
  .option('--timeout <ms>', 'Connection timeout in milliseconds', String(DEFAULT_CONNECTION_TIMEOUT))
  .action(async (opts) => {
    try {
      // Validate environment
      const env = EnvironmentSchema.parse(opts.env) as Environment;

      // Parse service lists
      const only = opts.only
        ? (opts.only.split(',').map((s: string) => s.trim()) as ServiceName[])
        : undefined;
      const skip = opts.skip
        ? (opts.skip.split(',').map((s: string) => s.trim()) as ServiceName[])
        : undefined;

      // Validate service names
      if (only) {
        for (const s of only) {
          if (!SERVICES.includes(s as ServiceName)) {
            console.error(chalk.red(`Unknown service: ${s}`));
            console.error(chalk.gray(`Valid services: ${SERVICES.join(', ')}`));
            process.exit(1);
          }
        }
      }
      if (skip) {
        for (const s of skip) {
          if (!SERVICES.includes(s as ServiceName)) {
            console.error(chalk.red(`Unknown service: ${s}`));
            console.error(chalk.gray(`Valid services: ${SERVICES.join(', ')}`));
            process.exit(1);
          }
        }
      }

      const options: SeedOptions = {
        env,
        only,
        skip,
        databaseUrl: opts.databaseUrl,
        forceProd: opts.forceProd,
        json: opts.json,
        ssmTunnel: opts.ssmTunnel,
        connectionTimeout: parseInt(opts.timeout, 10),
      };

      await runSeed(options);
    } catch (error) {
      if (error instanceof Error) {
        console.error(chalk.red(`Error: ${error.message}`));
      }
      process.exit(1);
    }
  });

program.parse();
