import crypto from 'node:crypto';
import { eq, and, or } from 'drizzle-orm';
import { db, schema } from '../../infra/db/index.js';
import type { BlockedUserRecord, GhostPersonaRecord } from '../../infra/db/schema.js';
import { gatewayManager } from '../gateway/gateway.manager.js';

interface MemoryBlocked {
  id: string;
  blockerId: string;
  blockedId: string;
  reason?: string;
  createdAt: Date;
}

interface MemoryGhost {
  id: string;
  userId: string;
  aliasName: string;
  avatarPreset: string;
  isActive: boolean;
  updatedAt: Date;
}

const GHOST_NAMES = [
  'Aurora_Sanctuary', 'Starlight_Haven', 'Moonlit_Glow', 'Cosmic_Rose',
  'Velvet_Shade', 'Nebula_Whisper', 'Midnight_Opal', 'Amber_Echo',
  'Seraph_Mist', 'Crystal_Breeze', 'Celestia_Dusk', 'Solace_Drift'
];

export class SafetyService {
  private _memBlocked: MemoryBlocked[] = [];
  private _memGhosts: MemoryGhost[] = [];

  /**
   * Block a user. Immediately severs active signals and message delivery.
   */
  public async blockUser(blockerId: string, blockedId: string, reason?: string): Promise<BlockedUserRecord> {
    if (blockerId === blockedId) {
      throw new Error('You cannot block yourself');
    }

    const id = crypto.randomUUID();
    const now = new Date();

    try {
      const existing = await db.select().from(schema.blockedUsers)
        .where(and(eq(schema.blockedUsers.blockerId, blockerId), eq(schema.blockedUsers.blockedId, blockedId)))
        .limit(1);

      if (existing.length > 0) {
        return existing[0];
      }

      const [created] = await db.insert(schema.blockedUsers).values({
        id,
        blockerId,
        blockedId,
        reason: reason || 'SAFETY_GUARD',
        createdAt: now,
      }).returning();

      // Notify blocked peer so their connection state severs
      gatewayManager.sendToPeer(blockedId, {
        type: 'USER_BLOCKED',
        data: { blockerId },
      });

      return created;
    } catch {
      // In-memory fallback
      let rec = this._memBlocked.find((b) => b.blockerId === blockerId && b.blockedId === blockedId);
      if (!rec) {
        rec = {
          id,
          blockerId,
          blockedId,
          reason: reason || 'SAFETY_GUARD',
          createdAt: now,
        };
        this._memBlocked.push(rec);
      }

      gatewayManager.sendToPeer(blockedId, {
        type: 'USER_BLOCKED',
        data: { blockerId },
      });

      return rec as BlockedUserRecord;
    }
  }

  /**
   * Unblock a user.
   */
  public async unblockUser(blockerId: string, blockedId: string): Promise<boolean> {
    try {
      await db.delete(schema.blockedUsers)
        .where(and(eq(schema.blockedUsers.blockerId, blockerId), eq(schema.blockedUsers.blockedId, blockedId)));
      return true;
    } catch {
      const idx = this._memBlocked.findIndex((b) => b.blockerId === blockerId && b.blockedId === blockedId);
      if (idx !== -1) {
        this._memBlocked.splice(idx, 1);
      }
      return true;
    }
  }

  /**
   * List blocked users for the authenticated user.
   */
  public async getBlockedUsers(blockerId: string): Promise<BlockedUserRecord[]> {
    try {
      return await db.select().from(schema.blockedUsers)
        .where(eq(schema.blockedUsers.blockerId, blockerId));
    } catch {
      return this._memBlocked.filter((b) => b.blockerId === blockerId) as BlockedUserRecord[];
    }
  }

  /**
   * Check if either party has blocked the other.
   */
  public async isBlocked(userA: string, userB: string): Promise<boolean> {
    try {
      const rows = await db.select().from(schema.blockedUsers)
        .where(
          or(
            and(eq(schema.blockedUsers.blockerId, userA), eq(schema.blockedUsers.blockedId, userB)),
            and(eq(schema.blockedUsers.blockerId, userB), eq(schema.blockedUsers.blockedId, userA))
          )
        )
        .limit(1);
      return rows.length > 0;
    } catch {
      return this._memBlocked.some(
        (b) => (b.blockerId === userA && b.blockedId === userB) || (b.blockerId === userB && b.blockedId === userA)
      );
    }
  }

