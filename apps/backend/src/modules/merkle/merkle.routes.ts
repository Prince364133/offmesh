import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { merkleTreeService } from './merkle.service.js';

const reconcileSchema = z.object({
  rootHashHex: z.string().length(64),
  dayHashes: z.record(z.string(), z.string().length(64)),
});

export const merkleRoutes: FastifyPluginAsync = async (app) => {
  // Query 32-byte global root hash (O(1) microsecond sync probe)
  app.get('/root', async (req, reply) => {
    const rootHashHex = merkleTreeService.getRootHash();
    return reply.status(200).send({
      rootHashHex,
      timestamp: Date.now(),
    });
  });

  // Reconcile tree differences (microsecond diff resolution)
  app.post('/reconcile', async (req, reply) => {
    const parse = reconcileSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid reconcile payload', details: parse.error.issues });
    }
    const result = merkleTreeService.reconcile(parse.data.rootHashHex, parse.data.dayHashes);
    return reply.status(200).send(result);
  });
};
