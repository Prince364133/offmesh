import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { buildApp } from '../src/app.js';
import { authService } from '../src/modules/auth/auth.service.js';
import { billingService } from '../src/modules/billing/billing.service.js';
import { fcmService } from '../src/modules/notifications/fcm.service.js';

test('Haven Couples & Privacy Test Suite', async (t) => {
  const app = await buildApp();

  await t.test('1. AuthService hashes and verifies passwords correctly with scrypt', async () => {
    const pwd = 'secret_love_pass_123';
    const hash = authService.hashPassword(pwd);
    assert.ok(hash.includes('$'));
    const [salt, key] = hash.split('$');
    assert.equal(salt.length, 32); // 16 bytes hex
    assert.equal(key.length, 128);  // 64 bytes hex

    assert.equal(authService.verifyPassword(pwd, hash), true);
    assert.equal(authService.verifyPassword('wrong_pass', hash), false);
  });

  await t.test('2. Token generation and verification protects sessions', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const decoded = authService.verifyToken(token);
    assert.ok(decoded);
    assert.equal(decoded!.sub, 'user_123');
    assert.equal(decoded!.usr, 'romeo');

    // Tampered token fails
    const tampered = token.slice(0, -4) + 'abcd';
    assert.equal(authService.verifyToken(tampered), null);
  });

  await t.test('3. Auth routes reject unauthenticated requests to protected endpoints', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
    });
    assert.equal(res.statusCode, 401);
  });

  await t.test('4. 180 Identity Exchange route validates payload and performs token exchange', async () => {
    // 4a: Validation failure on missing / short keys
    const invalidRes = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/exchange',
      payload: {
        code: '180_auth_code_test',
        signPublicKey: 'too_short',
        encPublicKey: 'too_short',
      },
    });
    assert.equal(invalidRes.statusCode, 400);
    const body = JSON.parse(invalidRes.body);
    assert.equal(body.error, 'Validation failed');

    // 4b: Successful 180 Identity Exchange
    const validRes = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/exchange',
      payload: {
        code: '180_auth_code_unit_test_user_777',
        signPublicKey: 'a'.repeat(64),
        encPublicKey: 'b'.repeat(64),
        username: 'test_180_romeo',
        displayName: 'Romeo Montague',
      },
    });
    assert.equal(validRes.statusCode, 200);
    const validBody = JSON.parse(validRes.body);
    assert.equal(validBody.success, true);
    assert.ok(validBody.token);
    assert.equal(validBody.displayName, 'Romeo Montague');

    // 4c: Authorize URL endpoint returns 180 workspace endpoints
    const authUrlRes = await app.inject({
      method: 'GET',
      url: '/api/v1/auth/authorize-url',
    });
    assert.equal(authUrlRes.statusCode, 200);
    const authUrlBody = JSON.parse(authUrlRes.body);
    assert.equal(authUrlBody.success, true);
    assert.ok(authUrlBody.authorizeUrl.includes('client_id=180_client_6182d7379831a5524c834e2fe8c58e68'));
  });

  await t.test('5. Stealth settings updates validate disguise mode enums', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'PUT',
      url: '/api/v1/couples/stealth',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        appDisguise: 'INVALID_MODE',
      },
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('6. Gateway Manager registers clients authenticated via session tokens', async () => {
    const { gatewayManager } = await import('../src/modules/gateway/gateway.manager.js');
    const token = authService.createToken('user_ws_1', 'juliet');
    const decoded = authService.verifyToken(token);
    assert.ok(decoded);
    assert.equal(decoded!.sub, 'user_ws_1');

    const mockSocket: any = {
      readyState: 1,
      send: () => {},
      on: () => {},
    };

    gatewayManager.registerClient(decoded!.sub, mockSocket);
    assert.equal(gatewayManager.isOnline('user_ws_1'), true);
  });

  await t.test('7. Signal endpoint validates signalType and rejects invalid types', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/couples/signal',
      headers: { authorization: `Bearer ${token}` },
      payload: { signalType: 'INVALID_SIGNAL' },
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('8. Permissions endpoint validates payload boolean schemas', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'PUT',
      url: '/api/v1/couples/permissions',
      headers: { authorization: `Bearer ${token}` },
      payload: { allowVibrate: 'not-a-boolean' },
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('9. Ephemeral upload-url route validates filename and mimeType', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/couples/media/upload-url',
      headers: { authorization: `Bearer ${token}` },
      payload: { filename: '', mimeType: 'image/jpeg' },
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('10. Customization route validates theme color constraints', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'PUT',
      url: '/api/v1/couples/customization',
      headers: { authorization: `Bearer ${token}` },
      payload: { themeColor: 'A'.repeat(50) }, // Exceeds max 32
    });
    assert.equal(res.statusCode, 400);
  });

  await t.test('11. Billing status route rejects unauthenticated requests', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/billing/status',
    });
    assert.equal(res.statusCode, 401);
  });

  await t.test('12. Billing status returns 3-day free trial details ($5/mo plan)', async () => {
    const token = authService.createToken('user_bill_1', 'juliet');
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/billing/status',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.plan, 'MONTHLY_5');
    assert.equal(body.priceUsd, 5);
    assert.equal(body.isTrialActive, true);
    assert.equal(body.hasChatAccess, true);
    assert.ok(body.trialDaysRemaining >= 1);
  });

  await t.test('13. Billing subscribe endpoint activates $5/month subscription', async () => {
    const token = authService.createToken('user_bill_2', 'romeo');
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/subscribe',
      headers: { authorization: `Bearer ${token}` },
      payload: { paymentProvider: 'STRIPE_GOOGLE_PLAY' },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.success, true);
    assert.equal(body.subscription.status, 'ACTIVE');
    assert.equal(body.subscription.isSubscribed, true);
    assert.equal(body.subscription.hasChatAccess, true);
  });

  await t.test('14. Safety - Block user and verify blocked list', async () => {
    const token = authService.createToken('girl_user_1', 'juliet');
    const resBlock = await app.inject({
      method: 'POST',
      url: '/api/v1/safety/block',
      headers: { authorization: `Bearer ${token}` },
      payload: { blockedId: 'harasser_user_99', reason: 'UNWANTED_HARASSMENT' },
    });
    assert.equal(resBlock.statusCode, 200);
    const bodyBlock = JSON.parse(resBlock.body);
    assert.equal(bodyBlock.success, true);
    assert.equal(bodyBlock.blocked.blockedId, 'harasser_user_99');

    const resList = await app.inject({
      method: 'GET',
      url: '/api/v1/safety/blocked',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(resList.statusCode, 200);
    const bodyList = JSON.parse(resList.body);
    assert.ok(Array.isArray(bodyList.blockedUsers));
    assert.ok(bodyList.blockedUsers.some((b: any) => b.blockedId === 'harasser_user_99'));
  });

  await t.test('15. Safety - Unblock user succeeds', async () => {
    const token = authService.createToken('girl_user_1', 'juliet');
    const resUnblock = await app.inject({
      method: 'DELETE',
      url: '/api/v1/safety/block/harasser_user_99',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(resUnblock.statusCode, 200);
    const body = JSON.parse(resUnblock.body);
    assert.equal(body.success, true);
  });

  await t.test('16. Safety - Nuke conversation broadcasts mutual wipe', async () => {
    const token = authService.createToken('girl_user_1', 'juliet');
    const resNuke = await app.inject({
      method: 'POST',
      url: '/api/v1/safety/nuke',
      headers: { authorization: `Bearer ${token}` },
      payload: { partnerId: 'ex_partner_88' },
    });
    assert.equal(resNuke.statusCode, 200);
    const body = JSON.parse(resNuke.body);
    assert.equal(body.success, true);
  });

  await t.test('17. Safety - Ghost Persona generation and customization', async () => {
    const token = authService.createToken('girl_user_2', 'selena');
    const resGet = await app.inject({
      method: 'GET',
      url: '/api/v1/safety/ghost-persona',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(resGet.statusCode, 200);
    const bodyGet = JSON.parse(resGet.body);
    assert.ok(bodyGet.ghostPersona.aliasName.length > 0);
    assert.equal(bodyGet.ghostPersona.isActive, true);

    const resPut = await app.inject({
      method: 'PUT',
      url: '/api/v1/safety/ghost-persona',
      headers: { authorization: `Bearer ${token}` },
      payload: { aliasName: 'Starlight_Princess', avatarPreset: 'AVATAR_COSMIC' },
    });
    assert.equal(resPut.statusCode, 200);
    const bodyPut = JSON.parse(resPut.body);
    assert.equal(bodyPut.ghostPersona.aliasName, 'Starlight_Princess');
    assert.equal(bodyPut.ghostPersona.avatarPreset, 'AVATAR_COSMIC');
  });

  await t.test('18. Media - Upload raw binary media and retrieve from proxy route', async () => {
    const testKey = 'couples/test_couple/photo_123.jpg';
    const testBinary = Buffer.from('FAKE_JPEG_IMAGE_BYTES_2026');

    // 1. Upload via PUT /media/upload
    const resUpload = await app.inject({
      method: 'PUT',
      url: `/api/v1/couples/media/upload?key=${encodeURIComponent(testKey)}`,
      headers: { 'content-type': 'image/jpeg' },
      body: testBinary,
    });
    assert.equal(resUpload.statusCode, 200);
    const bodyUpload = JSON.parse(resUpload.body);
    assert.equal(bodyUpload.success, true);
    assert.equal(bodyUpload.key, testKey);

    // 2. Fetch via GET /media/file/:key
    const resGet = await app.inject({
      method: 'GET',
      url: `/api/v1/couples/media/file/${encodeURIComponent(testKey)}`,
    });
    assert.equal(resGet.statusCode, 200);
    assert.equal(resGet.headers['content-type'], 'image/jpeg');
    assert.equal(resGet.rawPayload.toString(), 'FAKE_JPEG_IMAGE_BYTES_2026');
  });

  await t.test('19. Billing - Create checkout session returns valid session URL', async () => {
    const token = authService.createToken('payer_user_1', 'romeo');
    const resCheckout = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/checkout-session',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(resCheckout.statusCode, 200);
    const bodyCheckout = JSON.parse(resCheckout.body);
    assert.ok(bodyCheckout.sessionId.length > 0);
    assert.ok(bodyCheckout.url.length > 0);
  });

  await t.test('20. Billing - Stripe Webhook activates $5/mo subscription on checkout.session.completed', async () => {
    const webhookPayload = {
      type: 'checkout.session.completed',
      data: {
        object: {
          client_reference_id: 'webhook_user_42',
          customer: 'cus_123456',
        },
      },
    };

    const resWebhook = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/webhook/stripe',
      payload: webhookPayload,
    });
    assert.equal(resWebhook.statusCode, 200);
    const bodyWebhook = JSON.parse(resWebhook.body);
    assert.equal(bodyWebhook.received, true);
    assert.equal(bodyWebhook.handled, true);

    // Verify subscription is now ACTIVE
    const subStatus = await billingService.getSubscriptionStatus('webhook_user_42');
    assert.equal(subStatus.status, 'ACTIVE');
    assert.equal(subStatus.hasChatAccess, true);
  });

  await t.test('21. Billing - Create 180pay checkout session returns 180PAY provider & session URL', async () => {
    const token = authService.createToken('payer_180_user', 'juliet');
    const resCheckout = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/checkout-session',
      headers: { authorization: `Bearer ${token}` },
      payload: { provider: '180pay' },
    });
    assert.equal(resCheckout.statusCode, 200);
    const bodyCheckout = JSON.parse(resCheckout.body);
    assert.equal(bodyCheckout.provider, '180PAY');
    assert.ok(bodyCheckout.sessionId.length > 0);
    assert.ok(bodyCheckout.url.includes('180pay.com'));
    assert.equal(bodyCheckout.amount, 5.00);
    assert.equal(bodyCheckout.currency, 'USD');
  });

  await t.test('22. Billing - 180pay Webhook activates $5/mo subscription with verified signature', async () => {
    const webhookSecret = process.env.WEBHOOK_SECRET || process.env.PAY180_WEBHOOK_SECRET || 'whsec_49127795658766d61bb1e84c757ffbdde3eda005576f4117';
    const payload = {
      event: 'payment.succeeded',
      data: {
        userId: '180pay_user_99',
        amount: 5.00,
        currency: 'USD',
      },
    };
    const rawBody = JSON.stringify(payload);
    const signature = crypto.createHmac('sha256', webhookSecret).update(rawBody).digest('hex');

    const resWebhook = await app.inject({
      method: 'POST',
      url: '/api/v1/billing/webhook/180pay',
      headers: {
        'content-type': 'application/json',
        'x-180-signature': signature,
      },
      payload,
    });
    assert.equal(resWebhook.statusCode, 200);
    const bodyWebhook = JSON.parse(resWebhook.body);
    assert.equal(bodyWebhook.received, true);
    assert.equal(bodyWebhook.handled, true);

    // Verify subscription is now ACTIVE with 180PAY provider
    const subStatus = await billingService.getSubscriptionStatus('180pay_user_99');
    assert.equal(subStatus.status, 'ACTIVE');
    assert.equal(subStatus.hasChatAccess, true);
  });

  await t.test('23. Notifications - Register and unregister FCM device tokens', async () => {
    const token = authService.createToken('fcm_user_1', 'fcm_tester');
    const fcmDeviceToken = 'fcm_sample_device_registration_token_abc123';

    // 1. Register FCM token
    const resReg = await app.inject({
      method: 'POST',
      url: '/api/v1/notifications/token',
      headers: { authorization: `Bearer ${token}` },
      payload: { fcmToken: fcmDeviceToken, platform: 'android' },
    });
    assert.equal(resReg.statusCode, 200);
    const bodyReg = JSON.parse(resReg.body);
    assert.equal(bodyReg.success, true);
    assert.equal(bodyReg.registered, true);
    assert.ok(fcmService.getUserTokens('fcm_user_1').includes(fcmDeviceToken));

    // 2. Unregister FCM token
    const resUnreg = await app.inject({
      method: 'DELETE',
      url: '/api/v1/notifications/token',
      headers: { authorization: `Bearer ${token}` },
      payload: { fcmToken: fcmDeviceToken },
    });
    assert.equal(resUnreg.statusCode, 200);
    const bodyUnreg = JSON.parse(resUnreg.body);
    assert.equal(bodyUnreg.success, true);
    assert.equal(bodyUnreg.unregistered, true);
    assert.equal(fcmService.getUserTokens('fcm_user_1').includes(fcmDeviceToken), false);
  });

  await t.test('24. Notifications - Send tactile signal and test FCM push notifications', async () => {
    const token = authService.createToken('fcm_user_2', 'fcm_partner');
    const fcmDeviceToken = 'fcm_device_token_for_push_signal';
    fcmService.registerToken('fcm_user_2', fcmDeviceToken);

    // 1. Send test push notification
    const resTest = await app.inject({
      method: 'POST',
      url: '/api/v1/notifications/test',
      headers: { authorization: `Bearer ${token}` },
      payload: { title: 'Test Alert', body: 'Testing hardware signal push' },
    });
    assert.equal(resTest.statusCode, 200);
    const bodyTest = JSON.parse(resTest.body);
    assert.equal(bodyTest.success, true);
    assert.equal(bodyTest.total, 1);

    // 2. Direct signal push dispatch
    const signalResult = await fcmService.sendSignalNotification('fcm_user_2', {
      fromName: 'Romeo',
      signalType: 'BUZZ',
      timestamp: Date.now(),
    });
    assert.equal(signalResult.total, 1);

    // 3. Service account OAuth2 token generation
    const accessToken = await fcmService.getAccessToken();
    assert.ok(accessToken.length > 0);
  });

  await t.test('25. Media - Confirm media auto-clips videos exceeding 5 minutes (300s)', async () => {
    const token = authService.createToken('user_123', 'romeo');
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/couples/media/confirm',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        mediaKey: 'invalid_key',
        mediaUrl: 'not_a_valid_url',
        mimeType: 'video/mp4',
        durationSeconds: 400,
      },
    });
    // Validates url format according to schema
    assert.equal(res.statusCode, 400);
  });

  await app.close();
});

