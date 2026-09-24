# Architecture (as implemented, v0.1)

```
 ┌──────────── Android app (android/) ─────────────┐
 │ MainActivity  – test UI: contacts, compose,      │
 │                 statuses, BT scan, LAN sync, log │
 │ MeshService   – foreground service (connected-   │
 │                 Device): BT + TCP listeners,     │
 │                 retries remembered peers /90 s   │
 │ BluetoothLink – RFCOMM (insecure) transport      │
 └──────────────┬───────────────────────────────────┘
                │ InputStream / OutputStream
 ┌──────────────▼──── core/ (pure Java, JVM-tested) ┐
 │ SyncSession  – symmetric anti-entropy protocol   │  transport-independent
 │ TcpTransport – LAN/hotspot TCP                   │
 │ Node         – queue, relay store, inbox, dedupe,│
 │                expiry, Spray-and-Wait, statuses  │
 │ Sealer/Bundle/Receipt – E2E crypto, wire formats │
 │ Identity/Contact – keys, cards, safety codes     │
 │ Store        – atomic file persistence           │
 └──────────────────────────────────────────────────┘
```

Layers requested in the brief → where they live:

| Layer | Implementation | Status |
|---|---|---|
| Application | `MainActivity` (plain Android views) | written, type-checked, **not run on a device** |
| Message processing (ids, timestamps, expiry, dedupe, ACKs, retry) | `Node`, `SyncSession` | tested (JVM) |
| Security | `Crypto`, `Sealer`, `Receipt`, `Identity` | tested (JVM); Android provider support unverified → runtime self-test + BouncyCastle fallback |
| Transport abstraction | anything giving a byte stream → `SyncSession` | BT (untested), TCP (tested on loopback) |
| Local storage | `Store.FileStore` (write-temp, fsync, atomic rename) | tested across simulated restarts |
| Routing/forwarding | binary Spray-and-Wait in `Node.bundlesFor` | tested + simulated |

## Identities and addressing
- Each install generates Ed25519 (signing) + X25519 (key agreement). **Address = SHA-256(signPub ‖ dhPub).** No phone number, account, or server.
- Contacts are added by exchanging a card `NL1:<base64url(name, signPub, dhPub)>` in person (copy/paste now; QR planned). A 20-hex-digit **safety code** is shown for out-of-band comparison.

## Bundle (wire format, big-endian)
```
"NLB1" | msgId(16, random) | recipientId(32) | createdMs(8) | expiresMs(8)
| copies(1) | hopCount(1) | hopLimit(1) | ephemeralPub(32) | ctLen(2) | ciphertext
```
- AAD = magic‖msgId‖recipientId‖created‖expires‖eph (immutable). copies/hop fields are mutable routing metadata, **unauthenticated by design**.
- Ciphertext = ChaCha20-Poly1305 over `type | senderSignPub | senderDhPub | sentAt | body | Ed25519 sig`; key+nonce from HKDF-SHA256(salt=msgId, ikm=X25519(eph, recipientDh), info="NLv1"‖eph‖recipientDh).
- Limits: body ≤ 4000 B, ciphertext ≤ 6 KiB, lifetime ≤ 7 days (default 3), clock skew tolerance 10 min.

## Receipt (anti-packet)
`msgId | expiresMs | recipientSignPub | recipientDhPub | Ed25519 sig("NLRCPT1"|msgId|expires)`.
Any node holding the bundle verifies `SHA-256(keys) == recipientId` and the signature, then deletes its copy. Forged receipts (attacker keys) fail the binding check (test T13).

## Sync protocol (per contact, both sides symmetric)
```
→ HELLO(version, nodeId)       ← HELLO
→ SUMMARY(seen ids, receipt ids) ← SUMMARY
→ RECEIPTs the peer lacks
→ BUNDLEs per forwarding rule   ← (per bundle) RECEIPT if delivered, then ACK(code)
→ DONE                          ← DONE
close when: both DONE sent/received and all our BUNDLEs ACKed
```
Frames: `len u32 (≤16 KiB) | type u8 | payload`. Per-session caps: 200 bundles, 1000 receipts. Malformed bundle → dropped; malformed framing → session aborted.

## Forwarding rule (binary Spray-and-Wait, Spyropoulos et al. 2005)
- Peer **is** destination → send.
- Else if `copies > 1` and hops remain → give ⌊copies/2⌋, keep the rest **after** the peer ACKs (interruption-safe).
- Else (wait phase) → only direct delivery.
Default L = 8, hop limit 8. L=1 ⇒ direct-delivery only.

## Honest delivery statuses (sender side)
| Status | Meaning | Shown text |
|---|---|---|
| QUEUED | only on this phone | "Queued on this phone – not yet sent to anyone" |
| FORWARDED | ≥1 relay ACKed storage | "Carried by N other device(s) – delivery NOT confirmed" |
| DELIVERED | recipient-signed receipt verified | "Delivered (recipient signed a receipt)" |
| EXPIRED | lifetime passed without receipt | "Expired – never confirmed delivered" |
Unauthenticated link-level ACK codes are never shown as "delivered".

## Data flow example (2 hops)
Alice `send()` → bundle QUEUED → contact with Relay: relay stores (copies 8→4/4), Alice FORWARDED → Relay meets Bob: Bob opens, verifies Alice's signature, stores message, returns receipt; Relay deletes its copy → Relay meets Alice: receipt verified → DELIVERED. (Test T11.)

## Not implemented yet (future)
Forward secrecy/ratchet, QR scanning, BLE discovery beacon, Wi-Fi Aware / Nearby transports, group chats, attachments, key-at-rest encryption via Android Keystore, per-peer fairness quotas, smarter (PRoPHET-style) routing.
