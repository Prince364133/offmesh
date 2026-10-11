import type { FastifyPluginAsync } from 'fastify';
import { authService } from '../auth/auth.service.js';
import { fcmService } from './fcm.service.js';

export const notificationRoutes: FastifyPluginAsync = async (app) => {
  // Authentication middleware
  const authenticate = async (req: any, reply: any) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.code(401).send({ error: 'Missing or malformed Authorization header' });
    }
    const token = authHeader.substring(7);
    const decoded = authService.verifyToken(token);
    if (!decoded) {
      return reply.code(401).send({ error: 'Invalid or expired session token' });
    }
    req.user = decoded;
  };

  /**
   * POST /api/v1/notifications/token
   * Register an FCM device token for background push alerts.
   */
  app.post('/token', {
    preHandler: [authenticate],
    schema: {
      tags: ['Notifications'],
      description: 'Register FCM device push token for background notifications',
      body: {
        type: 'object',
        required: ['fcmToken'],
        properties: {
          fcmToken: { type: 'string' },
          platform: { type: 'string', enum: ['android', 'ios', 'web'] },
        },
      },
    },
  }, async (req: any) => {
    const userId = req.user.sub;
    const { fcmToken } = req.body;
    fcmService.registerToken(userId, fcmToken);
    return {
      success: true,
      registered: true,
      tokenCount: fcmService.getUserTokens(userId).length,
    };
  });

  /**
   * DELETE /api/v1/notifications/token
   * Unregister an FCM device token on logout.
   */
  app.delete('/token', {
    preHandler: [authenticate],
    schema: {
      tags: ['Notifications'],
      description: 'Unregister FCM device push token',
      body: {
        type: 'object',
        required: ['fcmToken'],
        properties: {
          fcmToken: { type: 'string' },
        },
      },
    },
  }, async (req: any) => {
    const userId = req.user.sub;
    const { fcmToken } = req.body;
    fcmService.unregisterToken(userId, fcmToken);
    return {
      success: true,
      unregistered: true,
    };
  });

  /**
   * POST /api/v1/notifications/test
   * Dispatch a test push notification to user's registered devices.
   */
  app.post('/test', {
    preHandler: [authenticate],
    schema: {
      tags: ['Notifications'],
      description: 'Send a test push notification to verify FCM delivery',
      body: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          body: { type: 'string' },
        },
      },
    },
  }, async (req: any) => {
    const userId = req.user.sub;
    const title = req.body?.title || 'OffMesh Haven Test';
    const body = req.body?.body || 'Hardware and push notification test signal received successfully!';

    const result = await fcmService.sendPushToUser(userId, {
      title,
      body,
      priority: 'high',
      data: {
        type: 'TEST_SIGNAL',
        timestamp: Date.now().toString(),
      },
    });

    return {
      success: true,
      ...result,
    };
  });
};
