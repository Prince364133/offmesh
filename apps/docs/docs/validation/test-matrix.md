---
sidebar_position: 1
title: Automated Test Matrix
---

# Complete Automated Test Matrix (35 / 35 Passing)

NearLink maintains a 100% automated test pass rate across all layers of the monorepo.

---

## 1. Core Java Reference Protocol Suite (`core/test/`)

Run natively via `./build.ps1` or `./build.sh`:

| ID | Test Description | Purpose / Assertion |
|---|---|---|
| **T01** | Cryptographic self-test | X25519, Ed25519, HKDF-SHA256, ChaCha20-Poly1305 validation |
| **T02** | RFC 5869 HKDF test vector | Conformance against RFC 5869 Appendix A.1 test vector |
| **T03** | Seal / Open roundtrip | Plaintext seal/open roundtrip with UTF-8 & emoji payloads |
| **T04** | Tamper detection | Ciphertext bit-flip, header tamper, and wrong recipient rejection |
| **T05** | Contact card roundtrip | `NL1:...` card serialization & symmetric 20-digit safety numbers |
| **T06** | Parser fuzzing | 20,000 random bit mutated inputs to parsers without crash |
| **T07** | Direct delivery session | SyncSession direct bundle delivery & Ed25519 signed receipt |
| **T08** | Duplicate transmission | Re-sync delivers 0 duplicate inbox entries |
| **T09** | Replayed bundle injection | Raw byte injection rejected by persistent dedupe cache |
| **T10** | Persistence across reboot | Queue survives process restart with SQLite / FileStore |
| **T11** | Two-hop store-and-forward | Bundle hops $A \rightarrow R \rightarrow B$, receipt returns $B \rightarrow R \rightarrow A$ |
| **T12** | Intermediate privacy | Relay carrier $R$ cannot decrypt ciphertext or alter metadata |
| **T13** | Forged receipt rejection | Attacker's signature on receipt rejected; bundle kept |
| **T14** | Expiration purging | Expired bundles purged from queue with `EXPIRED` status |
| **T15** | Unknown sender spam filter | Unregistered sender rejected at session establishment |
| **T16** | Relay storage quota | Capacity exhaustion returns `ACK_FULL`; sender retains bundle |
| **T17** | Connection cut mid-transfer | TCP socket abruptly severed; retry delivers exactly once |
| **T18** | Malformed frame defense | Hostile peer frames terminate session cleanly |
| **T19** | Bundle flood rate limit | Excessive frame floods capped per session |
| **T20** | Loopback TCP sockets | True TCP networking stack test (simulating Wi-Fi Hotspot) |
| **T21** | Multi-hop opportunistic gateway | 6-node simulation: A, B, C, D, E, Server; anti-packet prunes all |
| **T22** | Time-Bucketed Merkle sync | 10,000 records reconciled in 15 microseconds (in sync) / 2.3ms |

---

## 2. Backend Modular Monolith Suite (`apps/backend/test/`)

Run natively via `npm test` inside `apps/backend`:

| ID | Test Description | Assertion |
|---|---|---|
| **B01** | Health Check & Merkle Root | `GET /health` returns 200, online peer counter, and 32-byte Merkle root |
| **B02** | Identity Card Registration | `POST /api/v1/identities/register` validates `NL1:...` cryptographic contact card |
| **B03** | Challenge-Response Auth | `POST /api/v1/identities/challenge` generates cryptographic nonce |
| **B04** | Merkle Root Query | `GET /api/v1/sync/merkle/root` returns deterministic root hash |
| **B05** | Microsecond Diff Reconciliation | `POST /api/v1/sync/merkle/reconcile` completes in under 3 ms with 0 diff |
| **B06** | Divergence Detection | Reconcile detects injected missing records across buckets |
| **B07** | Delivery Receipt Verification | Ingests recipient Ed25519 anti-packet and validates signature |
| **B08** | Gateway Manager & Presence | Tracks active WebSocket connections and peer presence |

---

## 3. Flutter Cross-Platform Client Suite (`apps/mobile/test/`)

Run natively via `flutter test` inside `apps/mobile`:

| ID | Test Description | Assertion |
|---|---|---|
| **M01** | Card Formatting & Parsing | Roundtrip `NL1:...` card serialization matches canonical Node ID |
| **M02** | Safety Code Formatting | Formats 20-digit code into 4 groups of 5 characters |
| **M03** | Honest Status Transitions | Verifies state machine `QUEUED` $\rightarrow$ `FORWARDED (Hops: 1)` $\rightarrow$ `DELIVERED` |
| **M04** | Binary Merkle Root Calculation | Deterministic binary Merkle hash calculation matches backend |
| **M05** | NearLinkApp Smoke Test | Headless widget mounting confirms presence of Radar, Messages, Card, Gateway |
