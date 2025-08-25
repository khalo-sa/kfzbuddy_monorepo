import { z } from 'zod';

// Environment label constants
export const EnvironmentLabel = {
  PROD: 'prod',
  STAG: 'stag',
  DEV: 'dev',
} as const;

export type EnvironmentLabel =
  (typeof EnvironmentLabel)[keyof typeof EnvironmentLabel];

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  VAPI_API_KEY: z.string().min(1, 'VAPI_API_KEY is required'),
  EXTERNAL_API_TOKEN: z.string().min(1, 'EXTERNAL_API_TOKEN is required'),
  AUTH_SECRET: z.string().min(1, 'AUTH_SECRET is required'),
  HOST_URL: z.url(),
  NGROK_HOST_URL: z.url().optional(),
  STRIPE_SECRET_KEY: z.string().min(1, 'STRIPE_SECRET_KEY is required'),
  STRIPE_WEBHOOK_SECRET: z.string().min(1, 'STRIPE_WEBHOOK_SECRET is required'),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  LOG_LEVEL: z
    .enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace'])
    .default('info'),
});

export const loadEnv = () => {
  const env = envSchema.parse(process.env);
  return env;
};

// Base env object
const baseEnv = loadEnv();

// Extended env object with computed properties
export const env = {
  ...baseEnv,

  // Environment label based on BASE_URL (similar to vapi-crud pattern)
  envLabel: (() => {
    if (baseEnv.HOST_URL.includes('app.kfzbuddy.de')) {
      return EnvironmentLabel.PROD;
    }
    if (
      baseEnv.HOST_URL.includes('app-staging.kfzbuddy.de') ||
      baseEnv.HOST_URL.includes('railway.app')
    ) {
      return EnvironmentLabel.STAG;
    }
    if (baseEnv.HOST_URL.includes('localhost') || baseEnv.NGROK_HOST_URL) {
      return EnvironmentLabel.DEV;
    }
    throw new Error(
      `Unable to determine environment from BASE_URL: ${baseEnv.HOST_URL}. Expected to contain 'app.kfzbuddy.de', 'app-staging.kfzbuddy.de', 'railway.app', 'ngrok', or 'localhost'`
    );
  })(),
};
