import { Queue } from 'bullmq';
import { redis } from '../redis/index.js';

export const BUNDLE_QUEUE_NAME = 'nearlink-bundle-queue';
export const MERKLE_QUEUE_NAME = 'nearlink-merkle-queue';
export const TTL_QUEUE_NAME = 'nearlink-ttl-queue';

// BullMQ Queues
export const bundleQueue = new Queue(BUNDLE_QUEUE_NAME, {
  connection: redis,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 1000 },
    removeOnComplete: true,
  },
});

export const merkleQueue = new Queue(MERKLE_QUEUE_NAME, {
  connection: redis,
  defaultJobOptions: {
    attempts: 2,
    removeOnComplete: true,
  },
});

export const ttlQueue = new Queue(TTL_QUEUE_NAME, {
  connection: redis,
  defaultJobOptions: {
    attempts: 1,
    removeOnComplete: true,
  },
});
