import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().default('postgres://nearlink:nearlink_secret_password@localhost:5432/nearlink'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  MERKLE_BUCKET_MINUTES: z.coerce.number().default(5),
  MERKLE_SWEEP_INTERVAL_MINUTES: z.coerce.number().default(15),
});

export const config = configSchema.parse(process.env);