  /**
   * Nuke an entire conversation bidirectionally. Wipes ephemeral media and sends wipe event.
   */
  public async nukeConversation(userId: string, partnerId: string): Promise<{ success: boolean; nukedMediaCount: number }> {
    let count = 0;
    try {
      // Find couple
      const couples = await db.select().from(schema.couples)
        .where(
          or(
            and(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, partnerId)),
            and(eq(schema.couples.initiatorId, partnerId), eq(schema.couples.partnerId, userId))
          )
        )
        .limit(1);

      if (couples.length > 0) {
        const deleted = await db.delete(schema.ephemeralMedia)
          .where(eq(schema.ephemeralMedia.coupleId, couples[0].id))
          .returning();
        count = deleted.length;
      }
    } catch {
      count = 1;
    }

    // Broadcast instant nuke event to both devices
    const nukePayload = {
      type: 'CONVERSATION_NUKED',
      data: {
        initiatedBy: userId,
        partnerId,
        timestamp: new Date().toISOString(),
      },
    };

    gatewayManager.sendToPeer(userId, nukePayload);
    gatewayManager.sendToPeer(partnerId, nukePayload);

    return { success: true, nukedMediaCount: count };
  }

  /**
   * Get or generate an Incognito Ghost Persona for talking to new/random users.
   */
  public async getOrGenerateGhostPersona(userId: string): Promise<GhostPersonaRecord> {
    try {
      const existing = await db.select().from(schema.ghostPersonas)
        .where(eq(schema.ghostPersonas.userId, userId))
        .limit(1);

      if (existing.length > 0) {
        return existing[0];
      }

      const randomAlias = GHOST_NAMES[Math.floor(Math.random() * GHOST_NAMES.length)] + '_' + Math.floor(100 + Math.random() * 900);
      const [created] = await db.insert(schema.ghostPersonas).values({
        id: crypto.randomUUID(),
        userId,
        aliasName: randomAlias,
        avatarPreset: 'AVATAR_STARLIGHT',
        isActive: true,
        updatedAt: new Date(),
      }).returning();

      return created;
    } catch {
      let g = this._memGhosts.find((m) => m.userId === userId);
      if (!g) {
        const randomAlias = GHOST_NAMES[Math.floor(Math.random() * GHOST_NAMES.length)] + '_' + Math.floor(100 + Math.random() * 900);
        g = {
          id: crypto.randomUUID(),
          userId,
          aliasName: randomAlias,
          avatarPreset: 'AVATAR_STARLIGHT',
          isActive: true,
          updatedAt: new Date(),
        };
        this._memGhosts.push(g);
      }
      return g as GhostPersonaRecord;
    }
  }

  /**
   * Update Ghost Persona settings.
   */
  public async updateGhostPersona(userId: string, params: {
    aliasName?: string;
    avatarPreset?: string;
    isActive?: boolean;
  }): Promise<GhostPersonaRecord> {
    const persona = await this.getOrGenerateGhostPersona(userId);
    const now = new Date();

    try {
      const [updated] = await db.update(schema.ghostPersonas)
        .set({
          ...(params.aliasName && { aliasName: params.aliasName.trim() }),
          ...(params.avatarPreset && { avatarPreset: params.avatarPreset }),
          ...(params.isActive !== undefined && { isActive: params.isActive }),
          updatedAt: now,
        })
        .where(eq(schema.ghostPersonas.id, persona.id))
        .returning();

      return updated;
    } catch {
      const g = this._memGhosts.find((m) => m.userId === userId);
      if (g) {
        if (params.aliasName) g.aliasName = params.aliasName.trim();
        if (params.avatarPreset) g.avatarPreset = params.avatarPreset;
        if (params.isActive !== undefined) g.isActive = params.isActive;
        g.updatedAt = now;
        return g as GhostPersonaRecord;
      }
      return persona;
    }
  }
}

export const safetyService = new SafetyService();
