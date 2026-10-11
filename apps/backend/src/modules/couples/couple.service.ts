import crypto from 'node:crypto';
import { eq, or, and, lt } from 'drizzle-orm';
import { db, schema } from '../../infra/db/index.js';
import type {
  CoupleRecord,
  StealthSettingsRecord,
  CouplePermissionRecord,
  EphemeralMediaRecord,
  ChatCustomizationRecord,
} from '../../infra/db/schema.js';
import { gatewayManager } from '../gateway/gateway.manager.js';
import { billingService } from '../billing/billing.service.js';
import { fcmService } from '../notifications/fcm.service.js';

export interface CoupleDetails {
  coupleId: string;
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED';
  isInitiator: boolean;
  partner: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl: string | null;
    signPublicKey: string;
    encPublicKey: string;
    moodStatus: string;
  };
  myNicknameForPartner: string | null;
  partnerNicknameForMe: string | null;
  anniversaryDate: Date | null;
  daysTogether: number | null;
}

export class CoupleService {
  /**
   * Request couple pairing with a target user.
   */
  public async requestCouple(initiatorId: string, targetUsernameOrId: string): Promise<CoupleRecord> {
    const cleanTarget = targetUsernameOrId.trim().replace(/^@/, '').toLowerCase();

    // Find target user
    const targets = await db.select().from(schema.users)
      .where(or(eq(schema.users.username, cleanTarget), eq(schema.users.id, cleanTarget)))
      .limit(1);

    if (targets.length === 0) {
      throw new Error('Partner not found with that username');
    }

    const partner = targets[0];
    if (partner.id === initiatorId) {
      throw new Error('You cannot pair with yourself');
    }

    // Check if couple relationship already exists
    const existing = await db.select().from(schema.couples)
      .where(
        or(
          and(eq(schema.couples.initiatorId, initiatorId), eq(schema.couples.partnerId, partner.id)),
          and(eq(schema.couples.initiatorId, partner.id), eq(schema.couples.partnerId, initiatorId))
        )
      )
      .limit(1);

    if (existing.length > 0) {
      const rel = existing[0];
      if (rel.status === 'ACCEPTED') {
        throw new Error('You are already paired with this partner');
      }
      if (rel.status === 'PENDING') {
        return rel;
      }
    }

    const coupleId = crypto.randomUUID();
    const [created] = await db.insert(schema.couples).values({
      id: coupleId,
      initiatorId,
      partnerId: partner.id,
      status: 'PENDING',
      anniversaryDate: new Date(),
    }).returning();

    return created;
  }

  /**
   * Respond to an incoming couple request (Accept or Reject).
   */
  public async respondCouple(userId: string, coupleId: string, accept: boolean): Promise<CoupleRecord> {
    const rows = await db.select().from(schema.couples).where(eq(schema.couples.id, coupleId)).limit(1);
    if (rows.length === 0) {
      throw new Error('Couple request not found');
    }

    const couple = rows[0];
    if (couple.partnerId !== userId) {
      throw new Error('You can only respond to requests sent to you');
    }

    const newStatus = accept ? 'ACCEPTED' : 'REJECTED';
    const [updated] = await db.update(schema.couples)
      .set({ status: newStatus })
      .where(eq(schema.couples.id, coupleId))
      .returning();

    return updated;
  }

