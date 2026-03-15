import type { Pool } from 'pg';
import { DEMO_IDS } from '../shared/ids.js';
import { upsertMany, schemaExists, tableExists } from '../shared/sql.js';
import { logger } from '../shared/logger.js';

const SCHEMA = 'property_service';

export async function seedPropertyService(pool: Pool): Promise<boolean> {
  // Check schema exists
  if (!(await schemaExists(pool, SCHEMA))) {
    logger.skip('property_service', 'Schema not initialized', 'Run database migrations first');
    return false;
  }

  // Check required table exists
  if (!(await tableExists(pool, SCHEMA, 'properties'))) {
    logger.skip('property_service', 'Tables not initialized', 'Run database migrations first');
    return false;
  }

  // Seed properties
  const properties = [
    {
      id: DEMO_IDS.PROPERTY_CARRO,
      organization_id: DEMO_IDS.ORG,
      name: 'Carro Drive 4-Plex',
      address_line1: '123 Carro Drive',
      address_line2: null,
      city: 'San Jose',
      state: 'CA',
      zip_code: '95123',
      country: 'USA',
      property_type: 'MULTI_FAMILY',
      year_built: 1985,
      total_units: 4,
      total_sqft: 4800,
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.PROPERTY_GIBBONS,
      organization_id: DEMO_IDS.ORG,
      name: 'Gibbons Dr Duplex',
      address_line1: '456 Gibbons Drive',
      address_line2: null,
      city: 'Santa Clara',
      state: 'CA',
      zip_code: '95051',
      country: 'USA',
      property_type: 'DUPLEX',
      year_built: 1992,
      total_units: 2,
      total_sqft: 2400,
      created_at: new Date(),
      updated_at: new Date(),
    },
  ];

  const propCount = await upsertMany(pool, `${SCHEMA}.properties`, properties);
  logger.seeded('property_service', 'properties', propCount);

  // Seed units
  const units = [
    // Carro Drive units
    {
      id: DEMO_IDS.UNIT_CARRO_101,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_number: '101',
      floor: 1,
      bedrooms: 2,
      bathrooms: 1,
      sqft: 1200,
      rent_amount: 2200,
      status: 'OCCUPIED',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.UNIT_CARRO_102,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_number: '102',
      floor: 1,
      bedrooms: 2,
      bathrooms: 1,
      sqft: 1200,
      rent_amount: 2200,
      status: 'VACANT',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.UNIT_CARRO_201,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_number: '201',
      floor: 2,
      bedrooms: 2,
      bathrooms: 1,
      sqft: 1200,
      rent_amount: 2300,
      status: 'VACANT',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.UNIT_CARRO_202,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_CARRO,
      unit_number: '202',
      floor: 2,
      bedrooms: 2,
      bathrooms: 1,
      sqft: 1200,
      rent_amount: 2300,
      status: 'VACANT',
      created_at: new Date(),
      updated_at: new Date(),
    },
    // Gibbons Dr units
    {
      id: DEMO_IDS.UNIT_GIBBONS_A,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_GIBBONS,
      unit_number: 'A',
      floor: 1,
      bedrooms: 3,
      bathrooms: 2,
      sqft: 1400,
      rent_amount: 2800,
      status: 'OCCUPIED',
      created_at: new Date(),
      updated_at: new Date(),
    },
    {
      id: DEMO_IDS.UNIT_GIBBONS_B,
      organization_id: DEMO_IDS.ORG,
      property_id: DEMO_IDS.PROPERTY_GIBBONS,
      unit_number: 'B',
      floor: 1,
      bedrooms: 3,
      bathrooms: 2,
      sqft: 1000,
      rent_amount: 2600,
      status: 'VACANT',
      created_at: new Date(),
      updated_at: new Date(),
    },
  ];

  const unitCount = await upsertMany(pool, `${SCHEMA}.units`, units);
  logger.seeded('property_service', 'units', unitCount);

  // Seed amenities (if table exists)
  if (await tableExists(pool, SCHEMA, 'property_amenities')) {
    const amenities = [
      { id: DEMO_IDS.PROPERTY_CARRO + '-parking', property_id: DEMO_IDS.PROPERTY_CARRO, amenity: 'Covered Parking', created_at: new Date() },
      { id: DEMO_IDS.PROPERTY_CARRO + '-laundry', property_id: DEMO_IDS.PROPERTY_CARRO, amenity: 'On-site Laundry', created_at: new Date() },
      { id: DEMO_IDS.PROPERTY_GIBBONS + '-yard', property_id: DEMO_IDS.PROPERTY_GIBBONS, amenity: 'Private Yard', created_at: new Date() },
      { id: DEMO_IDS.PROPERTY_GIBBONS + '-garage', property_id: DEMO_IDS.PROPERTY_GIBBONS, amenity: 'Attached Garage', created_at: new Date() },
    ];
    const amenityCount = await upsertMany(pool, `${SCHEMA}.property_amenities`, amenities);
    logger.seeded('property_service', 'property_amenities', amenityCount);
  }

  return true;
}
