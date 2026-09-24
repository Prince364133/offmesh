---
sidebar_position: 4
title: Security Model & Threat Analysis
description: Comprehensive threat modeling, adversary profiles, cryptographic guarantees, and residual risks.
---

# Security Model & Threat Analysis

NearLink is engineered under an adversarial model where physical radio links, intermediate relay nodes, and public gateways are inherently untrusted.

---

## 1. Protected Assets

- **Message Confidentiality:** Text and file payloads must remain indecipherable to intermediate relays and network eavesdroppers.
- **Message Integrity & Authenticity:** Neither headers nor payloads may be modified or forged in transit without immediate rejection.
- **Non-Repudiation:** Delivery receipts must cryptographically prove receipt by the intended destination.
- **Relay Storage & Battery:** Nodes must be protected from resource-exhaustion attacks (bundle flooding, replay attacks).

---

## 2. Adversary Model

1. **Passive Radio Eavesdropper:** Monitors 2.4 GHz RFCOMM, BLE, or Wi-Fi packets.
2. **Malicious Relay Node:** Carries bundles but attempts to inspect contents, inject corrupted payloads, or forge delivery acknowledgments.
3. **Active Network Attacker:** Replays old valid messages, drops packets, or injects malformed binary frames to crash parsers.
4. **Device Thief:** Gains physical access to an unlocked or locked smartphone.

---

## 3. Threat Mitigation Matrix

| Threat | Mitigation Mechanism | Empirical Test | Residual Risk |
| :--- | :--- | :--- | :--- |
| **Radio Eavesdropping** | End-to-end ChaCha20-Poly1305 AEAD using ephemeral-static X25519 shared secret. | `T04`, `T12` | None (payloads are cryptographically indecipherable to relays). |
| **Payload Tampering** | Poly1305 16-byte authentication tag; any bit flip fails decryption. | `T04` | None (corrupted packets discarded instantly). |
| **Sender Impersonation** | Ed25519 signature inside encrypted envelope; recipient rejects non-contact senders. | `T15` | Contact key substitution if out-of-band safety codes are skipped. |
| **Surreptitious Forwarding** | Sender signature binds `recipientId` and `msgId` directly into signed envelope. | By Construction | None. |
| **Replay Attacks** | Deduplication index + strictly enforced expiration timestamps; expired packets rejected. | `T09`, `T14` | Severe clock manipulation on sender devices can cause premature rejection. |
| **Forged Anti-Packets** | Anti-packet receipts must carry an Ed25519 signature verified against the destination node ID. | `T13` | None (relays ignore unauthenticated anti-packets). |
| **Malformed Framing / Crashes** | Strict bounds-checked binary decoders with maximum frame limits (16 KB) and fuzzing. | `T06`, `T18` | Zero crashes across 20,000 randomized binary fuzz frames. |
| **Session Flooding** | Per-session transfer caps (200 bundles, 1000 receipts) and peer connection cooldowns. | `T19` | Reconnection floods mitigated by local rate limiters. |
| **Relay Storage Exhaustion** | Storage quota limits (e.g. 50 MB / 500 bundles); relays return `ACK_FULL` when capacity is reached. | `T16` | Malicious floods can crowd out honest bundles in the absence of contact whitelisting. |
| **Device Theft & Key Extraction** | Master encryption keys protected via hardware-backed Android KeyStore / iOS Keychain (AES-256-GCM). | `E-05` | Rooted forensic access on devices without secure hardware enclaves. |

---

## 4. Metadata & Privacy Considerations

- **Routable Addressing:** Relays must read `recipientId` (`SHA-256(recipientKeys)`) and `msgId` to determine forwarding eligibility. While message bodies are private, encounter frequency and message volume are visible to local observers.
- **Forward Secrecy:** NearLink v1 uses ephemeral-static X25519 key agreement to allow asynchronous one-shot delivery without pre-established sessions. Long-term compromise of a recipient's static private key allows retrospective decryption of captured historical bundles. Future protocol revisions plan Double Ratchet session ratcheting once direct contact occurs.
