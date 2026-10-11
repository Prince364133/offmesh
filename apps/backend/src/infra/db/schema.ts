import { pgTable, varchar, text, integer, bigint, timestamp, boolean, index } from 'drizzle-orm/pg-core';

export const identities = pgTable('identities', {
  id: varchar('id', { length: 64 }).primaryKey(), // 32-byte Ed25519 public key hex
  encPublicKey: varchar('enc_public_key', { length: 64 }).notNull(), // 32-byte X25519 public key hex
  name: varchar('name', { length: 64 }).notNull(),
  card: text('card').notNull(), // Full NL1:... contact card
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).defaultNow().notNull(),
});

export const bundles = pgTable('bundles', {
  id: varchar('id', { length: 32 }).primaryKey(), // 16-byte Message ID hex
  senderId: varchar('sender_id', { length: 64 }).notNull().references(() => identities.id),
  recipientId: varchar('recipient_id', { length: 64 }).notNull().references(() => identities.id),
  payloadBase64: text('payload_base64').notNull(), // Raw wire bundle base64
  status: varchar('status', { length: 20 }).default('QUEUED').notNull(), // QUEUED, FORWARDED, DELIVERED, EXPIRED
  hopCount: integer('hop_count').default(0).notNull(),
  copies: integer('copies').default(1).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('bundles_recipient_idx').on(table.recipientId),
  index('bundles_status_idx').on(table.status),
  index('bundles_expires_at_idx').on(table.expiresAt),
  index('bundles_created_at_idx').on(table.createdAt),
]);

export const receipts = pgTable('receipts', {
  msgId: varchar('msg_id', { length: 32 }).primaryKey(), // 16-byte Message ID hex
  recipientId: varchar('recipient_id', { length: 64 }).notNull().references(() => identities.id),
  signature: varchar('signature', { length: 128 }).notNull(), // 64-byte Ed25519 signature hex
  deliveredAt: timestamp('delivered_at', { withTimezone: true }).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
}, (table) => [
  index('receipts_recipient_idx').on(table.recipientId),
  index('receipts_delivered_at_idx').on(table.deliveredAt),
  index('receipts_expires_at_idx').on(table.expiresAt),
]);

export const merkleBuckets = pgTable('merkle_buckets', {
  id: varchar('id', { length: 64 }).primaryKey(), // Key: "day-hour-bucket"
  day: bigint('day', { mode: 'number' }).notNull(),
  hour: integer('hour').notNull(),
  bucket: integer('bucket').notNull(),
  hash: varchar('hash', { length: 64 }).notNull(), // 32-byte SHA-256 hex
  recordCount: integer('record_count').default(0).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('merkle_day_hour_idx').on(table.day, table.hour),
]);

export const users = pgTable('users', {
  id: varchar('id', { length: 64 }).primaryKey(), // 32-byte Ed25519 public key hex or generated UUID
  username: varchar('username', { length: 32 }).notNull().unique(), // e.g. romeo_99
  email: varchar('email', { length: 255 }).unique(),
  passwordHash: text('password_hash'), // scrypt hash: "salt$derivedKey"
  googleId: varchar('google_id', { length: 128 }).unique(),
  oneEightyId: varchar('one_eighty_id', { length: 128 }).unique(),
  displayName: varchar('display_name', { length: 64 }).notNull(),
  avatarUrl: text('avatar_url'),
  signPublicKey: varchar('sign_public_key', { length: 64 }).notNull(), // Ed25519 32-byte hex
  encPublicKey: varchar('enc_public_key', { length: 64 }).notNull(), // X25519 32-byte hex
  moodStatus: varchar('mood_status', { length: 64 }).default('Available').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('users_username_idx').on(table.username),
  index('users_email_idx').on(table.email),
]);

