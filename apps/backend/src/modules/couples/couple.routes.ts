import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { coupleService } from './couple.service.js';
import { authenticate } from '../auth/auth.routes.js';

const requestCoupleSchema = z.object({
  partnerUsername: z.string().min(1),
});

const respondCoupleSchema = z.object({
  coupleId: z.string().uuid(),
  accept: z.boolean(),
});

const updateDetailsSchema = z.object({
  anniversaryDate: z.string().datetime().optional(),
  nicknameForPartner: z.string().max(64).optional(),
});

const updateStealthSchema = z.object({
  appDisguise: z.enum(['CALCULATOR', 'NOTES', 'WEATHER', 'OFFMESH']).optional(),
  decoyPin: z.string().min(4).max(16).optional(),
  notifDisguiseMode: z.enum(['CAMOUFLAGE', 'DISCREET', 'NINJA', 'ROMANTIC']).optional(),
  fakeSenderTitle: z.string().max(64).optional(),
  fakeBodyPreview: z.string().max(128).optional(),
});

export const coupleRoutes: FastifyPluginAsync = async (app) => {
  // Request couple pairing
  app.post('/request', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = requestCoupleSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid partnerUsername', details: parse.error.issues });
    }
    try {
      const couple = await coupleService.requestCouple(userId, parse.data.partnerUsername);
      return reply.status(200).send({ success: true, couple });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Couple request failed' });
    }
  });

  // Respond to couple request (Accept or Reject)
  app.post('/respond', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = respondCoupleSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const couple = await coupleService.respondCouple(userId, parse.data.coupleId, parse.data.accept);
      return reply.status(200).send({ success: true, couple });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to respond to request' });
    }
  });

  // Get current couple status and romantic milestones
  app.get('/status', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const details = await coupleService.getCoupleStatus(userId);
      return reply.status(200).send({ couple: details });
    } catch (err: any) {
      return reply.status(500).send({ error: err.message || 'Failed to fetch couple status' });
    }
  });

  // Update anniversary date or nickname
  app.put('/details', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = updateDetailsSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const updated = await coupleService.updateCoupleDetails(userId, parse.data);
      return reply.status(200).send({ success: true, couple: updated });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to update details' });
    }
  });

  // Get user's stealth & notification disguise settings
  app.get('/stealth', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const settings = await coupleService.getStealthSettings(userId);
      return reply.status(200).send({ stealthSettings: settings });
    } catch (err: any) {
      return reply.status(500).send({ error: err.message || 'Failed to fetch stealth settings' });
    }
  });

  // Update user's stealth & notification disguise settings
  app.put('/stealth', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const parse = updateStealthSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const settings = await coupleService.updateStealthSettings(userId, parse.data);
      return reply.status(200).send({ success: true, stealthSettings: settings });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to update stealth settings' });
    }
  });

  // Get mutual permissions (self & partner)
  app.get('/permissions', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const mutual = await coupleService.getMutualPermissions(userId);
      return reply.status(200).send(mutual);
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to fetch permissions' });
    }
  });

  // Update authenticated user's permissions
  app.put('/permissions', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const updatePermissionsSchema = z.object({
      allowVibrate: z.boolean().optional(),
      allowRing: z.boolean().optional(),
      allowFlashlight: z.boolean().optional(),
      blockScreenshots: z.boolean().optional(),
      blockSaving: z.boolean().optional(),
      blockCopying: z.boolean().optional(),
    });
    const parse = updatePermissionsSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const updated = await coupleService.updatePermissions(userId, parse.data);
      return reply.status(200).send({ success: true, permissions: updated });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to update permissions' });
    }
  });

  // Trigger remote signal (BUZZ, RING, FLASHLIGHT) to partner
  app.post('/signal', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const signalSchema = z.object({
      signalType: z.enum(['BUZZ', 'RING', 'FLASHLIGHT']),
    });
    const parse = signalSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Invalid signalType. Must be BUZZ, RING, or FLASHLIGHT' });
    }
    try {
      const result = await coupleService.sendSignal(userId, parse.data.signalType);
      return reply.status(200).send(result);
    } catch (err: any) {
      return reply.status(403).send({ error: err.message || 'Signal disallowed or failed' });
    }
  });

  // Generate ephemeral Cloudflare R2 upload URL (7-day TTL)
  app.post('/media/upload-url', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const uploadUrlSchema = z.object({
      filename: z.string().min(1),
      mimeType: z.string().min(1),
      blockSaving: z.boolean().optional(),
    });
    const parse = uploadUrlSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const uploadData = await coupleService.generateEphemeralUploadUrl(
        userId,
        parse.data.filename,
        parse.data.mimeType,
        parse.data.blockSaving
      );
      return reply.status(200).send(uploadData);
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to generate upload URL' });
    }
  });

  // Upload raw binary ephemeral media (images, videos, audio notes)
  app.put('/media/upload', async (req, reply) => {
    const { key } = req.query as { key?: string };
    if (!key) {
      return reply.status(400).send({ error: 'Missing key query parameter' });
    }
    const contentType = (req.headers['content-type'] as string) || 'application/octet-stream';
    let buffer: Buffer;

    if (Buffer.isBuffer(req.body)) {
      buffer = req.body;
    } else if (typeof req.body === 'string') {
      buffer = Buffer.from(req.body, 'base64');
    } else {
      buffer = Buffer.from(JSON.stringify(req.body || ''));
    }

    coupleService.saveUploadedMedia(key, buffer, contentType);
    return reply.status(200).send({ success: true, key, sizeBytes: buffer.length });
  });

  // Retrieve ephemeral media for viewing
  app.get('/media/file/*', async (req, reply) => {
    const rawPath = (req.params as any)['*'] || '';
    const key = decodeURIComponent(rawPath);
    const item = coupleService.getUploadedMedia(key);
    if (!item) {
      return reply.status(404).send({ error: 'Media file not found or expired' });
    }
    return reply
      .header('Content-Type', item.mimeType)
      .header('Cache-Control', 'public, max-age=86400')
      .send(item.buffer);
  });

  // Confirm uploaded ephemeral media metadata (7-day TTL)
  app.post('/media/confirm', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const confirmMediaSchema = z.object({
      mediaKey: z.string().min(1),
      mediaUrl: z.string().url(),
      mimeType: z.string().min(1),
      sizeBytes: z.number().int().nonnegative().optional(),
      blockSaving: z.boolean().optional(),
      durationSeconds: z.number().int().nonnegative().optional(),
      maxViews: z.number().int().min(0).max(5).optional(),
      watermarkEnabled: z.boolean().optional(),
    });
    const parse = confirmMediaSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const media = await coupleService.recordEphemeralMedia(userId, parse.data);
      return reply.status(200).send({ success: true, media });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to record media' });
    }
  });

  // Consume view for N-view ephemeral media
  app.post('/media/view/:mediaId', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const { mediaId } = req.params as { mediaId: string };
    try {
      const result = await coupleService.consumeMediaView(userId, mediaId);
      return reply.status(200).send({ success: true, ...result });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to consume media view' });
    }
  });

  // Get chat wallpaper and customization
  app.get('/customization', async (req, reply) => {
    const userId = await authenticate(req, reply);
    try {
      const customization = await coupleService.getChatCustomization(userId);
      return reply.status(200).send({ customization });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to fetch customization' });
    }
  });

  // Update chat wallpaper and customization
  app.put('/customization', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const updateCustomizationSchema = z.object({
      wallpaperUrl: z.string().nullable().optional(),
      themeColor: z.string().max(32).optional(),
    });
    const parse = updateCustomizationSchema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const customization = await coupleService.updateChatCustomization(userId, parse.data);
      return reply.status(200).send({ success: true, customization });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || 'Failed to update customization' });
    }
  });
};
