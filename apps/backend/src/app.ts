import Fastify from 'fastify';
import cors from '@fastify/cors';
import sensible from '@fastify/sensible';
import websocket from '@fastify/websocket';
import { identityRoutes } from './modules/identity/identity.routes.js';
import { bundleRoutes } from './modules/bundles/bundle.routes.js';
import { receiptRoutes } from './modules/receipts/receipt.routes.js';
import { merkleRoutes } from './modules/merkle/merkle.routes.js';
import { gatewayManager } from './modules/gateway/gateway.manager.js';
import { merkleTreeService } from './modules/merkle/merkle.service.js';

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: process.env.NODE_ENV === 'test' ? 'silent' : 'info',
    },
  });

  await app.register(cors, { origin: '*' });
  await app.register(sensible);
  await app.register(websocket);

  // Health check
  app.get('/health', async () => {
    return {
      status: 'ok',
      service: 'nearlink-modular-monolith',
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

  // WebSocket Rendezvous Gateway
  app.get('/ws', { websocket: true }, (socket, req) => {
    const query = req.query as { idHex?: string };
    const idHex = query.idHex;

    if (!idHex || idHex.length !== 64) {
      socket.send(JSON.stringify({ error: 'Missing or invalid idHex query parameter' }));
      socket.close();
      return;
    }

    gatewayManager.registerClient(idHex, socket);
    socket.send(JSON.stringify({
      type: 'CONNECTED',
      idHex,
      merkleRootHex: merkleTreeService.getRootHash(),
    }));

    socket.on('message', (raw: any) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'PING') {
          socket.send(JSON.stringify({ type: 'PONG', timestamp: Date.now() }));
        }
      } catch {}
    });
  });

  return app;
}