export const couples = pgTable('couples', {
  id: varchar('id', { length: 36 }).primaryKey(), // UUID
  initiatorId: varchar('initiator_id', { length: 64 }).notNull().references(() => users.id),
  partnerId: varchar('partner_id', { length: 64 }).notNull().references(() => users.id),
  status: varchar('status', { length: 20 }).default('PENDING').notNull(), // PENDING, ACCEPTED, REJECTED
  anniversaryDate: timestamp('anniversary_date', { withTimezone: true }),
  initiatorNickname: varchar('initiator_nickname', { length: 64 }), // e.g. "My Sunshine"
  partnerNickname: varchar('partner_nickname', { length: 64 }),     // e.g. "My Romeo"
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('couples_initiator_idx').on(table.initiatorId),
  index('couples_partner_idx').on(table.partnerId),
]);

export const stealthSettings = pgTable('stealth_settings', {
  userId: varchar('user_id', { length: 64 }).primaryKey().references(() => users.id),
  appDisguise: varchar('app_disguise', { length: 32 }).default('CALCULATOR').notNull(), // CALCULATOR, NOTES, WEATHER, OFFMESH
  decoyPin: varchar('decoy_pin', { length: 16 }).default('1234').notNull(),
  notifDisguiseMode: varchar('notif_disguise_mode', { length: 32 }).default('CAMOUFLAGE').notNull(), // CAMOUFLAGE, DISCREET, NINJA, ROMANTIC
  fakeSenderTitle: varchar('fake_sender_title', { length: 64 }).default('System Update').notNull(),
  fakeBodyPreview: varchar('fake_body_preview', { length: 128 }).default('Sync completed successfully').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
});

export const couplePermissions = pgTable('couple_permissions', {
  id: varchar('id', { length: 36 }).primaryKey(), // UUID
  coupleId: varchar('couple_id', { length: 36 }).notNull().references(() => couples.id),
  userId: varchar('user_id', { length: 64 }).notNull().references(() => users.id),
  allowVibrate: boolean('allow_vibrate').default(true).notNull(),
  allowRing: boolean('allow_ring').default(true).notNull(),
  allowFlashlight: boolean('allow_flashlight').default(true).notNull(),
  blockScreenshots: boolean('block_screenshots').default(false).notNull(),
  blockSaving: boolean('block_saving').default(false).notNull(),
  blockCopying: boolean('block_copying').default(false).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('couple_permissions_couple_idx').on(table.coupleId),
  index('couple_permissions_user_idx').on(table.userId),
]);

export const ephemeralMedia = pgTable('ephemeral_media', {
  id: varchar('id', { length: 36 }).primaryKey(), // UUID
  coupleId: varchar('couple_id', { length: 36 }).notNull().references(() => couples.id),
  senderId: varchar('sender_id', { length: 64 }).notNull().references(() => users.id),
  mediaKey: varchar('media_key', { length: 128 }).notNull(),
  mediaUrl: text('media_url').notNull(),
  mimeType: varchar('mime_type', { length: 64 }).notNull(),
  sizeBytes: bigint('size_bytes', { mode: 'number' }).default(0).notNull(),
  blockSaving: boolean('block_saving').default(false).notNull(),
  durationSeconds: integer('duration_seconds'),
  maxViews: integer('max_views').default(1).notNull(), // 1, 2, 3, 4, 5, or 0 (unlimited within 7 days)
  viewCount: integer('view_count').default(0).notNull(),
  isConsumed: boolean('is_consumed').default(false).notNull(),
  watermarkEnabled: boolean('watermark_enabled').default(true).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(), // 7 days from creation
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('ephemeral_media_couple_idx').on(table.coupleId),
  index('ephemeral_media_expires_at_idx').on(table.expiresAt),
]);

export const chatCustomization = pgTable('chat_customization', {
  id: varchar('id', { length: 36 }).primaryKey(),
  coupleId: varchar('couple_id', { length: 36 }).notNull().references(() => couples.id),
  userId: varchar('user_id', { length: 64 }).notNull().references(() => users.id),
  wallpaperUrl: text('wallpaper_url'),
  themeColor: varchar('theme_color', { length: 32 }).default('#E11D48').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('chat_customization_couple_idx').on(table.coupleId),
  index('chat_customization_user_idx').on(table.userId),
]);

