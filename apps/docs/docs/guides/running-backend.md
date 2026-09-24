---
sidebar_position: 3
title: Running the Backend Gateway Server
description: Instructions for spinning up the Fastify Modular Monolith, PostgreSQL, Redis, BullMQ workers, and Swagger UI.
---

# Running the Backend Gateway Server

The NearLink Gateway in [`apps/backend/`](file:///c:/Users/saavi/Desktop/offline-messaging/apps/backend/) is an enterprise-grade **Modular Monolith** built on **Node.js 24 + TypeScript**, **Fastify 5**, **PostgreSQL 16** (via Drizzle ORM), **Redis 7**, and **BullMQ** asynchronous background workers.

---

## 1. Prerequisites

- **Node.js:** v22.0.0+ (Tested on v24.12.0)
- **Package Manager:** npm 10+
- **Database & Cache (Optional for dev mock):**
  - PostgreSQL 16+ on port `5432`
  - Redis 7+ on port `6379`

---

## 2. Environment Configuration

Copy the example environment file:

```bash
cd apps/backend
cp .env.example .env
```

Configuration defaults:
```env
PORT=3000
HOST=0.0.0.0
NODE_ENV=development
DATABASE_URL=postgres://nearlink:secret@localhost:5432/nearlink
REDIS_URL=redis://localhost:6379
LOG_LEVEL=info
```

---

## 3. Starting Infrastructure with Docker Compose

If running full database and queue services locally:

```bash
# In project root
docker compose -f docker-compose.backend.yml up -d
```

This provisions:
- PostgreSQL instance mapped to `localhost:5432`
- Redis cache mapped to `localhost:6379`

---

## 4. Running Database Migrations

Apply Drizzle schema migrations to PostgreSQL:

```bash
cd apps/backend
npm run db:push
```

---

## 5. Starting the Server

### Development Mode (with Hot Reloading)
```bash
cd apps/backend
npm run dev
```

### Production Mode
```bash
npm run build
npm start
```

---

## 6. Accessing API & Swagger UI

Once started, the backend exposes:
- **Interactive Swagger UI:** [http://127.0.0.1:3000/docs/](http://127.0.0.1:3000/docs/)
- **OpenAPI 3.0.3 Spec:** [http://127.0.0.1:3000/docs/json](http://127.0.0.1:3000/docs/json)
- **Health Check:** [http://127.0.0.1:3000/health](http://127.0.0.1:3000/health)
- **WebSocket Gateway:** `ws://127.0.0.1:3000/ws`

---

## 7. Running the Automated Test Suite

Verify all 8 modular monolith integration tests:

```bash
cd apps/backend
npm test
```

Expected output:
```text
▶ NearLink Backend Modular Monolith Test Suite
  ✔ 1. Health check returns ok and valid Merkle root
  ✔ 2. Identity registration verifies cryptographic contact card
  ✔ 3. Challenge-Response Auth generates cryptographic nonce
  ✔ 4. Merkle Tree Root Query returns 32-byte hash
  ✔ 5. Merkle Tree Microsecond Reconciliation matches identical state with 0 diff
  ✔ 6. Merkle Tree Reconciliation detects diverging records
  ✔ 7. Cryptographic Delivery Receipt verification validates recipient Ed25519 signature
  ✔ 8. Gateway Manager tracks online peers and dispatches messages
✔ NearLink Backend Modular Monolith Test Suite (330ms)
```
