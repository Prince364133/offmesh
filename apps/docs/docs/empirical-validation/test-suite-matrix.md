---
sidebar_position: 2
title: Automated Test Suite Matrix (35/35 Passing)
description: Complete catalogue of the 35 automated tests spanning pure Java Core, Fastify Modular Monolith backend, and Flutter mobile client.
---

# Automated Test Suite Matrix (35/35 Passing)

NearLink maintains a 100% automated test pass rate across three distinct runtime layers:
1. **Core Java Protocol Engine** (22 tests)
2. **Modular Monolith Backend API** (8 tests)
3. **Cross-Platform Flutter Mobile Client** (5 tests)

---

## 1. Core Java Protocol Engine (`core/`)

Executed via `./build.ps1` (Windows) and `./build.sh` (Linux) with pure OpenJDK 21.

| Test ID | Test Name / Scope | Verification Target | Status |
| :--- | :--- | :--- | :--- |
| `T01` | **HKDF-SHA256 Basic Extraction** | RFC 5869 pseudorandom key expansion and salt handling. | `PASS` |
| `T02` | **HKDF-SHA256 RFC 5869 Vector 1** | Strict cryptographic parity with official IETF test vectors. | `PASS` |
| `T03` | **Key Identity & Contact Cards** | Ed25519 and X25519 serialization into `NL1` format. | `PASS` |
| `T04` | **AEAD Sealing & Tamper Detection** | ChaCha20-Poly1305 encryption, AAD validation, bit-flip rejection. | `PASS` |
| `T05` | **Malformed Bundle Parsing** | Rejection of truncated buffers and invalid magic prefixes. | `PASS` |
| `T06` | **Bounded Frame Reader** | Enforcement of 16 KB maximum frame size limits. | `PASS` |
| `T07` | **Cryptographic Delivery Receipts** | Anti-packet validation and recipient signature checking. | `PASS` |
| `T08` | **Single Hop Delivery & Honest Status** | Direct peer delivery and `QUEUED` $\rightarrow$ `DELIVERED` status transition. | `PASS` |
| `T09` | **Deduplication & Seen Sets** | Rejection of duplicate transmissions of identical bundle IDs. | `PASS` |
| `T10` | **Atomic Persistence Across Restarts** | Recovery of queues and inbox from disk after process cut. | `PASS` |
| `T11` | **Two-Hop Relay Forwarding** | Store-carry-forward through intermediate relay node. | `PASS` |
| `T12` | **Relay Payload Secrecy** | Verification that intermediate nodes cannot decrypt payloads. | `PASS` |
| `T13` | **Forged Receipt Rejection** | Discarding anti-packets signed by unauthorized third-party keys. | `PASS` |
| `T14` | **Bundle Lifetime & Expiry** | Expired bundle deletion and suppression of stale deliveries. | `PASS` |
| `T15` | **Unknown Sender Rejection** | Enforcement of contact-gated acceptance rules. | `PASS` |
| `T16` | **Relay Storage Quota Enforcement** | Returning `ACK_FULL` when local queue capacity is reached. | `PASS` |
| `T17` | **Interrupted Transfer Safety** | Idempotent resume when socket cuts mid-stream. | `PASS` |
| `T18` | **Randomized Binary Fuzzing** | 20,000 randomized corrupt payloads without crash or memory leak. | `PASS` |
| `T19` | **Session Bundle & Receipt Caps** | Defense against session-level flooding attacks. | `PASS` |
| `T20` | **Loopback TCP Transport** | Socket communication over real loopback network stack. | `PASS` |
| `T21` | **Multi-Hop Gateway & Mesh Pruning** | Network-wide anti-packet propagation and queue purging. | `PASS` |
| `T22` | **Microsecond Merkle Reconciliation** | Hierarchical time-bucketed Merkle tree reconciliation. | `PASS` |

---

## 2. Modular Monolith Backend API (`apps/backend/`)

Executed via `npm test` using Node.js 24 native test runner.

| Test ID | Test Name / Scope | Verification Target | Status |
| :--- | :--- | :--- | :--- |
| `B01` | **Health & Merkle Root Endpoint** | `GET /health` returns HTTP 200 and valid 32-byte root hash. | `PASS` |
| `B02` | **Identity Registration & Contact Card** | `POST /api/v1/identities/register` validates Ed25519 signature. | `PASS` |
| `B03` | **Challenge-Response Authentication** | `POST /api/v1/identities/challenge` issues crypto nonces. | `PASS` |
| `B04` | **Merkle Tree Root Query** | `GET /api/v1/sync/merkle/root` returns tree state. | `PASS` |
| `B05` | **Microsecond Merkle Sync (Identical)** | `POST /api/v1/sync/merkle/reconcile` detects zero differences. | `PASS` |
| `B06` | **Microsecond Merkle Sync (Divergent)** | Detects diverging buckets and returns missing identifiers. | `PASS` |
| `B07` | **Delivery Receipt Verification** | `POST /api/v1/messages/receipt` validates Ed25519 recipient signature. | `PASS` |
| `B08` | **WebSocket Gateway Manager** | Real-time peer connection tracking and message dispatch. | `PASS` |

---

## 3. Cross-Platform Flutter Mobile Client (`apps/mobile/`)

Executed via `flutter test` across Dart 3 test runner.

| Test ID | Test Name / Scope | Verification Target | Status |
| :--- | :--- | :--- | :--- |
| `M01` | **Contact Card NL1 Parser & Formatter** | Roundtrip encoding/decoding of public keys and display names. | `PASS` |
| `M02` | **Symmetrical Safety Code Computation** | Deterministic 20-digit safety code generation. | `PASS` |
| `M03` | **Honest Message Status State Machine** | Strict transitions: `QUEUED` $\rightarrow$ `FORWARDED` $\rightarrow$ `DELIVERED`. | `PASS` |
| `M04` | **Binary Merkle Root Hash Computation** | SHA-256 tree root derivation matching backend parity. | `PASS` |
| `M05` | **Widget Tree Smoke & Navigation** | Navigation bar routing between Radar, Chats, People, Settings. | `PASS` |