export const subscriptions = pgTable('subscriptions', {
  id: varchar('id', { length: 36 }).primaryKey(),
  userId: varchar('user_id', { length: 64 }).notNull().references(() => users.id).unique(),
  status: varchar('status', { length: 20 }).default('TRIAL').notNull(), // TRIAL, ACTIVE, EXPIRED, CANCELLED
  plan: varchar('plan', { length: 32 }).default('MONTHLY_5').notNull(),
  priceUsd: integer('price_usd').default(5).notNull(),
  trialEndsAt: timestamp('trial_ends_at', { withTimezone: true }).notNull(),
  subscriptionEndsAt: timestamp('subscription_ends_at', { withTimezone: true }),
  paymentProvider: varchar('payment_provider', { length: 32 }).default('STRIPE_GOOGLE_PLAY'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('subscriptions_user_idx').on(table.userId),
  index('subscriptions_status_idx').on(table.status),
]);

export const blockedUsers = pgTable('blocked_users', {
  id: varchar('id', { length: 36 }).primaryKey(), // UUID
  blockerId: varchar('blocker_id', { length: 64 }).notNull().references(() => users.id),
  blockedId: varchar('blocked_id', { length: 64 }).notNull().references(() => users.id),
  reason: varchar('reason', { length: 64 }), // HARASSMENT, UNWANTED_CONTACT, SAFETY_CONCERN
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('blocked_users_blocker_idx').on(table.blockerId),
  index('blocked_users_blocked_idx').on(table.blockedId),
]);

export const ghostPersonas = pgTable('ghost_personas', {
  id: varchar('id', { length: 36 }).primaryKey(), // UUID
  userId: varchar('user_id', { length: 64 }).notNull().references(() => users.id),
  aliasName: varchar('alias_name', { length: 64 }).notNull(),
  avatarPreset: varchar('avatar_preset', { length: 32 }).default('AVATAR_STARLIGHT').notNull(),
  isActive: boolean('is_active').default(true).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
  index('ghost_personas_user_idx').on(table.userId),
]);

export type IdentityRecord = typeof identities.$inferSelect;
export type NewIdentity = typeof identities.$inferInsert;
export type BundleRecord = typeof bundles.$inferSelect;
export type NewBundle = typeof bundles.$inferInsert;
export type ReceiptRecord = typeof receipts.$inferSelect;
export type NewReceipt = typeof receipts.$inferInsert;
export type MerkleBucketRecord = typeof merkleBuckets.$inferSelect;
export type NewMerkleBucket = typeof merkleBuckets.$inferInsert;
export type UserRecord = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type CoupleRecord = typeof couples.$inferSelect;
export type NewCouple = typeof couples.$inferInsert;
export type StealthSettingsRecord = typeof stealthSettings.$inferSelect;
export type NewStealthSettings = typeof stealthSettings.$inferInsert;
export type CouplePermissionRecord = typeof couplePermissions.$inferSelect;
export type NewCouplePermission = typeof couplePermissions.$inferInsert;
export type EphemeralMediaRecord = typeof ephemeralMedia.$inferSelect;
export type NewEphemeralMedia = typeof ephemeralMedia.$inferInsert;
export type ChatCustomizationRecord = typeof chatCustomization.$inferSelect;
export type NewChatCustomization = typeof chatCustomization.$inferInsert;
export type SubscriptionRecord = typeof subscriptions.$inferSelect;
export type NewSubscription = typeof subscriptions.$inferInsert;
export type BlockedUserRecord = typeof blockedUsers.$inferSelect;
export type NewBlockedUser = typeof blockedUsers.$inferInsert;
export type GhostPersonaRecord = typeof ghostPersonas.$inferSelect;
export type NewGhostPersona = typeof ghostPersonas.$inferInsert;

