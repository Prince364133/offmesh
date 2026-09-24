import type { WebSocket } from 'ws';

export class GatewayManager {
  private activeSockets = new Map<string, WebSocket>(); // idHex -> WebSocket

  public registerClient(idHex: string, ws: WebSocket) {
    this.activeSockets.set(idHex, ws);
    console.log(`[Gateway] Mobile peer connected: ${idHex.substring(0, 8)}`);

    ws.on('close', () => {
      if (this.activeSockets.get(idHex) === ws) {
        this.activeSockets.delete(idHex);
        console.log(`[Gateway] Mobile peer disconnected: ${idHex.substring(0, 8)}`);
      }
    });

    ws.on('error', (err) => {
      console.warn(`[Gateway] Socket error for peer ${idHex.substring(0, 8)}: ${err.message}`);
      if (this.activeSockets.get(idHex) === ws) {
        this.activeSockets.delete(idHex);
      }
    });
  }

  public isOnline(idHex: string): boolean {
    const ws = this.activeSockets.get(idHex);
    return ws !== undefined && ws.readyState === 1; // OPEN
  }

  public sendToPeer(recipientIdHex: string, message: { type: string; data: any }): boolean {
    const ws = this.activeSockets.get(recipientIdHex);
    if (ws && ws.readyState === 1) {
      try {
        ws.send(JSON.stringify(message));
        return true;
      } catch (err) {
        if (this.activeSockets.get(recipientIdHex) === ws) {
          this.activeSockets.delete(recipientIdHex);
        }
        return false;
      }
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
