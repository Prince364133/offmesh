import { eq } from 'drizzle-orm';
import { db, schema } from '../../infra/db/index.js';
import { redis } from '../../infra/redis/index.js';
import { merkleQueue } from '../../infra/queue/index.js';
import { NearLinkCrypto } from '../../infra/crypto/index.js';

export interface DecodedReceipt {
  msgIdHex: string;
  recipientIdHex: string;
  expiresAtMs: number;
  deliveredAtMs: number;
  signatureHex: string;
  rawBase64: string;
}

export class ReceiptService {
  /**
   * Decodes and validates raw NearLink binary receipt wire format (`NLR1...`).
   */
  public decodeWireReceipt(rawBase64: string): DecodedReceipt {
    const buf = Buffer.from(rawBase64, 'base64');
    if (buf.length !== 4 + 1 + 16 + 32 + 8 + 8 + 64) {
      throw new Error(`Invalid receipt wire length: expected 133 bytes, got ${buf.length}`);
    }

    let offset = 0;
    const magic = buf.subarray(offset, offset + 4).toString('utf8'); offset += 4;
    if (magic !== 'OMR1' && magic !== 'NLR1') {
      throw new Error(`Invalid receipt magic: ${magic} (expected OMR1 or NLR1)`);
    }

    const version = buf.readUInt8(offset); offset += 1;
    if (version !== 0) {
      throw new Error(`Unsupported receipt version: ${version}`);
    }

    const msgId = buf.subarray(offset, offset + 16); offset += 16;
    const recipientId = buf.subarray(offset, offset + 32); offset += 32;
    const expiresMs = Number(buf.readBigUInt64BE(offset)); offset += 8;
    const deliveredAtMs = Number(buf.readBigUInt64BE(offset)); offset += 8;
    const signature = buf.subarray(offset, offset + 64); offset += 64;

    // Verify cryptographic signature:
    // payload = "DELIVERED" (9) || msgId (16) || deliveredAtMs (8)
    const valid = NearLinkCrypto.verifyReceipt(
      recipientId.toString('hex'),
      msgId.toString('hex'),
      deliveredAtMs,
      signature.toString('hex')
    );

    if (!valid) {
      throw new Error('Receipt signature verification failed (forged receipt)');
    }

    return {
      msgIdHex: msgId.toString('hex'),
      recipientIdHex: recipientId.toString('hex'),
      expiresAtMs: expiresMs,
      deliveredAtMs: deliveredAtMs,
      signatureHex: signature.toString('hex'),
      rawBase64,
    };
  }

  /**
   * Ingests a signed delivery receipt, marking the bundle as DELIVERED and recording anti-packet.
   */
  public async ingestReceipt(rawBase64: string): Promise<{ status: 'ACCEPTED' | 'ALREADY_PROCESSED'; msgIdHex: string }> {
    const receipt = this.decodeWireReceipt(rawBase64);

    // Fast check in Redis
    try {
      const alreadySeen = await redis.sismember('receipts:seen', receipt.msgIdHex);
      if (alreadySeen) {
        return { status: 'ALREADY_PROCESSED', msgIdHex: receipt.msgIdHex };
      }
    } catch {}

    // Atomic database update: mark bundle DELIVERED and insert receipt anti-packet
    await db.transaction(async (tx) => {
      // Mark bundle delivered
      await tx.update(schema.bundles)
        .set({ status: 'DELIVERED' })
        .where(eq(schema.bundles.id, receipt.msgIdHex));

      // Insert receipt
      await tx.insert(schema.receipts)
        .values({
          msgId: receipt.msgIdHex,
          recipientId: receipt.recipientIdHex,
          signature: receipt.signatureHex,
          deliveredAt: new Date(receipt.deliveredAtMs),
          expiresAt: new Date(receipt.expiresAtMs),
        })
        .onConflictDoNothing();
    });

    // Mark as receipt in Redis and remove from active queued bundles
    try {
      await redis.sadd('receipts:seen', receipt.msgIdHex);
      await redis.srem('bundles:seen', receipt.msgIdHex);
    } catch {}

    // Dispatch background indexing job to update Merkle bucket
    try {
      await merkleQueue.add('index-receipt', {
        msgIdHex: receipt.msgIdHex,
        deliveredAtMs: receipt.deliveredAtMs,
      });
    } catch {}

    return { status: 'ACCEPTED', msgIdHex: receipt.msgIdHex };
  }

  /**
   * Retrieves a receipt by message ID.
   */
  public async getReceipt(msgIdHex: string) {
    const rows = await db.select().from(schema.receipts).where(eq(schema.receipts.msgId, msgIdHex)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }
}

export const receiptService = new ReceiptService();
