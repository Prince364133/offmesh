---
sidebar_position: 1
title: High-Level Design (HLD)
---

# High-Level Design (HLD)

NearLink is structured around an opportunistic, store-carry-forward delay-tolerant network (DTN) architecture coupled with a high-throughput Cloud Gateway.

---

## 1. System Context & Architecture Diagram

```mermaid
graph TD
    subgraph Offline Mesh Layer (Physical Realm)
        UserA["Smartphone A (Sender)"]
        CarrierC["Carrier Smartphone C"]
        CarrierD["Carrier Smartphone D"]
        CarrierE["Carrier Smartphone E"]
        UserB_Offline["Smartphone B (Recipient)"]

        UserA -->|"BLE / Wi-Fi Hotspot"| CarrierC
        UserA -->|"BLE / Wi-Fi Hotspot"| CarrierD
        CarrierC -->|"Ad-hoc Sync"| CarrierE
        CarrierE -.->|"P2P Encounter"| UserB_Offline
    end

    subgraph Transit & Gateway Layer
        CarrierD -.->|"Travels to Internet Area"| Gateway["Gateway Radio / Cellular Tower"]
    end

    subgraph NearLink Backend Cloud Layer
        Gateway -->|"HTTPS REST (NLB1)"| FastifyServer["Modular Monolith Backend API (Fastify 5)"]
        FastifyServer -->|"Redis Cache & Queue"| Redis7["Redis 7 (Dedupe & PubSub)"]
        FastifyServer -->|"System of Record"| Postgres16["PostgreSQL 16 (Drizzle ORM)"]
        FastifyServer -->|"Async Workers"| BullMQ["BullMQ (Router / Merkle / Sweeper)"]
        FastifyServer -->|"WebSocket WSS"| ConnectedPeers["Online Mobile Clients"]
    end

    subgraph Anti-Packet Cancellation Flow
        ConnectedPeers -->|"Receipt R_M"| FastifyServer
        FastifyServer -->|"Purge Bundle M"| Postgres16
        FastifyServer -->|"Broadcast Anti-Packet"| CarrierD
        CarrierD -.->|"Returns to Offline Village"| CarrierC
        CarrierC -->|"Purge M"| CarrierE
        CarrierE -->|"Receipt Verified"| UserA
    end
```

---

## 2. Key Components & Responsibilities

### 2.1 The Mobile Node (`apps/mobile`)
Each mobile client acts simultaneously as:
* **Terminal:** A private endpoint for composing, signing, encrypting, and reading personal messages.
* **Courier / Carrier:** An opportunistic store-carry-forward transit router that holds encrypted bundles in isolated storage and replicates them to passing devices without access to their contents.
* **Radar Sensor:** Uses BLE advertising and scanning (`flutter_blue_plus`) with Service UUID `00006e4c-0000-1000-8000-00805f9b34fb` to discover nearby nodes in under 800 milliseconds.

### 2.2 The Modular Monolith Backend API (`apps/backend`)
Engineered in Node.js 24 and Fastify 5 with strict TypeScript:
* **Identity Module:** Manages Ed25519 challenge-response authentication nonces and indexes contact cards (`NL1:...`).
* **Bundle Routing Module:** Decodes `NLB1` binary wire frames, performs $O(1)$ duplicate bundle rejection via Redis, and queues bundles for destination nodes.
* **Anti-Packet Receipt Module:** Ingests cryptographically signed delivery receipts ($R_M$) from recipients, atomically transitions statuses to `DELIVERED`, and broadcasts anti-packet purge instructions across connected carriers.
* **Time-Bucketed Merkle Sync Module:** Computes hierarchical Merkle trees over 5-minute, hourly, and daily buckets to facilitate microsecond diff tracking.
* **WebSocket Gateway:** Maintains real-time presence of online mobile nodes and pushes pending bundles and anti-packet purges with zero polling delay.

---

## 3. The Anti-Packet Delivery Paradigm

In conventional delay-tolerant networks (like epidemic routing), bundles flood through the network until an expiration timer runs out, causing severe memory exhaustion and redundant battery drain.

NearLink introduces **Cryptographic Anti-Packets (R_M)**:
1. When Recipient B receives bundle M, it verifies sender authenticity and signs receipt:
   ```text
   R_M = Sign(B_priv, "NL-receipt" || bundleId || timestamp)
   ```
2. R_M is transferred to any encountered carrier node or uploaded to the cloud gateway.
3. Every carrier holding bundle M that verifies R_M immediately executes:
   ```text
   queue.remove(M)
   ```
4. The anti-packet cancels all outstanding transit copies, terminating multi-hop propagation across the entire mesh.

