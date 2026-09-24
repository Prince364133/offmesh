import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { identityService } from './identity.service.js';

const registerCardSchema = z.object({
  card: z.string().refine((c) => c.startsWith('OM1:') || c.startsWith('NL1:'), {
    message: "Contact card must start with 'OM1:' or 'NL1:'",
  }),
});

const challengeSchema = z.object({
  idHex: z.string().length(64),
});

const verifyChallengeSchema = z.object({
  idHex: z.string().length(64),
  signatureHex: z.string().length(128),
});

export const identityRoutes: FastifyPluginAsync = async (app) => {
  // Register contact card
  app.post('/register', async (req, reply) => {
    const parse = registerCardSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid contact card format', details: parse.error.issues });
    }
    try {
      const registered = await identityService.registerCard(parse.data.card);
      return reply.status(200).send({ success: true, identity: registered });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Registration failed' });
    }
  });

  // Get identity by ID
  app.get('/:idHex', async (req, reply) => {
    const { idHex } = req.params as { idHex: string };
    if (!idHex || idHex.length !== 64) {
      return reply.status(400).send({ error: 'Invalid idHex' });
    }
    const identity = await identityService.getIdentity(idHex);
    if (!identity) {
      return reply.status(404).send({ error: 'Identity not found' });
    }
    return reply.status(200).send({ identity });
  });

  // Request auth challenge
  app.post('/challenge', async (req, reply) => {
    const parse = challengeSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid idHex parameter' });
    }
    const challenge = await identityService.createAuthChallenge(parse.data.idHex);
    return reply.status(200).send(challenge);
  });

  // Verify auth challenge
  app.post('/verify', async (req, reply) => {
    const parse = verifyChallengeSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid verify parameters' });
    }
    const ok = await identityService.verifyAuthChallenge(parse.data.idHex, parse.data.signatureHex);
    if (!ok) {
      return reply.status(401).send({ error: 'Challenge signature verification failed' });
    }
    return reply.status(200).send({ authenticated: true, idHex: parse.data.idHex });
  });
};
