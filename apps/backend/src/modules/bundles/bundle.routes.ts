import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { bundleService } from './bundle.service.js';

const uploadBundleSchema = z.object({
  payloadBase64: z.string().min(100),
});

export const bundleRoutes: FastifyPluginAsync = async (app) => {
  // Upload / Ingest bundle
  app.post('/upload', async (req, reply) => {
    const parse = uploadBundleSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid payloadBase64 string', details: parse.error.issues });
    }
    try {
      const result = await bundleService.ingestBundle(parse.data.payloadBase64);
      if (result.status === 'DUPLICATE') {
        return reply.status(409).send({ status: 'DUPLICATE', msgId: result.msgIdHex });
      }
      if (result.status === 'EXPIRED') {
        return reply.status(410).send({ status: 'EXPIRED', msgId: result.msgIdHex });
      }
      return reply.status(201).send({ status: 'ACCEPTED', msgId: result.msgIdHex });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Bundle ingestion failed' });
    }
  });

  // Fetch mailbox for recipient
  app.get('/mailbox/:recipientIdHex', async (req, reply) => {
    const { recipientIdHex } = req.params as { recipientIdHex: string };
    if (!recipientIdHex || recipientIdHex.length !== 64) {
      return reply.status(400).send({ error: 'Invalid recipientIdHex parameter' });
    }
    try {
      const messages = await bundleService.getMailbox(recipientIdHex);
      return reply.status(200).send({ count: messages.length, bundles: messages });
    } catch (err: any) {
      return reply.status(500).send({ error: err.message || 'Failed to fetch mailbox' });
    }
  });
};
