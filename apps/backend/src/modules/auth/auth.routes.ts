import type { FastifyPluginAsync, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { authService } from './auth.service.js';
import { db, schema } from '../../infra/db/index.js';
import { eq } from 'drizzle-orm';
import { config } from '../../config/index.js';

const exchange180Schema = z.object({
  code: z.string().min(1, 'Authorization code is required'),
  redirectUri: z.string().url().optional(),
  signPublicKey: z.string().length(64, 'Must be 64-char hex Ed25519 public key'),
  encPublicKey: z.string().length(64, 'Must be 64-char hex X25519 public key'),
  username: z.string().min(3).max(32).optional(),
  displayName: z.string().min(1).max(64).optional(),
});

// Middleware helper to authenticate requests
export async function authenticate(req: FastifyRequest, reply: FastifyReply): Promise<string> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    reply.status(401).send({ error: 'Missing or malformed Authorization header' });
    throw new Error('Unauthorized');
  }
  const token = authHeader.substring(7);
  const decoded = authService.verifyToken(token);
  if (!decoded) {
    reply.status(401).send({ error: 'Invalid or expired session token' });
    throw new Error('Unauthorized');
  }
  return decoded.sub;
}

export const authRoutes: FastifyPluginAsync = async (app) => {
  // 180 Identity Token Exchange & User Profile Verification
  app.post('/exchange', async (req, reply) => {
    const parse = exchange180Schema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const result = await authService.exchange180IdentityCode(parse.data);
      return reply.status(200).send({ success: true, ...result });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || '180 Identity exchange failed' });
    }
  });

  // Alias endpoint for explicit 180 Identity client calls
  app.post('/180identity/exchange', async (req, reply) => {
    const parse = exchange180Schema.safeParse(req.body);
    if (!parse.success) {
      return reply.status(400).send({ error: 'Validation failed', details: parse.error.issues });
    }
    try {
      const result = await authService.exchange180IdentityCode(parse.data);
      return reply.status(200).send({ success: true, ...result });
    } catch (err: any) {
      return reply.status(400).send({ error: err.message || '180 Identity exchange failed' });
    }
  });

  // Get 180 Identity Universal Authorize URL
  app.get('/authorize-url', async (req, reply) => {
    const { redirectUri, state } = req.query as { redirectUri?: string; state?: string };
    const authorizeUrl = authService.get180IdentityAuthorizeUrl(redirectUri, state);
    return reply.status(200).send({
      success: true,
      authorizeUrl,
      clientId: config.CLIENT_ID,
      authUrl: config.AUTH_URL,
    });
  });

  // Get Current Authenticated Profile
  app.get('/me', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const user = await authService.getUserById(userId);
    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }
    // Fetch user stealth settings
    const [settings] = await db.select().from(schema.stealthSettings).where(eq(schema.stealthSettings.userId, userId)).limit(1);
    return reply.status(200).send({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        signPublicKey: user.signPublicKey,
        encPublicKey: user.encPublicKey,
        moodStatus: user.moodStatus,
        createdAt: user.createdAt,
      },
      stealthSettings: settings || null,
    });
  });

  // Search Users by Username (for finding partners)
  app.get('/search', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const { q } = req.query as { q?: string };
    if (!q || q.trim().length < 1) {
      return reply.status(200).send({ users: [] });
    }
    const results = await authService.searchUsers(q, userId);
    return reply.status(200).send({ users: results });
  });

  // Update Mood Status (Romantic / Partner status)
  app.put('/mood', async (req, reply) => {
    const userId = await authenticate(req, reply);
    const { moodStatus } = req.body as { moodStatus?: string };
    if (!moodStatus || typeof moodStatus !== 'string') {
      return reply.status(400).send({ error: 'Invalid moodStatus string' });
    }
    const [updated] = await db.update(schema.users)
      .set({ moodStatus: moodStatus.trim().slice(0, 64) })
      .where(eq(schema.users.id, userId))
      .returning();
    return reply.status(200).send({ success: true, moodStatus: updated.moodStatus });
  });
};
