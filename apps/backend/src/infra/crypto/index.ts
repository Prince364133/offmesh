import crypto from 'node:crypto';

// Ed25519 SPKI Prefix (RFC 8410)
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

export interface ParsedContactCard {
  version: number;
  name: string;
  idHex: string; // 32-byte sha256("NL-id" || signPub || dhPub)
  signPublicKeyHex: string; // 32-byte Ed25519 public key hex
  encPublicKeyHex: string; // 32-byte X25519 public key hex
  rawCard: string;
}

export class OffMeshCrypto {
  /**
   * Computes SHA-256 hash of one or more buffers/strings.
   */
  public static sha256(...parts: (Buffer | Uint8Array | string)[]): Buffer {
    const hash = crypto.createHash('sha256');
    for (const part of parts) {
      if (typeof part === 'string') {
        hash.update(Buffer.from(part, 'utf8'));
      } else {
        hash.update(part);
      }
    }
    return hash.digest();
  }

  /**
   * Verifies an Ed25519 signature given raw 32-byte public key, data, and 64-byte signature.
   */
  public static verifyEd25519(publicKeyRaw: Buffer, data: Buffer, signature: Buffer): boolean {
    if (publicKeyRaw.length !== 32 || signature.length !== 64) {
      return false;
    }
    try {
      const spkiKey = Buffer.concat([ED25519_SPKI_PREFIX, publicKeyRaw]);
      return crypto.verify(null, data, { key: spkiKey, format: 'der', type: 'spki' }, signature);
    } catch {
      return false;
    }
  }

  /**
   * Parses an OM1:... or NL1:... contact card matching Contact wire format:
   * var16(name) || signPub (32) || dhPub (32)
   */
  public static parseCard(cardString: string): ParsedContactCard {
    if (!cardString.startsWith('OM1:') && !cardString.startsWith('NL1:')) {
      throw new Error('Invalid card prefix: must start with OM1: or NL1:');
    }
    const b64 = cardString.substring(4).replace(/-/g, '+').replace(/_/g, '/');
    const buf = Buffer.from(b64, 'base64');
    if (buf.length < 2 + 32 + 32) {
      throw new Error('Card buffer too short');
    }

    let offset = 0;
    const nameLen = buf.readUInt16BE(offset); offset += 2;
    if (offset + nameLen + 32 + 32 > buf.length) {
      throw new Error('Malformed card length fields');
    }

    const name = buf.subarray(offset, offset + nameLen).toString('utf8'); offset += nameLen;
    const signPub = buf.subarray(offset, offset + 32); offset += 32;
    const dhPub = buf.subarray(offset, offset + 32); offset += 32;

    // Support both OM-id and legacy NL-id domains based on card prefix
    const isOm = cardString.startsWith('OM1:');
    const idDomain = isOm ? 'OM-id' : 'NL-id';
    const id = this.sha256(Buffer.from(idDomain, 'utf8'), signPub, dhPub);

    return {
      version: 0,
      name,
      idHex: id.toString('hex'),
      signPublicKeyHex: signPub.toString('hex'),
      encPublicKeyHex: dhPub.toString('hex'),
      rawCard: cardString,
    };
  }

  /**
   * Verifies a delivery receipt signature:
   * Signed payload = "DELIVERED" || msgIdBytes (16) || deliveredAtMs (8 bytes BE)
   */
  public static verifyReceipt(recipientIdHex: string, msgIdHex: string, deliveredAtMs: number, signatureHex: string): boolean {
    const recipientKey = Buffer.from(recipientIdHex, 'hex');
    const msgId = Buffer.from(msgIdHex, 'hex');
    const sig = Buffer.from(signatureHex, 'hex');

    const payload = Buffer.alloc(9 + 16 + 8);
    payload.write('DELIVERED', 0, 'utf8');
    msgId.copy(payload, 9);
    payload.writeBigInt64BE(BigInt(deliveredAtMs), 25);

    return this.verifyEd25519(recipientKey, payload, sig);
  }
}

export const NearLinkCrypto = OffMeshCrypto;
