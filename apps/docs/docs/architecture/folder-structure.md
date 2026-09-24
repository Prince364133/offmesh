---
sidebar_position: 3
title: Folder Structure & Monorepo
---

# Monorepo Taxonomy & Folder Structure

The NearLink ecosystem is organized as a unified monorepo cleanly separating mobile clients, backend services, documentation portals, and reference protocol engines.

```
offline-messaging/
├── apps/
│   ├── backend/                     # Modular Monolith Backend API
│   │   ├── src/
│   │   │   ├── config/              # Environment variables & zod validation
│   │   │   ├── infra/
│   │   │   │   ├── crypto/          # Ed25519 & X25519 crypto helpers
│   │   │   │   ├── db/              # Drizzle ORM schema & Postgres client
│   │   │   │   └── redis/           # ioredis client & connection pool
│   │   │   ├── modules/
│   │   │   │   ├── identity/        # Auth nonces, contact registration, card parsing
│   │   │   │   ├── bundles/         # Ingest, NLB1 decoding, Redis deduplication
│   │   │   │   ├── receipts/        # Anti-packet receipts & atomic queue purging
│   │   │   │   ├── merkle/          # Time-bucketed Merkle sync (root & reconcile)
│   │   │   │   └── gateway/         # WebSocket peer presence & real-time dispatch
│   │   │   ├── workers/             # BullMQ background workers (bundle, indexer, sweeper)
│   │   │   ├── app.ts               # Fastify app builder & Swagger UI mount
│   │   │   └── index.ts             # Server entrypoint
│   │   ├── test/                    # Node test runner integration suites (8/8 pass)
│   │   ├── docker-compose.yml       # PostgreSQL 16 & Redis 7 container orchestration
│   │   └── package.json
│   │
│   ├── mobile/                      # Cross-Platform Mobile Application (Flutter)
│   │   ├── lib/
│   │   │   ├── core/
│   │   │   │   ├── crypto.dart      # Ed25519/X25519, NL1 card, Merkle root hashing
│   │   │   │   ├── models.dart      # Contact, MessageItem, MessageStatus, DiscoveredPeer
│   │   │   │   └── engine.dart      # NearLinkEngine ChangeNotifier, BLE & WS sync
│   │   │   ├── ui/
│   │   │   │   ├── theme.dart       # Obsidian Dark palette (#0A0E17) & Cyan accent
│   │   │   │   └── screens/
│   │   │   │       ├── radar_screen.dart      # Animated BLE Mesh Radar & RSSI
│   │   │   │       ├── contact_qr_screen.dart # Optical QR card & safety numbers
│   │   │   │       ├── chats_screen.dart      # Honest delivery status bubbles
│   │   │   │       └── gateway_screen.dart    # Cloud gateway & Merkle diff sync
│   │   │   └── main.dart            # Flutter application entrypoint
│   │   ├── test/                    # Mobile unit & smoke tests (5/5 pass)
│   │   ├── android/                 # Android native shell & BLE permissions
│   │   ├── ios/                     # iOS native shell & CoreBluetooth background modes
│   │   └── pubspec.yaml
│   │
│   └── docs/                        # Developer Documentation Portal (Docusaurus 3)
│       ├── docs/                    # Versioned technical Markdown documents
│       ├── src/                     # React components & custom dark theme styling
│       └── docusaurus.config.ts     # Docusaurus configuration
│
├── core/                            # Standalone Reference Protocol Engine (Java 21)
│   ├── src/net/nearlink/core/       # Cryptography, Bundle, Contact, Node, Store
│   └── test/net/nearlink/core/      # 22/22 native unit tests & multi-hop simulations
│
├── build.ps1                        # Native Windows compiler & test runner for Core
├── build.sh                         # Linux / macOS shell build script
├── STATUS.md                        # Project state & experimental milestones
└── EXPERIMENT_LOG.md                # Quantitative test logs (E-01 to E-07)
```

---

## Package Boundary Rules

1. **Self-Contained Mobile Client:** `apps/mobile` imports zero backend code and zero Java code. All cryptographic algorithms and wire parsers are natively implemented in pure Dart.
2. **Wire Compatibility:** Any binary frame encoded by `apps/mobile` (Dart) can be decoded identically by `core/` (Java) and `apps/backend/` (TypeScript).
3. **No Cross-Pollution:** Root-level directories only contain build scripts and reference engines; all active user-facing applications reside strictly under `apps/`.
