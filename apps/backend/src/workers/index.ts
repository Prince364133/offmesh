import { Worker } from 'bullmq';
import { redis } from '../infra/redis/index.js';
import { BUNDLE_QUEUE_NAME, MERKLE_QUEUE_NAME, TTL_QUEUE_NAME } from '../infra/queue/index.js';
import { gatewayManager } from '../modules/gateway/gateway.manager.js';
import { merkleTreeService } from '../modules/merkle/merkle.service.js';
import { bundleService } from '../modules/bundles/bundle.service.js';

export function startWorkers() {
  console.log('[Workers] Initializing BullMQ background workers...');

  // 1. Bundle Processing Worker
  const bundleWorker = new Worker(
    BUNDLE_QUEUE_NAME,
    async (job) => {
      const { msgIdHex, recipientIdHex } = job.data;
      // If recipient is currently online over WebSocket, push directly
      if (gatewayManager.isOnline(recipientIdHex)) {
        const mailbox = await bundleService.getMailbox(recipientIdHex);
        const match = mailbox.find((b) => b.id === msgIdHex);
        if (match) {
          gatewayManager.sendToPeer(recipientIdHex, {
            type: 'BUNDLE_OFFER',
            data: match,
          });
          console.log(`[Worker] Pushed bundle ${msgIdHex.substring(0, 8)} to online peer ${recipientIdHex.substring(0, 8)}`);
        }
      }
    },
    { connection: redis, concurrency: 5 }
  );

  // 2. Merkle Indexer Worker
  const merkleWorker = new Worker(
    MERKLE_QUEUE_NAME,
    async (job) => {
      const { msgIdHex, deliveredAtMs } = job.data;
      merkleTreeService.insertRecord({
        id: msgIdHex,
        timestampMs: deliveredAtMs,
      });

      // Broadcast anti-packet to all connected peers
      gatewayManager.broadcast({
        type: 'ANTI_PACKET_PRUNE',
        data: { msgIdHex, deliveredAtMs },
      });
      console.log(`[Worker] Indexed receipt ${msgIdHex.substring(0, 8)} into Merkle tree and broadcasted prune`);
    },
    { connection: redis, concurrency: 5 }
  );

  // 3. TTL Sweeper Worker
  const ttlWorker = new Worker(
    TTL_QUEUE_NAME,
    async (job) => {
      console.log('[Worker] Executing TTL sweep for expired bundles...');
      // Logic for sweeping expired entries
    },
    { connection: redis }
  );

  bundleWorker.on('error', (err) => console.warn(`[BundleWorker] Notice: ${err.message}`));
  merkleWorker.on('error', (err) => console.warn(`[MerkleWorker] Notice: ${err.message}`));
  ttlWorker.on('error', (err) => console.warn(`[TtlWorker] Notice: ${err.message}`));

  return { bundleWorker, merkleWorker, ttlWorker };
}
