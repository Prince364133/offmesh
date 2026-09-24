---
sidebar_position: 4
title: Architectural Decision Records (ADRs)
description: Formal engineering decisions (D-01 through D-10) shaping NearLink's offline delay-tolerant networking, cryptography, and storage.
---

# Architectural Decision Records (ADRs)

This document records the foundational engineering decisions made during the design and implementation of the NearLink / OffMesh platform.

---

### D-01: Target a Local Delay-Tolerant Network, Not a Long-Range Direct Channel
- **Decision:** Optimize for short-range radio ad-hoc links (BLE, Wi-Fi Direct, Local Hotspot) combined with store-carry-forward delay-tolerant networking.
- **Alternatives Considered:** GNSS transmission, arbitrary-frequency unlicensed transmission, Bluetooth Mesh (SIG), satellite messaging, LoRa.
- **Rationale:**
  - Smartphones cannot transmit to GNSS satellites (GNSS chips are strictly receive-only).
  - Radios are firmware-locked and type-certified; unlicensed transmission is illegal and hardware-constrained.
  - Standard SIG Bluetooth Mesh on Android supports only provisioner/proxy roles, not autonomous ad-hoc relaying between smartphones.
  - Satellite messaging is carrier-controlled, vendor-locked, and closed to third-party arbitrary data payloads.
  - LoRa requires specialized external hardware dongles.

---

### D-02: Initial Transports: BLE + Bluetooth Classic RFCOMM + LAN TCP
- **Decision:** Support BLE rendezvous, Bluetooth Classic RFCOMM byte streams, and local TCP sockets over phone hotspots or Wi-Fi Direct.
- **Alternatives Considered:** Google Nearby Connections, Wi-Fi Aware (`NAN`).
- **Rationale:** Pure AOSP APIs operate across all Android 12+ devices without requiring proprietary Google Play Services. Nearby Connections announced in late 2026 that it will no longer silently auto-enable radios. Wi-Fi Aware hardware (`FEATURE_WIFI_AWARE`) is missing on many budget chipsets.

---

### D-03: Transport-Independent Pure Java Protocol Engine (`core/`)
- **Decision:** Implement the wire framing, anti-entropy synchronization, cryptographic verification, and Spray-and-Wait forwarding in a pure Java library with zero mandatory external runtime dependencies.
- **Rationale:** Enables deterministic JVM-level testing, prevents dependency bloat, allows seamless compilation in both Android apps and server environments, and guarantees protocol portability.

---

### D-04: Application-Level Store-Carry-Forward with Binary Spray-and-Wait ($L=8$)
- **Decision:** Use binary Spray-and-Wait ($L=8$, hop limit 8) for multi-hop bundle replication.
- **Alternatives Considered:** Epidemic routing (flooding), direct-delivery only, PRoPHET routing (RFC 6693).
- **Rationale:** In empirical simulations (E-03), Spray-and-Wait ($L=8$) reached 95–100% delivery ratio within 6 hours while generating over 60% fewer transmissions than epidemic flooding, conserving battery and flash storage.

---

### D-05: Authenticated End-to-End Cryptography (X25519 + HKDF-SHA256 + ChaCha20-Poly1305 + Ed25519)
- **Decision:** One-shot sign-then-encrypt payload construction using ephemeral-static X25519 key agreement, HKDF-SHA256 key derivation, ChaCha20-Poly1305 AEAD, and Ed25519 identity signatures.
- **Alternatives Considered:** Libsignal (Double Ratchet / Signal Protocol), OpenPGP.
- **Rationale:** Signal Protocol requires interactive sessions, prekey bundles, and round-trips that are impossible during fleeting 2-second physical encounters between strangers. One-shot static key agreement enables zero-round-trip encryption.

---

### D-06: Publicly Verifiable Signed Delivery Receipts (Anti-Packets)
- **Decision:** Delivery receipts are signed by the ultimate recipient's private key and include the bundle ID. Any relay node holding the bundle can independently verify `SHA-256(recipientKeys) == recipientId` and the signature, and purge the delivered bundle from its local store.
- **Rationale:** Prevents relay storage exhaustion by terminating forwarding jobs across the mesh once a message reaches its destination.

---

### D-07: Cryptographically Honest Delivery Statuses
- **Decision:** Sender UI status transitions to `DELIVERED` **only** upon cryptographic verification of an authenticated recipient receipt.
- **Rationale:** Link-level ACKs only verify that a neighbor phone accepted a forwarding job (`FORWARDED`). Misleading users into believing a message is delivered when it is merely in transit destroys trust in offline emergency communication.

---

### D-08: Contact-Gated Acceptance by Default
- **Decision:** By default, user inboxes only accept and decrypt messages from verified contacts in the address book.
- **Rationale:** Protects mobile devices from unsolicited spam and malicious broadcast floods in dense environments.

---

### D-09: Atomic Snapshot Storage with Keystore Encryption
- **Decision:** Local bundle queues, seen indices, and identity records are persisted using atomic write-to-temp and fsync renames, protected by hardware-backed Android KeyStore AES-256-GCM master keys.
- **Rationale:** Protects keys and messages at rest against device theft while preventing database corruption during unexpected battery cutoffs.

---

### D-10: Hierarchical Time-Bucketed Merkle Tree Synchronization
- **Decision:** Organize bundle and cancellation state into hierarchical Day $\rightarrow$ Hour $\rightarrow$ 5-Minute Merkle trees.
- **Rationale:** Reconciles identical states in 15 microseconds (32 bytes exchanged) and pinpoints differences in 2.3 milliseconds, saving 99% of bandwidth compared to linear array dumping over slow radio links.
