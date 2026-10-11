import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { safetyService } from './safety.service.js';
import { authenticate } from '../auth/auth.routes.js';

const blockUserSchema = z.object({
  blockedId: z.string().min(1),
  reason: z.string().max(64).optional(),
});

const nukeSchema = z.object({
  partnerId: z.string().min(1),
});

const updateGhostSchema = z.object({
  aliasName: z.string().min(2).max(64).optional(),
  avatarPreset: z.string().max(32).optional(),
  isActive: z.boolean().optional(),
});

export const safetyRoutes: FastifyPluginAsync = async (app) => {
  // Block user
  app.post('/block', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = blockUserSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const record = await safetyService.blockUser(userId, parse.data.blockedId, parse.data.reason);
      return reply.status(200).send({ success: true, blocked: record });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Block failed' });
    }
  });

  // Unblock user
  app.delete('/block/:blockedId', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const { blockedId } = req.params as { blockedId: string };
    try {
      await safetyService.unblockUser(userId, blockedId);
      return reply.status(200).send({ success: true });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Unblock failed' });
    }
  });

  // Get blocked users list
  app.get('/blocked', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const list = await safetyService.getBlockedUsers(userId);
      return reply.status(200).send({ blockedUsers: list });
    } catch (err: any) {
      return reply.status(500).send({ error: err.message || 'Failed to fetch blocked users' });
    }
  });

  // Nuke conversation bidirectionally
  app.post('/nuke', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = nukeSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const result = await safetyService.nukeConversation(userId, parse.data.partnerId);
      return reply.status(200).send(result);
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Nuke failed' });
    }
  });

  // Get ghost persona
  app.get('/ghost-persona', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const persona = await safetyService.getOrGenerateGhostPersona(userId);
      return reply.status(200).send({ ghostPersona: persona });
    } catch (err: any) {
      return reply.status(500).send({ error: err.message || 'Failed to fetch ghost persona' });
    }
  });

  // Update ghost persona
  app.put('/ghost-persona', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = updateGhostSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const updated = await safetyService.updateGhostPersona(userId, parse.data);
      return reply.status(200).send({ success: true, ghostPersona: updated });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to update ghost persona' });
    }
  });
};
