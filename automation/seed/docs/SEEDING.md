# LeaseBase Demo Data Seeding

This tool populates realistic sample data for all LeaseBase microservices, allowing you to test the application immediately after deployment.

## Overview

The seeder creates a complete "demo organization" with:
- **2 Properties**: Carro Drive 4-Plex, Gibbons Dr Duplex
- **6 Units**: 4 units at Carro Drive, 2 at Gibbons
- **3 Tenants**: With profiles, employment info, and household members
- **2 Active Leases**: With rent schedules (including partial payment scenarios)
- **3 Maintenance Requests**: NEW, IN_PROGRESS, and COMPLETED statuses
- **3 Payment Transactions**: Success, failed, and pending
- **Notification Templates**: Rent due reminders, maintenance updates
- **Document Metadata**: Lease agreements, move-in checklists
- **Report Definitions**: Monthly property summary with sample run

All data uses **deterministic UUIDs** based on entity names, ensuring:
- Re-runs don't create duplicates (idempotent)
- IDs are consistent across environments
- Cross-service references work correctly

## Prerequisites

- **Node.js 20+**
- **AWS CLI** configured with appropriate credentials
- **Network access** to the database (see Troubleshooting if DB is in private subnet)

## Installation

```bash
cd automation/seed
npm install
npm run build
```

## Usage

### Basic Usage

```bash
# Seed dev environment (default)
npm run seed

# Seed specific environment
npm run seed -- --env qa

# Use explicit database URL
DATABASE_URL="postgresql://user:pass@host:5432/leasebase" npm run seed
```

### Selective Seeding

```bash
# Only seed specific services
npm run seed -- --only property_service,tenant_service,lease_service

# Skip specific services
npm run seed -- --skip reporting_service,notification_service
```

### Available Services

- `property_service` - Properties and units
- `tenant_service` - Tenants and household members
- `lease_service` - Leases and rent schedules
- `maintenance_service` - Maintenance requests and vendors
- `payments_service` - Payment transactions
- `notification_service` - Templates and notifications
- `document_service` - Document metadata
- `reporting_service` - Report definitions and runs

### Production Safety

Production seeding is blocked by default. To seed production:

```bash
npm run seed -- --env prod --force-prod
```

⚠️ **Warning**: This modifies production data. Use with extreme caution.

### CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `-e, --env <env>` | Target environment (dev, qa, uat, prod) | `dev` |
| `--only <services>` | Only seed these services (comma-separated) | all |
| `--skip <services>` | Skip these services (comma-separated) | none |
| `--database-url <url>` | Database URL (overrides Secrets Manager) | - |
| `--force-prod` | Required flag to seed production | `false` |
| `--json` | Output results in JSON format | `false` |
| `--timeout <ms>` | Connection timeout in milliseconds | `3000` |

## Database Connection

### Connection Priority

1. **DATABASE_URL** environment variable or `--database-url` flag
2. **AWS Secrets Manager** with patterns:
   - `leasebase/<env>/<service>/db`
   - `leasebase/<service>-db`
   - `leasebase/<service>/db`

### Secret Format

Secrets should be JSON with these fields:

```json
{
  "host": "db.example.com",
  "port": 5432,
  "username": "leasebase",
  "password": "secret",
  "dbname": "leasebase",
  "ssl": true,
  "schema": "property_service"
}
```

### Schema Architecture

The tool assumes a **single database with separate schemas per service**:

```
leasebase (database)
├── property_service (schema)
├── tenant_service (schema)
├── lease_service (schema)
├── maintenance_service (schema)
├── payments_service (schema)
├── notification_service (schema)
├── document_service (schema)
└── reporting_service (schema)
```

When using `DATABASE_URL`, the seeder connects with an admin user and sets `search_path` for each service's schema.

## Output

### Console Output

The seeder provides colorized output showing:

```
╔══════════════════════════════════════════════════════════════╗
║          LeaseBase Demo Data Seeder                          ║
╚══════════════════════════════════════════════════════════════╝

  Environment: DEV
  Started:     2024-03-04T15:30:00.000Z

────────────────────────────────────────────────────────────────

▸ property_service
    ✓ properties: 2 rows
    ✓ units: 6 rows
  ✓ SEEDED

▸ tenant_service
    ✓ tenants: 3 rows
    ✓ household_members: 1 rows
  ✓ SEEDED

...

────────────────────────────────────────────────────────────────

Summary

  ✓ Seeded:  8 services (25 total rows)
  ⊘ Skipped: 0 services

  Duration: 2.34s
```

