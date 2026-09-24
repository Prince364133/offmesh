import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { receiptService } from './receipt.service.js';

const submitReceiptSchema = z.object({
  payloadBase64: z.string().min(50),
});

export const receiptRoutes: FastifyPluginAsync = async (app) => {
  // Ingest delivery receipt (anti-packet)
  app.post('/submit', async (req, reply) => {
    const parse = submitReceiptSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid payloadBase64 string', details: parse.error.issues });
    }
    try {
      const res = await receiptService.ingestReceipt(parse.data.payloadBase64);
      return reply.status(200).send(res);
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Receipt processing failed' });
    }
  });

  // Get receipt by message ID
  app.get('/:msgIdHex', async (req, reply) => {
    const { msgIdHex } = req.params as { msgIdHex: string };
    if (!msgIdHex || msgIdHex.length !== 32) {
      return reply.status(400).send({ error: 'Invalid msgIdHex parameter' });
    }
    const receipt = await receiptService.getReceipt(msgIdHex);
    if (!receipt) {
      return reply.status(404).send({ error: 'Receipt not found' });
    }
    return reply.status(200).send({ receipt });
  });
};
