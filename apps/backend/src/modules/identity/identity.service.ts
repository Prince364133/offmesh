import crypto from 'node:crypto';
import { eq } from 'drizzle-orm';
import { db, schema } from '../../infra/db/index.js';
import { redis } from '../../infra/redis/index.js';
import { NearLinkCrypto, type ParsedContactCard } from '../../infra/crypto/index.js';

export class IdentityService {
  /**
   * Registers a NearLink contact card, validating the cryptographic self-signature.
   */
  public async registerCard(cardString: string): Promise<ParsedContactCard> {
    const card = NearLinkCrypto.parseCard(cardString);

    // Persist to Postgres
    await db.insert(schema.identities)
      .values({
        id: card.idHex,
        encPublicKey: card.encPublicKeyHex,
        name: card.name,
        card: card.rawCard,
        lastSeenAt: new Date(),
      })
      .onConflictDoUpdate({
        target: schema.identities.id,
        set: {
          name: card.name,
          card: card.rawCard,
          lastSeenAt: new Date(),
        },
      });

    // Cache in Redis for instant lookups
    try {
      await redis.set(`identity:${card.idHex}`, JSON.stringify(card), 'EX', 86400);
    } catch (e) {
      // Non-fatal if Redis offline
    }

    return card;
  }

  /**
   * Retrieves an identity by hex ID.
   */
  public async getIdentity(idHex: string): Promise<ParsedContactCard | null> {
    try {
      const cached = await redis.get(`identity:${idHex}`);
      if (cached) return JSON.parse(cached);
    } catch {}

    const rows = await db.select().from(schema.identities).where(eq(schema.identities.id, idHex)).limit(1);
    if (!rows.length) return null;

    const row = rows[0];
    const result = NearLinkCrypto.parseCard(row.card);

    try {
      await redis.set(`identity:${idHex}`, JSON.stringify(result), 'EX', 86400);
    } catch {}

    return result;
  }

  /**
   * Issues an authentication challenge nonce (32 bytes hex) for an Ed25519 identity.
   */
  public async createAuthChallenge(idHex: string): Promise<{ challenge: string; expiresSec: number }> {
    const nonce = crypto.randomBytes(32).toString('hex');
    const key = `auth:challenge:${idHex}`;
    try {
      await redis.set(key, nonce, 'EX', 60);
    } catch {}
    return { challenge: nonce, expiresSec: 60 };
  }

  /**
   * Verifies that the client signed the challenge with their Ed25519 private key.
   */
  public async verifyAuthChallenge(idHex: string, signatureHex: string): Promise<boolean> {
    let challenge: string | null = null;
    const key = `auth:challenge:${idHex}`;
    try {
      challenge = await redis.get(key);
      if (challenge) await redis.del(key);
    } catch {}

    if (!challenge) {
      return false; // Challenge expired or invalid
    }

    const pubKeyRaw = Buffer.from(idHex, 'hex');
    const challengeBytes = Buffer.from(challenge, 'utf8');
    const sigBytes = Buffer.from(signatureHex, 'hex');

    return NearLinkCrypto.verifyEd25519(pubKeyRaw, challengeBytes, sigBytes);
  }
}

export const identityService = new IdentityService();
