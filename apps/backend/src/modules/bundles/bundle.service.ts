import { eq, and, gt } from 'drizzle-orm';
import { db, schema } from '../../infra/db/index.js';
import { redis } from '../../infra/redis/index.js';
import { bundleQueue } from '../../infra/queue/index.js';
import { NearLinkCrypto } from '../../infra/crypto/index.js';

export interface DecodedBundle {
  msgIdHex: string;
  senderIdHex: string;
  recipientIdHex: string;
  expiresAtMs: number;
  copies: number;
  hopCount: number;
  hopLimit: number;
  ephPublicKeyHex: string;
  ciphertextBase64: string;
  senderSignatureHex: string;
  rawBase64: string;
}

export class BundleService {
  /**
   * Decodes raw NearLink binary wire bundle (`NLB1...`).
   */
  public decodeWireBundle(rawBase64: string): DecodedBundle {
    const buf = Buffer.from(rawBase64, 'base64');
    if (buf.length > 10 * 1024 * 1024) {
      throw new Error('Bundle wire bytes exceed maximum allowed size (10MB)');
    }
    if (buf.length < 4 + 1 + 16 + 32 + 32 + 8 + 2 + 2 + 2 + 32 + 2 + 64) {
      throw new Error('Bundle wire bytes too short');
    }

    let offset = 0;
    const magic = buf.subarray(offset, offset + 4).toString('utf8'); offset += 4;
    if (magic !== 'OMB1' && magic !== 'NLB1') {
      throw new Error(`Invalid bundle magic: ${magic} (expected OMB1 or NLB1)`);
    }

    const version = buf.readUInt8(offset); offset += 1;
    if (version !== 0) {
      throw new Error(`Unsupported bundle version: ${version}`);
    }

    const msgId = buf.subarray(offset, offset + 16); offset += 16;
    const senderId = buf.subarray(offset, offset + 32); offset += 32;
    const recipientId = buf.subarray(offset, offset + 32); offset += 32;
    const expiresMs = Number(buf.readBigUInt64BE(offset)); offset += 8;
    const copies = buf.readUInt16BE(offset); offset += 2;
    const hopCount = buf.readUInt16BE(offset); offset += 2;
    const hopLimit = buf.readUInt16BE(offset); offset += 2;
    const ephPubKey = buf.subarray(offset, offset + 32); offset += 32;

    const cipherLen = buf.readUInt16BE(offset); offset += 2;
    if (offset + cipherLen + 64 > buf.length) {
      throw new Error('Malformed ciphertext length');
    }

    const ciphertext = buf.subarray(offset, offset + cipherLen); offset += cipherLen;
    const signature = buf.subarray(offset, offset + 64); offset += 64;

    // Verify sender signature over the header
    const signedData = buf.subarray(0, offset - 64);
    const valid = NearLinkCrypto.verifyEd25519(senderId, signedData, signature);
    if (!valid) {
      throw new Error('Sender signature verification failed (forged bundle)');
    }

    return {
      msgIdHex: msgId.toString('hex'),
      senderIdHex: senderId.toString('hex'),
      recipientIdHex: recipientId.toString('hex'),
      expiresAtMs: expiresMs,
      copies,
      hopCount,
      hopLimit,
      ephPublicKeyHex: ephPubKey.toString('hex'),
      ciphertextBase64: ciphertext.toString('base64'),
      senderSignatureHex: signature.toString('hex'),
      rawBase64,
    };
  }

  /**
   * Ingests an uploaded bundle, executing deduplication and queuing for delivery.
   */
  public async ingestBundle(rawBase64: string): Promise<{ status: 'ACCEPTED' | 'DUPLICATE' | 'EXPIRED'; msgIdHex: string }> {
    const bundle = this.decodeWireBundle(rawBase64);
    const now = Date.now();

    if (bundle.expiresAtMs <= now) {
      return { status: 'EXPIRED', msgIdHex: bundle.msgIdHex };
    }

    if (bundle.hopLimit > 0 && bundle.hopCount >= bundle.hopLimit) {
      return { status: 'EXPIRED', msgIdHex: bundle.msgIdHex };
    }

    // Fast Redis check for seen bundles or existing receipts (cancellations)
    try {
      const isReceipt = await redis.sismember('receipts:seen', bundle.msgIdHex);
      if (isReceipt) {
        return { status: 'DUPLICATE', msgIdHex: bundle.msgIdHex };
      }
      const isSeen = await redis.sismember('bundles:seen', bundle.msgIdHex);
      if (isSeen) {
        return { status: 'DUPLICATE', msgIdHex: bundle.msgIdHex };
      }
    } catch {}

    // Check Postgres
    const existing = await db.select().from(schema.bundles).where(eq(schema.bundles.id, bundle.msgIdHex)).limit(1);
    if (existing.length > 0) {
      return { status: 'DUPLICATE', msgIdHex: bundle.msgIdHex };
    }

    // Persist to Postgres idempotently
    try {
      await db.insert(schema.bundles).values({
        id: bundle.msgIdHex,
        senderId: bundle.senderIdHex,
        recipientId: bundle.recipientIdHex,
        payloadBase64: bundle.rawBase64,
        status: 'QUEUED',
        hopCount: bundle.hopCount,
        copies: bundle.copies,
        expiresAt: new Date(bundle.expiresAtMs),
        createdAt: new Date(),
      }).onConflictDoNothing();
    } catch (e) {
      return { status: 'DUPLICATE', msgIdHex: bundle.msgIdHex };
    }

    // Mark as seen in Redis
    try {
      await redis.sadd('bundles:seen', bundle.msgIdHex);
    } catch {}

    // Dispatch background job for routing and push notification
    try {
      await bundleQueue.add('process-bundle', {
        msgIdHex: bundle.msgIdHex,
        recipientIdHex: bundle.recipientIdHex,
      });
    } catch {}

    return { status: 'ACCEPTED', msgIdHex: bundle.msgIdHex };
  }

  /**
   * Retrieves pending queued bundles for a recipient.
   */
  public async getMailbox(recipientIdHex: string): Promise<Array<{ id: string; payloadBase64: string; expiresAt: Date }>> {
    const now = new Date();
    const rows = await db.select({
      id: schema.bundles.id,
      payloadBase64: schema.bundles.payloadBase64,
      expiresAt: schema.bundles.expiresAt,
    })
    .from(schema.bundles)
    .where(
      and(
        eq(schema.bundles.recipientId, recipientIdHex),
        eq(schema.bundles.status, 'QUEUED'),
        gt(schema.bundles.expiresAt, now)
      )
    );

    return rows;
  }
}

export const bundleService = new BundleService();
