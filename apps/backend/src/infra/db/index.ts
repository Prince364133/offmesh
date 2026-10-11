import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { config } from '../../config/index.js';
import * as schema from './schema.js';

let client: postgres.Sql;

const isSslRequired = config.DATABASE_URL.includes('sslmode=require') || 
                      config.DATABASE_URL.includes('ssl=require') || 
                      config.DATABASE_URL.includes('rds.amazonaws.com');

try {
  client = postgres(config.DATABASE_URL, {
    max: 10,
    idle_timeout: 20,
    connect_timeout: 10,
    ssl: isSslRequired ? 'require' : undefined,
  });
} catch (e) {
  console.warn('Warning: Postgres connection initialization failed, using lazy client');
  client = postgres(config.DATABASE_URL, { 
    max: 1, 
    ssl: isSslRequired ? 'require' : undefined 
  });
}

export const db = drizzle(client, { schema });
export { schema };
