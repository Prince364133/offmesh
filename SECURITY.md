# Security model and threat analysis (v0.1)

**A successful transmission test is not proof of secure messaging.** This design uses only standard primitives (X25519, Ed25519, HKDF-SHA256, ChaCha20-Poly1305) via the platform JCA; the *protocol* composing them is new and has **not been independently reviewed**. Bridgefy adopted libsignal and was still broken by protocol-level mistakes (Albrecht, Eikenberg, Paterson, USENIX Security 2022). Treat this as a research prototype, not a tool for high-risk users.

## Assets
Message content · sender identity · who-talks-to-whom metadata · device availability · storage/battery.

## Adversaries
Passive radio eavesdropper · malicious relay phone · active attacker on the BT/Wi-Fi link · flooding/spam device · thief with an unlocked phone.

## Threats → status

| Threat | Mitigation in v0.1 | Tested | Residual risk |
|---|---|---|---|
| Eavesdropping on radio or relay reading content | E2E AEAD to recipient's X25519 key | T04, T12 | — |
| Tampering with content or immutable header | AEAD with header as AAD + sender signature | T04 | — |
| Tampering with copies/hopCount | none (mutable routing fields) | T04 (confirms decryption unaffected) | Relay can drop, stop spraying, or inflate copies (bounded by hopLimit ≤ 255 and expiry) |
| Sender impersonation | Ed25519 signature inside ciphertext; recipient only accepts known contacts | T15 | Key substitution at contact exchange if safety codes aren't compared |
| Surreptitious forwarding (re-encrypt to someone else) | Signature covers recipientId and msgId (AAD) | by construction | — |
| Replay of an old bundle | seen-set + receipts until expiry; expired bundles refused; created ≤ now+10 min | T09, T14 | After `seen` entry expires the bundle has also expired, so replay is refused by expiry. Clock-manipulated phones weaken this |
| Forged "delivered" to purge messages | receipts must be signed by the key hashing to recipientId | T13 | — |
| Fake delivery status shown to user | only verified receipts set DELIVERED | T07, T11 | — |
| Malformed input crashing parser | bounds-checked reader, frame ≤ 16 KiB, fuzzed 20k inputs | T06, T18 | Not a full coverage fuzzer |
| Bundle/receipt flooding in one session | per-session caps 200/1000 | T19 | Attacker can reconnect repeatedly; no per-peer rate limit yet |
| Storage exhaustion on relays | maxRelayBundles (500) → ACK_FULL | T16 | Honest messages can be crowded out; no eviction policy |
| Spam to recipient | messages from non-contacts refused | T15 | Spam still consumes relay storage |
| Device tracking via HELLO nodeId | **not mitigated** — nodeId = stable identity hash | — | Nearby observers who learn your id can recognise you. Also Bluetooth MAC exposure. Future: rotating session ids |
| Metadata: recipientId visible to relays; receipts reveal "R got M" | **not mitigated** | — | Inherent to routable store-and-forward without mixing |
| Compromise of recipient's long-term X25519 key | **no forward secrecy** | — | Past captured bundles decryptable. Future: prekeys/ratchet |
| Keys at rest | app-private files (Android sandbox + device file-based encryption) | — | Not wrapped with Android Keystore; rooted/forensic access exposes keys and plaintext history |
| Bluetooth link attacks | insecure RFCOMM; no reliance on BT security | — | Link-level DoS/jamming possible |

## Why "insecure" RFCOMM is acceptable here
All confidentiality/integrity/authenticity are provided end-to-end on each bundle and receipt, so an unauthenticated link only enables DoS or metadata observation, both already listed above.

## Recommended before any public release
1. External cryptographic review of `Sealer`/`Receipt`/`SyncSession`.
2. QR-based contact exchange with mandatory safety-code verification UX.
3. Rotating ephemeral HELLO identifiers.
4. Keystore-wrapped identity key; optional app PIN.
5. Evaluate adopting an audited protocol (Signal X3DH/Double Ratchet or MLS) for pairwise sessions, keeping our bundle layer only for routing.
