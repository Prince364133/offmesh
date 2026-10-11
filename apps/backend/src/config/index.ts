import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  BACKEND_URL: z.string().default('http://localhost:3000'),
  CORS_ORIGIN: z.string().default('*'),
  DATABASE_URL: z.string().default('postgresql://pitchin_admin:P8DeNPdMPsIipBRv0ZgiVbgrmIJcziQp@pitchin-db.csne8mek4dog.us-east-1.rds.amazonaws.com:5432/offmesh_db?sslmode=require'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  MERKLE_BUCKET_MINUTES: z.coerce.number().default(5),
  MERKLE_SWEEP_INTERVAL_MINUTES: z.coerce.number().default(15),
  JWT_SECRET: z.string().default('haven_dev_secret_key_change_in_production_2026_super_secure_offline_haven'),
  SESSION_SECRET: z.string().default('haven_dev_session_secret_local_development_only'),
  R2_ACCOUNT_ID: z.string().optional().default('7158d01d5e0dd9e7f5be050ed3717b14'),
  R2_ACCESS_KEY_ID: z.string().optional().default(''),
  R2_SECRET_ACCESS_KEY: z.string().optional().default(''),
  R2_ACCESS_KEY: z.string().optional(),
  R2_SECRET_KEY: z.string().optional(),
  R2_BUCKET_NAME: z.string().default('offmesh'),
  R2_PUBLIC_DOMAIN: z.string().default('https://7158d01d5e0dd9e7f5be050ed3717b14.r2.cloudflarestorage.com/offmesh'),
  PAYMENT_PROVIDER: z.enum(['mock', 'stripe', '180pay']).default('180pay'),
  // Unified 180 Core Credentials (Shared by 180 Identity & 180 Pay)
  CLIENT_ID: z.string().default('180_client_6182d7379831a5524c834e2fe8c58e68'),
  CLIENT_SECRET: z.string().default('180_secret_d3ef7341bd69d7431a6e05bf3bad804c21d4ff5ec2b30d33fb081eed290810cd'),
  WEBHOOK_SECRET: z.string().default('whsec_49127795658766d61bb1e84c757ffbdde3eda005576f4117'),
  API_URL: z.string().default('https://services.180workspace.com'),
  AUTH_URL: z.string().default('https://auth.180workspace.com'),

  // Backwards-compatible aliases (fallback to unified 180 Core credentials)
  PAY180_CLIENT_ID: z.string().optional(),
  PAY180_CLIENT_SECRET: z.string().optional(),
  PAY180_WEBHOOK_SECRET: z.string().optional(),
  PAY180_API_URL: z.string().optional(),
  ONE_EIGHTY_CLIENT_ID: z.string().optional(),
  ONE_EIGHTY_CLIENT_SECRET: z.string().optional(),
  ONE_EIGHTY_AUTH_URL: z.string().optional(),
  ONE_EIGHTY_API_URL: z.string().optional(),
  ONE_EIGHTY_WEBHOOK_SECRET: z.string().optional(),

  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_PUBLISHABLE_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
  STRIPE_PRICE_ID_MONTHLY_5: z.string().optional(),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  FCM_PROJECT_ID: z.string().default('offmesh'),
  FCM_CLIENT_EMAIL: z.string().default('firebase-adminsdk-fbsvc@offmesh.iam.gserviceaccount.com'),
  FCM_PRIVATE_KEY: z.string().optional(),
  GOOGLE_APPLICATION_CREDENTIALS: z.string().optional().default('c:/Users/saavi/Desktop/offmesh/offmesh-firebase-adminsdk-fbsvc-a7b98bd576.json'),
});

const rawConfig = configSchema.parse(process.env);

export const config = {
  ...rawConfig,
  ONE_EIGHTY_CLIENT_ID: rawConfig.ONE_EIGHTY_CLIENT_ID || rawConfig.CLIENT_ID,
  ONE_EIGHTY_CLIENT_SECRET: rawConfig.ONE_EIGHTY_CLIENT_SECRET || rawConfig.CLIENT_SECRET,
  ONE_EIGHTY_AUTH_URL: rawConfig.ONE_EIGHTY_AUTH_URL || rawConfig.AUTH_URL,
  ONE_EIGHTY_API_URL: rawConfig.ONE_EIGHTY_API_URL || rawConfig.API_URL,
  ONE_EIGHTY_WEBHOOK_SECRET: rawConfig.ONE_EIGHTY_WEBHOOK_SECRET || rawConfig.WEBHOOK_SECRET,
  PAY180_CLIENT_ID: rawConfig.PAY180_CLIENT_ID || rawConfig.CLIENT_ID,
  PAY180_CLIENT_SECRET: rawConfig.PAY180_CLIENT_SECRET || rawConfig.CLIENT_SECRET,
  PAY180_WEBHOOK_SECRET: rawConfig.PAY180_WEBHOOK_SECRET || rawConfig.WEBHOOK_SECRET,
  PAY180_API_URL: rawConfig.PAY180_API_URL || rawConfig.API_URL,
  R2_ACCESS_KEY_ID: rawConfig.R2_ACCESS_KEY_ID || rawConfig.R2_ACCESS_KEY || '',
  R2_SECRET_ACCESS_KEY: rawConfig.R2_SECRET_ACCESS_KEY || rawConfig.R2_SECRET_KEY || '',
  R2_ACCESS_KEY: rawConfig.R2_ACCESS_KEY || rawConfig.R2_ACCESS_KEY_ID || '',
  R2_SECRET_KEY: rawConfig.R2_SECRET_KEY || rawConfig.R2_SECRET_ACCESS_KEY || '',
};
