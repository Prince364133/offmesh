import { NearLinkCrypto } from '../../infra/crypto/index.js';
import { db, schema } from '../../infra/db/index.js';

export interface MerkleRecord {
  id: string; // 16-byte message ID hex
  timestampMs: number;
}

export interface BucketNode {
  day: number;
  hour: number;
  bucket: number;
  hashHex: string;
  count: number;
}

export class MerkleTreeService {
  private static readonly BUCKET_MS = 5 * 60 * 1000; // 5 minutes
  private static readonly HOUR_MS = 60 * 60 * 1000;   // 1 hour
  private static readonly DAY_MS = 24 * 60 * 60 * 1000; // 1 day

  // In-memory cache for fast microsecond lookups
  private dayHashes = new Map<number, string>();
  private hourHashes = new Map<string, string>(); // "day:hour" -> hash
  private bucketHashes = new Map<string, string>(); // "day:hour:bucket" -> hash
  private bucketRecords = new Map<string, MerkleRecord[]>(); // "day:hour:bucket" -> records
  private globalRootHashHex: string = '0000000000000000000000000000000000000000000000000000000000000000';

  /**
   * Inserts a record and updates the Merkle tree branches.
   */
  public insertRecord(record: MerkleRecord) {
    const day = Math.floor(record.timestampMs / MerkleTreeService.DAY_MS);
    const hour = Math.floor((record.timestampMs % MerkleTreeService.DAY_MS) / MerkleTreeService.HOUR_MS);
    const bucket = Math.floor((record.timestampMs % MerkleTreeService.HOUR_MS) / MerkleTreeService.BUCKET_MS);

    const bKey = `${day}:${hour}:${bucket}`;
    const list = this.bucketRecords.get(bKey) || [];
    list.push(record);
    this.bucketRecords.set(bKey, list);

    this.recomputeTree();
  }

  /**
   * Recomputes hierarchical SHA-256 hashes from leaf buckets up to the Global Root.
   */
  public recomputeTree() {
    // 1. Compute bucket hashes
    const dayToHours = new Map<number, Set<number>>();

    for (const [bKey, recs] of this.bucketRecords.entries()) {
      const [dStr, hStr, bStr] = bKey.split(':');
      const d = parseInt(dStr, 10);
      const h = parseInt(hStr, 10);
      if (!dayToHours.has(d)) dayToHours.set(d, new Set());
      dayToHours.get(d)!.add(h);

      const buffers = recs.map(r => Buffer.concat([
        Buffer.from(r.id, 'hex'),
        Buffer.from(r.timestampMs.toString(16).padStart(16, '0'), 'hex')
      ]));
      const bHash = NearLinkCrypto.sha256(...buffers).toString('hex');
      this.bucketHashes.set(bKey, bHash);
    }

    // 2. Compute hour hashes
    for (const [day, hours] of dayToHours.entries()) {
      for (const hour of hours) {
        const hourKey = `${day}:${hour}`;
        const bHashes: Buffer[] = [];
        for (let b = 0; b < 12; b++) {
          const bh = this.bucketHashes.get(`${day}:${hour}:${b}`);
          if (bh) bHashes.push(Buffer.from(bh, 'hex'));
        }
        if (bHashes.length > 0) {
          const hHash = NearLinkCrypto.sha256(...bHashes).toString('hex');
          this.hourHashes.set(hourKey, hHash);
        }
      }
    }

    // 3. Compute day hashes
    const dayHashesList: Buffer[] = [];
    for (const [day, hours] of dayToHours.entries()) {
      const hHashes: Buffer[] = [];
      for (let h = 0; h < 24; h++) {
        const hh = this.hourHashes.get(`${day}:${h}`);
        if (hh) hHashes.push(Buffer.from(hh, 'hex'));
      }
      if (hHashes.length > 0) {
        const dHash = NearLinkCrypto.sha256(...hHashes).toString('hex');
        this.dayHashes.set(day, dHash);
        dayHashesList.push(Buffer.from(dHash, 'hex'));
      }
    }

    // 4. Compute global root hash
    if (dayHashesList.length > 0) {
      this.globalRootHashHex = NearLinkCrypto.sha256(...dayHashesList).toString('hex');
    } else {
      this.globalRootHashHex = Buffer.alloc(32).toString('hex');
    }
  }

  /**
   * Returns current 32-byte Global Root Hash.
   */
  public getRootHash(): string {
    return this.globalRootHashHex;
  }

  /**
   * Reconciles client's day hashes against the server's Merkle tree.
   * If root differs, returns mismatched days and diverging buckets.
   */
  public reconcile(clientRootHex: string, clientDayHashes: Record<string, string>): {
    inSync: boolean;
    divergingDays: number[];
    missingRecords: MerkleRecord[];
  } {
    if (clientRootHex === this.globalRootHashHex) {
      // 100% in sync: 0 bytes further diff needed
      return { inSync: true, divergingDays: [], missingRecords: [] };
    }

    const divergingDays: number[] = [];
    const missingRecords: MerkleRecord[] = [];

    for (const [day, dayHash] of this.dayHashes.entries()) {
      const clientHash = clientDayHashes[day.toString()];
      if (clientHash !== dayHash) {
        divergingDays.push(day);

        // Gather all records for this diverging day
        for (let h = 0; h < 24; h++) {
          for (let b = 0; b < 12; b++) {
            const recs = this.bucketRecords.get(`${day}:${h}:${b}`);
            if (recs) missingRecords.push(...recs);
          }
        }
      }
    }

    return {
      inSync: false,
      divergingDays,
      missingRecords,
    };
  }
}

export const merkleTreeService = new MerkleTreeService();
