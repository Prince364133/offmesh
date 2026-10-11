import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import websocket from '@fastify/websocket';
import fastifySwagger from '@fastify/swagger';
import fastifySwaggerUi from '@fastify/swagger-ui';
import { identityRoutes } from './modules/identity/identity.routes.js';
import { bundleRoutes } from './modules/bundles/bundle.routes.js';
import { receiptRoutes } from './modules/receipts/receipt.routes.js';
import { merkleRoutes } from './modules/merkle/merkle.routes.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { coupleRoutes } from './modules/couples/couple.routes.js';
import { billingRoutes } from './modules/billing/billing.routes.js';
import { safetyRoutes } from './modules/safety/safety.routes.js';
import { notificationRoutes } from './modules/notifications/notifications.routes.js';
import { authService } from './modules/auth/auth.service.js';
import { gatewayManager } from './modules/gateway/gateway.manager.js';
import { merkleTreeService } from './modules/merkle/merkle.service.js';
import { fcmService } from './modules/notifications/fcm.service.js';

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: process.env.NODE_ENV === 'test' ? 'silent' : 'info',
    },
  });

  await app.register(cors, { origin: '*' });
  await app.register(sensible);
  await app.register(websocket);

  // Accept binary payloads for raw media streaming (images, videos, audio notes)
  app.addContentTypeParser(
    /^(image|video|audio|application\/octet-stream).*/,
    { parseAs: 'buffer' },
    (_req, body, done) => {
      done(null, body);
    }
  );

  // OpenAPI Swagger Documentation
  await app.register(fastifySwagger, {
    openapi: {
      info: {
        title: 'OffMesh Modular Monolith API',
        description: 'OffMesh — Stay Connected. Anywhere. Opportunistic Mesh Gateway, Anti-Packet Delivery Receipts & Time-Bucketed Merkle Sync Engine',
        version: '1.0.0',
      },
      servers: [
        { url: 'http://localhost:3000', description: 'Local Gateway' },
      ],
      tags: [
        { name: 'Identities', description: 'Ed25519 challenge-response auth and contact cards' },
        { name: 'Bundles', description: 'Opportunistic mesh store-and-forward bundle routing' },
        { name: 'Receipts', description: 'Cryptographic anti-packet delivery receipts and pruning' },
        { name: 'Merkle', description: 'Microsecond time-bucketed Merkle tree reconciliation' },
      ],
    },
  });

  await app.register(fastifySwaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: false,
    },
  });

  // Health check
  app.get('/health', async () => {
    return {
      status: 'ok',
      service: 'offmesh-modular-monolith',
      onlinePeers: gatewayManager.getOnlineCount(),
      merkleRootHex: merkleTreeService.getRootHash(),
      timestamp: new Date().toISOString(),
    };
  });

  // Mount API modules
  await app.register(identityRoutes, { prefix: '/api/v1/identities' });
  await app.register(bundleRoutes, { prefix: '/api/v1/bundles' });
  await app.register(receiptRoutes, { prefix: '/api/v1/receipts' });
  await app.register(merkleRoutes, { prefix: '/api/v1/sync/merkle' });
  await app.register(authRoutes, { prefix: '/api/v1/auth' });
  await app.register(coupleRoutes, { prefix: '/api/v1/couples' });
  await app.register(billingRoutes, { prefix: '/api/v1/billing' });
  await app.register(safetyRoutes, { prefix: '/api/v1/safety' });
  await app.register(notificationRoutes, { prefix: '/api/v1/notifications' });

  // WebSocket Rendezvous Gateway
  app.get('/ws', { websocket: true }, (socket, req) => {
    const query = req.query as { idHex?: string; token?: string };
    let clientId: string | null = null;

    if (query.token) {
      const decoded = authService.verifyToken(query.token);
      if (decoded) {
        clientId = decoded.sub;
      }
    } else if (query.idHex && query.idHex.length === 64) {
      clientId = query.idHex;
    }

    if (!clientId) {
      socket.send(JSON.stringify({ error: 'Missing or invalid token / idHex query parameter' }));
      socket.close();
      return;
    }

    gatewayManager.registerClient(clientId, socket);
    socket.send(JSON.stringify({
      type: 'CONNECTED',
      idHex: clientId,
      merkleRootHex: merkleTreeService.getRootHash(),
    }));

    socket.on('message', (raw: any) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'PING') {
          socket.send(JSON.stringify({ type: 'PONG', timestamp: Date.now() }));
        } else if (msg.type === 'ENCRYPTED_MESSAGE' && msg.recipientId && msg.payload) {
          // Zero-knowledge real-time relay: forward encrypted payload immediately to recipient's active socket
          gatewayManager.sendToPeer(msg.recipientId, {
            type: 'ENCRYPTED_MESSAGE',
            msgId: msg.msgId || Date.now().toString(),
            senderId: clientId,
            payload: msg.payload,
            timestamp: Date.now(),
          });

          // Dispatch background FCM notification
          fcmService.sendMessageNotification(msg.recipientId, {
            fromName: 'Your Partner',
          }).catch(() => {});
        }
      } catch {}
    });
  });

  return app;
}