### JSON Output

Use `--json` for machine-readable output:

```bash
npm run seed -- --json
```

```json
{
  "status": "completed",
  "duration_seconds": 2.34,
  "seeded": {
    "property_service": { "properties": 2, "units": 6 },
    "tenant_service": { "tenants": 3, "household_members": 1 }
  },
  "skipped": []
}
```

## Troubleshooting

### Database Not Reachable

If the database is in a private subnet, you'll see:

```
⊘ SKIPPED: Connection timed out
  → Database may be in a private subnet. Try SSM port forwarding...
```

**Solutions:**

#### 1. SSM Port Forwarding

```bash
# Find an ECS task or EC2 instance in the VPC
aws ssm start-session \
  --target i-1234567890abcdef0 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["your-db.cluster-xxx.us-west-2.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5432"]}'

# In another terminal
DATABASE_URL="postgresql://user:pass@localhost:5432/leasebase" npm run seed
```

#### 2. Run as ECS Task

Deploy the seeder as a one-off ECS task within the VPC:

```bash
aws ecs run-task \
  --cluster leasebase-dev-cluster \
  --task-definition leasebase-seed \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx]}"
```

#### 3. Bastion Host

```bash
ssh -L 5432:your-db.cluster-xxx.rds.amazonaws.com:5432 ec2-user@bastion-ip

# In another terminal
DATABASE_URL="postgresql://user:pass@localhost:5432/leasebase" npm run seed
```

### Schema Not Initialized

```
⊘ SKIPPED: Schema not initialized
  → Run database migrations first
```

Run migrations before seeding:

```bash
# Example with Prisma
npx prisma migrate deploy
```

### Secret Not Found

```
⊘ SKIPPED: Secret not found (tried: leasebase/dev/property_service/db, ...)
  → Provide DATABASE_URL or create the secret in Secrets Manager
```

Either:
1. Set `DATABASE_URL` environment variable
2. Create the secret in AWS Secrets Manager

### Authentication Failed

```
⊘ SKIPPED: Authentication failed
  → Check database username and password
```

Verify credentials in Secrets Manager or DATABASE_URL.

## Demo Data Reference

### Organization

| ID | Name |
|----|------|
| `demo-org` | Demo Organization |

### Users (Logical IDs)

| Email | Role |
|-------|------|
| owner@demo.leasebase | OWNER |
| pm@demo.leasebase | PROPERTY_MANAGER |
| tenant@demo.leasebase | TENANT |
| vendor@demo.leasebase | VENDOR |

### Properties

| Name | Address | Units |
|------|---------|-------|
| Carro Drive 4-Plex | 123 Carro Drive, San Jose, CA | 4 |
| Gibbons Dr Duplex | 456 Gibbons Drive, Santa Clara, CA | 2 |

### Tenants

| Name | Email | Status |
|------|-------|--------|
| John Smith | john.smith@email.com | ACTIVE |
| Sarah Johnson | sarah.johnson@email.com | ACTIVE |
| Mike Williams | mike.williams@email.com | PROSPECTIVE |

## Development

### Adding a New Service

1. Create `src/seed/<service>.ts`:

```typescript
import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'new_service';

export async function seedNewService(pool: Pool): Promise<boolean> {
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('new_service', 'Schema not initialized');
    return false;
  }

  // Seed data...
  const data = [{ id: DEMO_IDS.SOMETHING, ... }];
  const count = await upsertMany(pool, `${SCHEMA}.table_name`, data);
  logger.seeded('new_service', 'table_name', count);

  return true;
}
```

2. Add to `src/config.ts` SERVICES array
3. Add to `src/shared/ids.ts` if new IDs needed
4. Import and register in `src/index.ts` SEEDERS map

### Adding New Demo IDs

Add to `src/shared/ids.ts`:

```typescript
export const DEMO_IDS = {
  // ...existing IDs
  NEW_ENTITY: deterministicId('service', 'entity', 'unique-name'),
};
```
