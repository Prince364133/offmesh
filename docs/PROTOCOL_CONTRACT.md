# Canonical OffMesh protocol and gateway contract

This contract freezes the existing Java core wire format for the Android-first implementation. All implementations must use shared fixtures and preserve domain separation. No OM1 rebranding of cryptographic domains is permitted.

## Identity/contact
Node ID is SHA-256(signPub[32] || dhPub[32]), lowercase 64-character hex. It is NOT the signing public key. Contact card is `NL1:` plus unpadded base64url of nameLength[u16 BE] || UTF-8 name (max 64 bytes) || signPub[32] || dhPub[32], with no trailing bytes. Safety code follows Java `Contact.safetyCode`, not the previous Dart variant.

## Bundle
`NLB1`[4] || msgId[16] || recipientId[32] || createdMs[u64 BE] || expiresMs[u64 BE] || copies[u8] || hopCount[u8] || hopLimit[u8] || ephemeralPub[32] || ciphertextLength[u16 BE] || ciphertext.
Header 105 bytes. Ciphertext max 6144 bytes. No version byte, sender ID, or external signature. Sender signature is INSIDE the encrypted envelope; a gateway cannot verify it and must not pretend it can. AEAD immutable fields and derivation follow Java `Bundle`/`Sealer`. Max lifetime 7 days, clock skew allowance 10 minutes, copies >= 1, hopCount <= hopLimit. Strict canonical decoding and bounds required.

## Receipt
msgId[16] || expiresMs[u64 BE] || recipientSignPub[32] || recipientDhPub[32] || signature[64]. Exactly 152 bytes. Signature covers UTF-8 `NLRCPT1` || msgId || expiresMs. Receipt recipientId = SHA-256(signPub || dhPub). A self-valid signature alone is NOT delivery proof: message ID, recipient identity, and exact expiry must match the bundle. Unknown receipts must never suppress unrelated future bundles merely by message ID.

## Gateway API (JSON, except binary values encoded standard base64)
All production requests use HTTPS/WSS. Local cleartext may be enabled explicitly for private-LAN development; do not silently accept public HTTP. CORS restricted to configured origins. Rate and size bounds on all routes.

- `GET /health`: liveness; `GET /ready`: dependency readiness (503 if not ready).
- `POST /api/v1/identities/register`: `{card, signatureHex}`. Signature is Ed25519 over UTF-8 `OFFMESH-REGISTER-v1\n` concatenated with EXACT canonical card string. Server validates identity/card and proof before persistence. Response `{success:true, identity:{idHex,...}}`.
- `POST /api/v1/identities/challenge`: `{idHex}` for registered identity. Response `{challenge, expiresSec}`; challenge is 64 lowercase random hex characters, expires after 60s.
- `POST /api/v1/identities/verify`: `{idHex, signatureHex}`. Signed bytes are UTF-8 `OFFMESH-AUTH-v1\n` + challenge. Nonce is consumed atomically once. Verify using registered signPub, NOT idHex. Response `{authenticated:true,idHex,token,expiresSec}`. Token is opaque random bearer credential stored hashed with bounded expiry, not a claim trusted from the caller.
- All remaining APIs require `Authorization: Bearer TOKEN`. Token bound to ID. Registration/challenge protected by rate limits too.
- `POST /api/v1/bundles/upload`: `{payloadBase64}` canonical bundle; authenticated relays may upload opaque bundles for any recipient. Success 201 `{status:'ACCEPTED',msgId}`, duplicate 409 `{status:'DUPLICATE',msgId}`, expired 410. Acknowledged accepted/duplicate means durable storage or existing verified receipt, never recipient delivery.
- `GET /api/v1/bundles/mailbox/:recipientIdHex?limit=100&after=...`: caller ID must equal recipient ID; return `{count,bundles:[{id,payloadBase64,expiresAt}],nextCursor?}`. Non-destructive fetch, sorted stable pagination.
- `POST /api/v1/receipts/submit`: `{payloadBase64}` canonical full signed receipt. Authenticate submitting relay but verify recipient binding to stored bundle before status/pruning. Unknown bundle may return 404 (client retains receipt for retry); no global poisoning from unbound receipts. Returns `{status:'ACCEPTED'|'ALREADY_PROCESSED',msgIdHex}`. Duplicate must match existing receipt identity/expiry. Transactionally persist full receipt and delete message payload. Retain tombstone through original expiry.
- `GET /api/v1/receipts/:msgIdHex`: authenticated relay lookup; `{receipt:{payloadBase64,...}}`, 404 if missing. Client must verify full receipt itself. Never trust server status/ID alone.
- `GET /ws`: authenticated socket; supports bearer header for native clients. Client identity comes from session, NOT query ID. Notifications contain only hints (`BUNDLE_AVAILABLE`, `RECEIPT_AVAILABLE`); client polls authorized mailbox/full receipt to verify.
- Optional Merkle endpoints remain authenticated. Merkle IDs alone cannot set delivery state. Deterministic ordering, duplicates, restart, and pruning tested. Correctness must work through mailbox/receipt polling even without Merkle or WebSocket.

## Android gateway synchronization sequence
Validate configured endpoint -> register with proof -> challenge/sign/verify -> upload bounded held bundles (including relay bundles) -> fetch own mailbox -> feed bundles to core -> submit locally held receipts -> fetch receipts for pending held/outgoing IDs -> feed full receipts to core -> persist state. Use bounded request/connect/read timeouts, pagination, failure visibility, and idempotent retry. Do not mark delivered based on HTTP 2xx, duplicate, WebSocket hint, or a Merkle record. Preserve queues on every failure.
