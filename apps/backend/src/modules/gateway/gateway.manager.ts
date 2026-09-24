import type { WebSocket } from 'ws';

export class GatewayManager {
  private activeSockets = new Map<string, WebSocket>(); // idHex -> WebSocket

  public registerClient(idHex: string, ws: WebSocket) {
    this.activeSockets.set(idHex, ws);
    console.log(`[Gateway] Mobile peer connected: ${idHex.substring(0, 8)}`);

    ws.on('close', () => {
      this.activeSockets.delete(idHex);
      console.log(`[Gateway] Mobile peer disconnected: ${idHex.substring(0, 8)}`);
    });
  }

  public isOnline(idHex: string): boolean {
    const ws = this.activeSockets.get(idHex);
    return ws !== undefined && ws.readyState === 1; // OPEN
  }

  public sendToPeer(recipientIdHex: string, message: { type: string; data: any }): boolean {
    const ws = this.activeSockets.get(recipientIdHex);
    if (ws && ws.readyState === 1) {
      ws.send(JSON.stringify(message));
      return true;
    }
    return false;
  }

  public broadcast(message: { type: string; data: any }) {
    const payload = JSON.stringify(message);
    for (const ws of this.activeSockets.values()) {
      if (ws.readyState === 1) {
        ws.send(payload);
      }
    }
  }

  public getOnlineCount(): number {
    return this.activeSockets.size;
  }
}

export const gatewayManager = new GatewayManager();
