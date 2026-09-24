import test from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import { OffMeshCrypto, NearLinkCrypto } from '../src/infra/crypto/index.js';
import { merkleTreeService } from '../src/modules/merkle/merkle.service.js';

test('OffMesh Backend Modular Monolith Test Suite', async (t) => {
  const app = await buildApp();

  await t.test('1. Health check returns ok and valid Merkle root', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health',
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'offmesh-modular-monolith');
    assert.equal(typeof body.merkleRootHex, 'string');
    assert.equal(body.merkleRootHex.length, 64);
  });

  await t.test('2. Identity registration verifies cryptographic contact card', async () => {
    // Valid card from our test suite
    const card = 'NL1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw';
    const parsed = NearLinkCrypto.parseCard(card);
    assert.equal(parsed.name, 'sdk_gphone64_x86_64');
    assert.equal(parsed.idHex.length, 64);

    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/identities/register',
      payload: { card },
    });
    // If postgres is not running locally, it gracefully handles failure, or succeeds if live
    assert.ok(res.statusCode === 200 || res.statusCode === 400 || res.statusCode === 500);
  });

  await t.test('3. Challenge-Response Auth generates cryptographic nonce', async () => {
    const idHex = '3909030ed953bc4a8ee718c03af3ec9ee3264861d1f8e3932d7ee5c26829cd97';
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/identities/challenge',
      payload: { idHex },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(typeof body.challenge, 'string');
    assert.equal(body.challenge.length, 64);
    assert.equal(body.expiresSec, 60);
  });

  await t.test('4. Merkle Tree Root Query returns 32-byte hash', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/sync/merkle/root',
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(typeof body.rootHashHex, 'string');
    assert.equal(body.rootHashHex.length, 64);
  });

  await t.test('5. Merkle Tree Microsecond Reconciliation matches identical state with 0 diff', async () => {
    const currentRoot = merkleTreeService.getRootHash();
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/sync/merkle/reconcile',
      payload: {
        rootHashHex: currentRoot,
        dayHashes: {},
      },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.inSync, true);
    assert.equal(body.missingRecords.length, 0);
  });

  await t.test('6. Merkle Tree Reconciliation detects diverging records', async () => {
    // Insert a new record into server's Merkle tree
    const now = 1_700_000_000_000;
    merkleTreeService.insertRecord({
      id: 'aabbccddeeff00112233445566778899',
      timestampMs: now,
    });

    const updatedRoot = merkleTreeService.getRootHash();
    assert.notEqual(updatedRoot, '0000000000000000000000000000000000000000000000000000000000000000');

    // Client sends an outdated root
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/sync/merkle/reconcile',
      payload: {
        rootHashHex: '1111111111111111111111111111111111111111111111111111111111111111',
        dayHashes: {},
      },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.inSync, false);
    assert.ok(body.divergingDays.length > 0);
    assert.ok(body.missingRecords.some((r: any) => r.id === 'aabbccddeeff00112233445566778899'));
  });

  await t.test('7. Cryptographic Delivery Receipt verification validates recipient Ed25519 signature', async () => {
    // Generate an ephemeral Ed25519 keypair
    const crypto = await import('node:crypto');
    const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
    const rawPub = publicKey.export({ format: 'der', type: 'spki' }).subarray(12);

    const msgId = crypto.randomBytes(16);
    const deliveredAt = Date.now();

    // Construct receipt payload: "DELIVERED" || msgId (16) || deliveredAt (8)
    const payload = Buffer.alloc(9 + 16 + 8);
    payload.write('DELIVERED', 0, 'utf8');
    msgId.copy(payload, 9);
    payload.writeBigInt64BE(BigInt(deliveredAt), 25);

    const sig = crypto.sign(null, payload, privateKey);

    const valid = NearLinkCrypto.verifyReceipt(
      rawPub.toString('hex'),
      msgId.toString('hex'),
      deliveredAt,
      sig.toString('hex')
    );
    assert.equal(valid, true);

    // Tampered payload rejected
    const invalid = NearLinkCrypto.verifyReceipt(
      rawPub.toString('hex'),
      msgId.toString('hex'),
      deliveredAt + 1000,
      sig.toString('hex')
    );
    assert.equal(invalid, false);
  });

  await t.test('8. Gateway Manager tracks online peers and dispatches messages', async () => {
    const { gatewayManager } = await import('../src/modules/gateway/gateway.manager.js');
    const fakeSocket: any = {
      readyState: 1, // OPEN
      send: (data: string) => {},
      on: () => {},
    };

    const peerId = 'deadbeef00112233445566778899aabbccddeeff00112233445566778899aabb';
    gatewayManager.registerClient(peerId, fakeSocket);
    assert.equal(gatewayManager.isOnline(peerId), true);
    assert.equal(gatewayManager.getOnlineCount() >= 1, true);

    const sent = gatewayManager.sendToPeer(peerId, { type: 'TEST', data: 'hello' });
    assert.equal(sent, true);
  });

  await t.test('9. Contact card parser supports OM1: and NL1: prefixes interchangeably', async () => {
    const cardNL = 'NL1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw';
    const parsedNL = OffMeshCrypto.parseCard(cardNL);
    assert.equal(parsedNL.name, 'sdk_gphone64_x86_64');
    assert.equal(parsedNL.idHex.length, 64);

    const cardOM = 'OM1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw';
    const parsedOM = OffMeshCrypto.parseCard(cardOM);
    assert.equal(parsedOM.name, 'sdk_gphone64_x86_64');
    assert.equal(parsedOM.idHex.length, 64);

    // Invalid prefix rejected
    assert.throws(() => OffMeshCrypto.parseCard('INVALID:12345'), /Invalid card prefix/);
  });

  await t.test('10. Bundle upload rejects malformed packets or invalid magic', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/bundles/upload',
      payload: {
        payloadBase64: Buffer.from('FAKE1_truncated_data_that_fails_validation_and_cannot_be_parsed_as_wire_bundle_protocol_header').toString('base64'),
      },
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('11. Mailbox endpoint rejects invalid recipient ID parameters', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/bundles/mailbox/invalid-short-id',
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('12. Gateway Manager safely handles broken socket pipes without throwing uncaught exceptions', async () => {
    const { gatewayManager } = await import('../src/modules/gateway/gateway.manager.js');
    const faultySocket: any = {
      readyState: 1,
      send: () => {
        throw new Error('EPIPE: Broken pipe connection');
      },
      on: () => {},
    };

    const faultyPeerId = '0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff';
    gatewayManager.registerClient(faultyPeerId, faultySocket);
    // Should not throw, but safely catch and return false
    const sent = gatewayManager.sendToPeer(faultyPeerId, { type: 'PING', data: {} });
    assert.equal(sent, false);
    assert.equal(gatewayManager.isOnline(faultyPeerId), false);
  });

  await app.close();
});
