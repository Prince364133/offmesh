---
sidebar_position: 1
title: Wire Protocol & Binary Framing
description: Canonical wire formats for contact cards (NL1), encrypted bundles (NLB1), anti-packet receipts (NLR1), and sync frames.
---

# Wire Protocol & Binary Framing

NearLink uses compact, deterministic, big-endian binary framing designed for ultra-low MTU radio links, high transmission efficiency, and memory-safe parsing.

---

## 1. Contact Card Format (`NL1`)

Used for out-of-band QR code exchange and peer introduction.

```text
"NL1:" || Base64UrlSafe(
    nameLength (2 bytes, unsigned big-endian)
    || utf8NameBytes (N bytes, max 64)
    || ed25519SigningPublicKey (32 bytes)
    || x25519AgreementPublicKey (32 bytes)
)
```

### Safety Number Derivation
A 20-digit human-comparable numeric code formatted in four 5-digit groups (e.g. `12345 67890 24680 13579`):
```text
hash = SHA-256(min(signPubA, signPubB) || max(signPubA, signPubB))
safetyCode = BigInteger(hash[0..8]) mod 10^20
```

---

## 2. Encrypted Message Bundle Format (`NLB1`)

The standard store-carry-forward wire packet transported across peer radio hops and gateway servers.

| Field | Size (Bytes) | Description |
| :--- | :--- | :--- |
| **Magic** | 4 | ASCII `"NLB1"` |
| **Message ID** | 16 | Cryptographically secure random identifier |
| **Recipient Node ID** | 32 | `SHA-256(recipientSignPub \|\| recipientDhPub)` |
| **Created Timestamp** | 8 | Milliseconds since Unix epoch (int64) |
| **Expiry Timestamp** | 8 | Milliseconds since Unix epoch (int64, default 3 days) |
| **Spray Copies ($L$)** | 1 | Mutable relay forwarding quota (e.g. 8) |
| **Hop Count** | 1 | Number of transit hops traversed |
| **Hop Limit** | 1 | Maximum allowable hops (default 8) |
| **Ephemeral Public Key** | 32 | Sender's one-time X25519 public key |
| **Ciphertext Length** | 2 | Unsigned 16-bit integer (max 6144 bytes) |
| **AEAD Ciphertext** | Var | ChaCha20-Poly1305 ciphertext + 16-byte Poly1305 MAC |

### Associated Authenticated Data (AAD)
To prevent header modification or routing tampering, the AEAD encryption binds the immutable fields:
```text
AAD = Magic (4) || MsgId (16) || RecipientId (32) || CreatedMs (8) || ExpiresMs (8) || EphemeralPub (32)
```

### Decrypted Payload Structure
```text
Payload = MessageType (1 byte)
       || SenderEd25519SignPub (32 bytes)
       || SenderX25519DhPub (32 bytes)
       || SentTimestampMs (8 bytes)
       || BodyLength (2 bytes)
       || BodyUtf8Text (N bytes, max 4000)
       || SenderEd25519Signature (64 bytes)
```

The signature inside the ciphertext covers:
```text
SigPayload = "NLv1" || MsgId || RecipientId || SentTimestampMs || BodyUtf8Text
```

---

## 3. Cryptographic Anti-Packet Receipt (`NLR1`)

A compact proof-of-delivery packet that propagates backward through the mesh and cloud gateways to purge redundant relay copies.

| Field | Size (Bytes) | Description |
| :--- | :--- | :--- |
| **Magic** | 6 | ASCII `"NLRCPT"` |
| **Message ID** | 16 | The 16-byte identifier of the delivered bundle |
| **Expiry Timestamp** | 8 | Milliseconds since Unix epoch matching the bundle |
| **Recipient Sign PubKey** | 32 | Ed25519 public key of the recipient |
| **Recipient DH PubKey** | 32 | X25519 public key of the recipient |
| **Signature** | 64 | Ed25519 signature over `("NLRCPT1" \|\| msgId \|\| expiresMs)` |

### Relay Validation Rule
Any relay holding a bundle validates the anti-packet before deletion:
1. Verify `SHA-256(recipientSignPubKey || recipientDhPubKey) == bundle.recipientNodeId`.
2. Verify Ed25519 signature over `"NLRCPT1" || msgId || expiresMs` using `recipientSignPubKey`.
3. If both match, delete bundle from relay queue and append receipt to local anti-packet index.

---

## 4. Peer-to-Peer Stream Framing (`SyncSession`)

When two nodes establish a TCP, BLE GATT, or RFCOMM stream, messages are partitioned into framed packets:

```text
Frame = FrameLength (4 bytes, unsigned big-endian, max 16,384 bytes)
     || FrameType (1 byte)
     || PayloadData (N bytes)
```

### Frame Type Identifiers
- `0x01` — `HELLO`: Handshake exchanging version (`uint16`) and local `nodeId` (`32 bytes`).
- `0x02` — `SUMMARY`: Vector exchange containing seen bundle IDs and held receipt IDs.
- `0x03` — `RECEIPT`: Anti-packet transmission.
- `0x04` — `BUNDLE`: Encrypted bundle transmission.
- `0x05` — `ACK`: Per-bundle acknowledgment code (`0x00 = OK`, `0x01 = FULL`, `0x02 = REJECT`).
- `0x06` — `DONE`: Graceful session completion signal.
