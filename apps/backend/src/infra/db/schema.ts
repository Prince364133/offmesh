import { pgTable, varchar, text, integer, bigint, timestamp, index } from 'drizzle-orm/pg-core';

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

export type IdentityRecord = typeof identities.$inferSelect;
export type NewIdentity = typeof identities.$inferInsert;
export type BundleRecord = typeof bundles.$inferSelect;
export type NewBundle = typeof bundles.$inferInsert;
export type ReceiptRecord = typeof receipts.$inferSelect;
export type NewReceipt = typeof receipts.$inferInsert;
export type MerkleBucketRecord = typeof merkleBuckets.$inferSelect;
export type NewMerkleBucket = typeof merkleBuckets.$inferInsert;
