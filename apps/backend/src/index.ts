import { buildApp } from './app.js';
import { config } from './config/index.js';
import { startWorkers } from './workers/index.js';

async function main() {
  const app = await buildApp();

  try {
    startWorkers();
  } catch (err: any) {
    console.warn(`[Workers Notice] Background workers running in deferred mode: ${err.message}`);
  }

  try {
    const address = await app.listen({ port: config.PORT, host: config.HOST });
    console.log(`[OffMesh Server] Modular Monolith running at ${address}`);
    console.log(`[OffMesh Server] Health endpoint: ${address}/health`);
    console.log(`[OffMesh Server] WebSocket gateway: ws://${config.HOST}:${config.PORT}/ws`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();