  /**
   * Get current couple status for a user.
   */
  public async getCoupleStatus(userId: string): Promise<CoupleDetails | null> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) return null;

    const couple = rows[0];
    const isInitiator = couple.initiatorId === userId;
    const partnerId = isInitiator ? couple.partnerId : couple.initiatorId;

    const partnerRows = await db.select().from(schema.users).where(eq(schema.users.id, partnerId)).limit(1);
    if (partnerRows.length === 0) return null;
    const partner = partnerRows[0];

    let daysTogether: number | null = null;
    if (couple.anniversaryDate) {
      const ms = Date.now() - new Date(couple.anniversaryDate).getTime();
      daysTogether = Math.max(0, Math.floor(ms / (1000 * 60 * 60 * 24)));
    }

    return {
      coupleId: couple.id,
      status: couple.status as 'PENDING' | 'ACCEPTED' | 'REJECTED',
      isInitiator,
      partner: {
        id: partner.id,
        username: partner.username,
        displayName: partner.displayName,
        avatarUrl: partner.avatarUrl,
        signPublicKey: partner.signPublicKey,
        encPublicKey: partner.encPublicKey,
        moodStatus: partner.moodStatus,
      },
      myNicknameForPartner: isInitiator ? couple.initiatorNickname : couple.partnerNickname,
      partnerNicknameForMe: isInitiator ? couple.partnerNickname : couple.initiatorNickname,
      anniversaryDate: couple.anniversaryDate,
      daysTogether,
    };
  }

  /**
   * Update anniversary date or nickname.
   */
  public async updateCoupleDetails(userId: string, params: {
    anniversaryDate?: string;
    nicknameForPartner?: string;
  }): Promise<CoupleRecord> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No active couple found');
    }

    const couple = rows[0];
    const isInitiator = couple.initiatorId === userId;

    const updates: Partial<typeof schema.couples.$inferInsert> = {};
    if (params.anniversaryDate) {
      updates.anniversaryDate = new Date(params.anniversaryDate);
    }
    if (params.nicknameForPartner !== undefined) {
      if (isInitiator) {
        updates.initiatorNickname = params.nicknameForPartner;
      } else {
        updates.partnerNickname = params.nicknameForPartner;
      }
    }

    const [updated] = await db.update(schema.couples)
      .set(updates)
      .where(eq(schema.couples.id, couple.id))
      .returning();

    return updated;
  }

  /**
   * Get Stealth & Ghost Notification settings for user.
   */
  public async getStealthSettings(userId: string): Promise<StealthSettingsRecord> {
    const rows = await db.select().from(schema.stealthSettings).where(eq(schema.stealthSettings.userId, userId)).limit(1);
    if (rows.length > 0) return rows[0];

    // Create default
    const [created] = await db.insert(schema.stealthSettings).values({
      userId,
      appDisguise: 'CALCULATOR',
      decoyPin: '1234',
      notifDisguiseMode: 'CAMOUFLAGE',
      fakeSenderTitle: 'System Update',
      fakeBodyPreview: 'Sync completed successfully',
    }).returning();

    return created;
  }

  /**
   * Update Stealth & Ghost Notification settings for user.
   */
  public async updateStealthSettings(userId: string, settings: {
    appDisguise?: string;
    decoyPin?: string;
    notifDisguiseMode?: string;
    fakeSenderTitle?: string;
    fakeBodyPreview?: string;
  }): Promise<StealthSettingsRecord> {
    const [updated] = await db.insert(schema.stealthSettings)
      .values({
        userId,
        appDisguise: settings.appDisguise || 'CALCULATOR',
        decoyPin: settings.decoyPin || '1234',
        notifDisguiseMode: settings.notifDisguiseMode || 'CAMOUFLAGE',
        fakeSenderTitle: settings.fakeSenderTitle || 'System Update',
        fakeBodyPreview: settings.fakeBodyPreview || 'Sync completed successfully',
        updatedAt: new Date(),
      })
      .onConflictDoUpdate({
        target: schema.stealthSettings.userId,
        set: {
          ...(settings.appDisguise && { appDisguise: settings.appDisguise }),
          ...(settings.decoyPin && { decoyPin: settings.decoyPin }),
          ...(settings.notifDisguiseMode && { notifDisguiseMode: settings.notifDisguiseMode }),
          ...(settings.fakeSenderTitle && { fakeSenderTitle: settings.fakeSenderTitle }),
          ...(settings.fakeBodyPreview && { fakeBodyPreview: settings.fakeBodyPreview }),
          updatedAt: new Date(),
        },
      })
      .returning();

    return updated;
  }

  /**
   * Get permissions for a specific user in a couple.
   */
  public async getPermissions(coupleId: string, userId: string): Promise<CouplePermissionRecord> {
    const rows = await db.select().from(schema.couplePermissions)
      .where(and(eq(schema.couplePermissions.coupleId, coupleId), eq(schema.couplePermissions.userId, userId)))
      .limit(1);

    if (rows.length > 0) return rows[0];

    const [created] = await db.insert(schema.couplePermissions).values({
      id: crypto.randomUUID(),
      coupleId,
      userId,
      allowVibrate: true,
      allowRing: true,
      allowFlashlight: true,
      blockScreenshots: false,
      blockSaving: false,
      blockCopying: false,
    }).returning();

    return created;
  }

  /**
   * Update chat permissions for the authenticated user.
   */
  public async updatePermissions(userId: string, perms: {
    allowVibrate?: boolean;
    allowRing?: boolean;
    allowFlashlight?: boolean;
    blockScreenshots?: boolean;
    blockSaving?: boolean;
    blockCopying?: boolean;
  }): Promise<CouplePermissionRecord> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No active couple found');
    }

    const couple = rows[0];
    const existing = await this.getPermissions(couple.id, userId);

    const [updated] = await db.update(schema.couplePermissions)
      .set({
        ...(perms.allowVibrate !== undefined && { allowVibrate: perms.allowVibrate }),
        ...(perms.allowRing !== undefined && { allowRing: perms.allowRing }),
        ...(perms.allowFlashlight !== undefined && { allowFlashlight: perms.allowFlashlight }),
        ...(perms.blockScreenshots !== undefined && { blockScreenshots: perms.blockScreenshots }),
        ...(perms.blockSaving !== undefined && { blockSaving: perms.blockSaving }),
        ...(perms.blockCopying !== undefined && { blockCopying: perms.blockCopying }),
        updatedAt: new Date(),
      })
      .where(eq(schema.couplePermissions.id, existing.id))
      .returning();

    // Broadcast permission update to partner
    const partnerId = couple.initiatorId === userId ? couple.partnerId : couple.initiatorId;
    gatewayManager.sendToPeer(partnerId, {
      type: 'HAVEN_PERMISSIONS_UPDATED',
      data: {
        partnerId: userId,
        permissions: updated,
      },
    });

    return updated;
  }

  /**
   * Get mutual permissions (what I allow my partner, and what partner allows me).
   */
  public async getMutualPermissions(userId: string): Promise<{
    coupleId: string;
    myPermissions: CouplePermissionRecord;
    partnerPermissions: CouplePermissionRecord;
  }> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No active couple found');
    }

    const couple = rows[0];
    const partnerId = couple.initiatorId === userId ? couple.partnerId : couple.initiatorId;

    const myPermissions = await this.getPermissions(couple.id, userId);
    const partnerPermissions = await this.getPermissions(couple.id, partnerId);

    return {
      coupleId: couple.id,
      myPermissions,
      partnerPermissions,
    };
  }

  /**
   * Trigger a remote hardware signal (vibration, bell ring, flashlight torch)
   * strictly adhering to the partner's mutual consent permissions.
   */
  public async sendSignal(userId: string, signalType: 'BUZZ' | 'RING' | 'FLASHLIGHT'): Promise<{
    success: boolean;
    signalType: string;
    deliveredOnline: boolean;
  }> {
    const rows = await db.select().from(schema.couples)
      .where(
        and(
          or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)),
          eq(schema.couples.status, 'ACCEPTED')
        )
      )
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No accepted couple relationship found');
    }

    // Verify sender subscription / trial access
    const billing = await billingService.getSubscriptionStatus(userId);
    if (!billing.hasChatAccess) {
      throw new Error('Subscription required: 3-day free trial has expired. Subscribe to Haven Sanctuary ($5/mo) to send signals.');
    }

    const couple = rows[0];
    const partnerId = couple.initiatorId === userId ? couple.partnerId : couple.initiatorId;

    // Verify recipient's consent permission
    const partnerPerms = await this.getPermissions(couple.id, partnerId);

    if (signalType === 'BUZZ' && !partnerPerms.allowVibrate) {
      throw new Error('Your partner has disabled remote vibration');
    }
    if (signalType === 'RING' && !partnerPerms.allowRing) {
      throw new Error('Your partner has disabled remote bell ring');
    }
    if (signalType === 'FLASHLIGHT' && !partnerPerms.allowFlashlight) {
      throw new Error('Your partner has disabled remote flashlight');
    }

    // Get sender info
    const senderRows = await db.select().from(schema.users).where(eq(schema.users.id, userId)).limit(1);
    const senderName = senderRows.length > 0 ? senderRows[0].displayName : 'Your Partner';

    // Dispatch real-time signal via WebSocket
    const delivered = gatewayManager.sendToPeer(partnerId, {
      type: 'HAVEN_SIGNAL',
      data: {
        fromUserId: userId,
        fromName: senderName,
        signalType,
        timestamp: Date.now(),
      },
    });

    // Dispatch background FCM push notification
    fcmService.sendSignalNotification(partnerId, {
      fromName: senderName,
      signalType,
      timestamp: Date.now(),
    }).catch((err) => console.warn('[FCM] Signal notification error:', err));

    return {
      success: true,
      signalType,
      deliveredOnline: delivered,
    };
  }

  private _localMediaStore = new Map<string, { buffer: Buffer; mimeType: string }>();

  public saveUploadedMedia(mediaKey: string, buffer: Buffer, mimeType: string): void {
    this._localMediaStore.set(mediaKey, { buffer, mimeType });
  }

  public getUploadedMedia(mediaKey: string): { buffer: Buffer; mimeType: string } | undefined {
    return this._localMediaStore.get(mediaKey);
  }

  /**
   * Generates AWS SigV4 Presigned PUT URL for Cloudflare R2 bucket.
   */
  public generateR2PresignedPutUrl(params: {
    accountId: string;
    accessKeyId: string;
    secretAccessKey: string;
    bucket: string;
    key: string;
    mimeType: string;
    expiresInSeconds?: number;
  }): string {
    const { accountId, accessKeyId, secretAccessKey, bucket, key, mimeType, expiresInSeconds = 3600 } = params;
    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.substring(0, 8);
    const region = 'auto';
    const service = 's3';
    const host = `${bucket}.${accountId}.r2.cloudflarestorage.com`;
    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;

    const queryParams: Record<string, string> = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': `${accessKeyId}/${credentialScope}`,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresInSeconds.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    const sortedQuery = Object.keys(queryParams)
      .sort()
      .map(k => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k])}`)
      .join('&');

    const canonicalUri = `/${key.split('/').map(encodeURIComponent).join('/')}`;
    const canonicalHeaders = `host:${host}\n`;
    const canonicalRequest = ['PUT', canonicalUri, sortedQuery, canonicalHeaders, 'host', 'UNSIGNED-PAYLOAD'].join('\n');

    const canonicalReqHash = crypto.createHash('sha256').update(canonicalRequest).digest('hex');
    const stringToSign = ['AWS4-HMAC-SHA256', amzDate, credentialScope, canonicalReqHash].join('\n');

    const kDate = crypto.createHmac('sha256', 'AWS4' + secretAccessKey).update(dateStamp).digest();
    const kRegion = crypto.createHmac('sha256', kDate).update(region).digest();
    const kService = crypto.createHmac('sha256', kRegion).update(service).digest();
    const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();
    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign).digest('hex');

    return `https://${host}${canonicalUri}?${sortedQuery}&X-Amz-Signature=${signature}`;
  }

  /**
   * Generate an upload URL for Cloudflare R2 ephemeral media (7-day TTL).
   */
  public async generateEphemeralUploadUrl(userId: string, filename: string, mimeType: string, blockSaving = false): Promise<{
    mediaKey: string;
    uploadUrl: string;
    publicUrl: string;
    expiresAt: Date;
    blockSaving: boolean;
  }> {
    const rows = await db.select().from(schema.couples)
      .where(
        and(
          or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)),
          eq(schema.couples.status, 'ACCEPTED')
        )
      )
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No accepted couple found to share media with');
    }

    // Verify sender subscription / trial access
    const billing = await billingService.getSubscriptionStatus(userId);
    if (!billing.hasChatAccess) {
      throw new Error('Subscription required: 3-day free trial has expired. Subscribe to Haven Sanctuary ($5/mo) to upload media.');
    }

    const couple = rows[0];
    const fileId = crypto.randomUUID();
    const cleanName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const mediaKey = `couples/${couple.id}/${fileId}_${cleanName}`;

    const r2AccountId = process.env.R2_ACCOUNT_ID?.trim() || config.R2_ACCOUNT_ID;
    const r2AccessKey = process.env.R2_ACCESS_KEY?.trim() || process.env.R2_ACCESS_KEY_ID?.trim() || config.R2_ACCESS_KEY_ID;
    const r2SecretKey = process.env.R2_SECRET_KEY?.trim() || process.env.R2_SECRET_ACCESS_KEY?.trim() || config.R2_SECRET_ACCESS_KEY;
    const r2Bucket = process.env.R2_BUCKET_NAME?.trim() || config.R2_BUCKET_NAME || 'offmesh';
    const r2PublicDomain = process.env.R2_PUBLIC_DOMAIN?.trim() || config.R2_PUBLIC_DOMAIN || 'http://localhost:3000/api/v1/couples/media/file';

    let uploadUrl = `/api/v1/couples/media/upload?key=${encodeURIComponent(mediaKey)}`;
    let publicUrl = `${r2PublicDomain}/${encodeURIComponent(mediaKey)}`;

    if (r2AccountId && r2AccessKey && r2SecretKey) {
      uploadUrl = this.generateR2PresignedPutUrl({
        accountId: r2AccountId,
        accessKeyId: r2AccessKey,
        secretAccessKey: r2SecretKey,
        bucket: r2Bucket,
        key: mediaKey,
        mimeType,
        expiresInSeconds: 3600,
      });
      publicUrl = `${r2PublicDomain}/${mediaKey}`;
    }

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7-day TTL

    return {
      mediaKey,
      uploadUrl,
      publicUrl,
      expiresAt,
      blockSaving,
    };
  }

  /**
   * Confirm and record ephemeral media metadata (7-day TTL).
   */
  public async recordEphemeralMedia(userId: string, params: {
    mediaKey: string;
    mediaUrl: string;
    mimeType: string;
    sizeBytes?: number;
    blockSaving?: boolean;
    durationSeconds?: number;
    maxViews?: number;
    watermarkEnabled?: boolean;
  }): Promise<EphemeralMediaRecord> {
    const rows = await db.select().from(schema.couples)
      .where(
        and(
          or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)),
          eq(schema.couples.status, 'ACCEPTED')
        )
      )
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No accepted couple found');
    }

    const couple = rows[0];
    const partnerId = couple.initiatorId === userId ? couple.partnerId : couple.initiatorId;

    // Check sender's chat permissions to see if global blockSaving is enabled
    const myPerms = await this.getPermissions(couple.id, userId);
    const effectiveBlockSaving = params.blockSaving ?? myPerms.blockSaving;
    const maxViews = params.maxViews !== undefined ? params.maxViews : 1;
    const watermarkEnabled = params.watermarkEnabled !== undefined ? params.watermarkEnabled : true;

    const id = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7-day TTL

    // Enforce 5-minute maximum video limit (300 seconds) with auto-clipping
    let durationSeconds = params.durationSeconds;
    if (params.mimeType.startsWith('video/') && durationSeconds && durationSeconds > 300) {
      durationSeconds = 300;
    }

    const [created] = await db.insert(schema.ephemeralMedia).values({
      id,
      coupleId: couple.id,
      senderId: userId,
      mediaKey: params.mediaKey,
      mediaUrl: params.mediaUrl,
      mimeType: params.mimeType,
      sizeBytes: params.sizeBytes || 0,
      blockSaving: effectiveBlockSaving,
      durationSeconds: durationSeconds,
      maxViews,
      viewCount: 0,
      isConsumed: false,
      watermarkEnabled,
      expiresAt,
    }).returning();

    // Deliver event to partner if online
    gatewayManager.sendToPeer(partnerId, {
      type: 'HAVEN_MEDIA',
      data: {
        mediaId: created.id,
        senderId: userId,
        mediaUrl: created.mediaUrl,
        mimeType: created.mimeType,
        blockSaving: created.blockSaving,
        durationSeconds: created.durationSeconds,
        maxViews: created.maxViews,
        viewCount: created.viewCount,
        isConsumed: created.isConsumed,
        watermarkEnabled: created.watermarkEnabled,
        expiresAt: created.expiresAt,
      },
    });

    return created;
  }

  /**
   * Consume an N-view ephemeral media view. Decrements remaining views and sets isConsumed = true when limit hit.
   */
  public async consumeMediaView(userId: string, mediaId: string): Promise<{
    mediaId: string;
    viewCount: number;
    maxViews: number;
    isConsumed: boolean;
  }> {
    const rows = await db.select().from(schema.ephemeralMedia)
      .where(eq(schema.ephemeralMedia.id, mediaId))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('Media not found or expired');
    }

    const media = rows[0];
    const newViewCount = media.viewCount + 1;
    const isConsumed = media.maxViews > 0 && newViewCount >= media.maxViews;

    await db.update(schema.ephemeralMedia)
      .set({
        viewCount: newViewCount,
        isConsumed,
      })
      .where(eq(schema.ephemeralMedia.id, mediaId));

    const coupleRows = await db.select().from(schema.couples)
      .where(eq(schema.couples.id, media.coupleId))
      .limit(1);

    if (coupleRows.length > 0) {
      const couple = coupleRows[0];
      const partnerId = couple.initiatorId === userId ? couple.partnerId : couple.initiatorId;

      const payload = {
        type: 'HAVEN_MEDIA_VIEW_UPDATE',
        data: {
          mediaId,
          viewCount: newViewCount,
          maxViews: media.maxViews,
          isConsumed,
        },
      };

      gatewayManager.sendToPeer(media.senderId, payload);
      gatewayManager.sendToPeer(partnerId, payload);
    }

    return {
      mediaId,
      viewCount: newViewCount,
      maxViews: media.maxViews,
      isConsumed,
    };
  }

  /**
   * Get wallpaper and customization for the chat screen.
   */
  public async getChatCustomization(userId: string): Promise<ChatCustomizationRecord> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No active couple found');
    }

    const couple = rows[0];
    const custRows = await db.select().from(schema.chatCustomization)
      .where(and(eq(schema.chatCustomization.coupleId, couple.id), eq(schema.chatCustomization.userId, userId)))
      .limit(1);

    if (custRows.length > 0) return custRows[0];

    const [created] = await db.insert(schema.chatCustomization).values({
      id: crypto.randomUUID(),
      coupleId: couple.id,
      userId,
      wallpaperUrl: null,
      themeColor: '#E11D48',
    }).returning();

    return created;
  }

  /**
   * Update wallpaper and customization for the chat screen.
   */
  public async updateChatCustomization(userId: string, params: {
    wallpaperUrl?: string | null;
    themeColor?: string;
  }): Promise<ChatCustomizationRecord> {
    const rows = await db.select().from(schema.couples)
      .where(or(eq(schema.couples.initiatorId, userId), eq(schema.couples.partnerId, userId)))
      .limit(1);

    if (rows.length === 0) {
      throw new Error('No active couple found');
    }

    const couple = rows[0];
    const existing = await this.getChatCustomization(userId);

    const [updated] = await db.update(schema.chatCustomization)
      .set({
        ...(params.wallpaperUrl !== undefined && { wallpaperUrl: params.wallpaperUrl }),
        ...(params.themeColor !== undefined && { themeColor: params.themeColor }),
        updatedAt: new Date(),
      })
      .where(eq(schema.chatCustomization.id, existing.id))
      .returning();

    return updated;
  }

  /**
   * Purge ephemeral media records that have passed their 7-day TTL.
   */
  public async cleanupExpiredMedia(): Promise<number> {
    const deleted = await db.delete(schema.ephemeralMedia)
      .where(lt(schema.ephemeralMedia.expiresAt, new Date()))
      .returning();
    return deleted.length;
  }
}

export const coupleService = new CoupleService();
