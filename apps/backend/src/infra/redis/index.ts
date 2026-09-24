import { Redis } from 'ioredis';
import { config } from '../../config/index.js';

let redisClient: Redis;

export function getRedisClient(): Redis {
  if (redisClient) return redisClient;

  redisClient = new Redis(config.REDIS_URL, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    retryStrategy(times: number) {
      if (times > 3 && config.NODE_ENV === 'test') {
        return null; // Don't retry endlessly in test
      }
      return Math.min(times * 100, 3000);
    },
    lazyConnect: true,
  });

  redisClient.on('error', (err: any) => {
    // Log once, suppress spam if offline in dev
    if (config.NODE_ENV === 'development') {
      console.warn(`[Redis Notice] Connection to ${config.REDIS_URL} pending: ${err.message}`);
    }
  });

  return redisClient;
}

export const redis = getRedisClient();
