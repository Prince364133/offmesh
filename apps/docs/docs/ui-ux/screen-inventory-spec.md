---
sidebar_position: 6
title: Screen Inventory & Interactions
description: Exhaustive screen-by-screen inventory, interaction flows, and edge cases across onboarding, chats, discovery, and sync.
---

# OffMesh — Screen Inventory & Interaction Specification

**Document type:** Screen inventory, layout, and interaction specification  
**Version:** 1.0  
**Platform:** Android-first mobile application; adapted to iOS conventions where supported  
**Visual direction:** Monochrome Minimal theme  
**Scope:** Main user journeys and offline messaging edge cases  

---

## 1. Product Summary

OffMesh is an offline-first messaging application. Nearby devices discover and connect through supported local communication technologies (BLE, Wi-Fi Direct). Eligible encrypted message packets can be carried by relays and uploaded by a relay with internet access. The server stores messages until the intended recipient can receive them.

The interface distinguishes:
1. **Local storage** (Queued on sender device)
2. **Relay acceptance** (Carried in transit by nearby mesh node)
3. **Server storage** (Buffered in cloud queue)
4. **Confirmed recipient delivery** (Cryptographic Ed25519 receipt verified)

---

## 2. Navigation Model

Four core bottom navigation tabs:
- **Chats** — Conversation list, search, and message threads
- **People** — Verified contacts, pending exchanges, QR safety codes
- **Nearby** — Real-time peer radar, direct connection, and manual sync triggers
- **Settings** — Relay preferences, encryption keys, storage management, and diagnostics

---

## 3. Screen Inventory

### A. Onboarding & Account

#### A1. Welcome
- **Purpose:** Introduce OffMesh and set expectations.
- **Elements:** OffMesh mark, concise value proposition ("Stay connected, even when the internet isn't available"), primary "Get started" button, secondary "I already have an account" action.
- **Behavior:** Clearly explains that delivery depends on a viable mesh path or relay and cannot be guaranteed when no route exists.

#### A2. Permissions
- **Purpose:** Contextually request hardware capabilities.
- **Elements:** Bluetooth / Nearby Devices, Wi-Fi Direct, Notifications, Optional Coarse Location.
- **Behavior:** Never imply that the app can silently enable hardware radios without OS approval. Includes clear "Not now" options for optional features.

#### A3. Create Profile
- **Purpose:** Generate local cryptographic identity.
- **Elements:** Optional avatar, display name, handle, generated device public key fingerprint, "Continue" CTA.
- **Behavior:** Generates an Ed25519 signing pair and X25519 key-exchange pair into secure hardware storage (Android Keystore / iOS Keychain). Private keys are never exposed in the UI.

#### A4. Contact Card / QR Code
- **Purpose:** Exchange out-of-band verified contact details.
- **Elements:** User QR code (embedding Ed25519 + X25519 public keys), display name, 6-digit numeric safety code, "Share" and "Scan QR" buttons.
- **Behavior:** Prompts users to compare safety codes in person to eliminate Man-In-The-Middle (MITM) risks.

---

### B. Chats & Messaging

#### B1. Chats List
- **Purpose:** Display conversations and delivery status summaries.
- **Elements:** Search bar, conversation rows, unread badge, timestamp, preview snippet, delivery state icons.
- **Empty state:** Guides user to add a contact or launch Nearby Radar.

#### B2. Chat — Connected Recipient
- **Purpose:** Direct peer-to-peer or server-bridged conversation.
- **Elements:** Recipient header, live link status, message bubbles with timestamps and honest status indicators, composer field, attachment actions.
- **Behavior:** Immediately persists outgoing messages into SQLite locally before attempting wire transfer.

#### B3. Chat — Recipient Offline
- **Purpose:** Transparent delayed delivery management.
- **Elements:** Availability banner, queued message bubble with "Waiting for a connection" badge, message details sheet trigger.
- **Behavior:** Preserves packets in the local DTN queue. Retries opportunistically whenever a mesh peer or server gateway appears.

#### B4. Message Actions
- **Purpose:** Contextual actions on a selected message.
- **Elements:** Reply, Copy Text, View Details, Cancel Forwarding, Delete Locally.
- **Behavior:** Strictly separates "Delete from my device" from cryptographic "Cancel Forwarding" (which broadcasts an authenticated anti-packet).

#### B5. Message Details & Delivery Diagnostics
- **Purpose:** Inspect end-to-end cryptographic and routing diagnostics.
- **Elements:** Hex Message ID (copyable), recipient public key fingerprint, creation timestamp, server ingestion timestamp (if applicable), recipient receipt signature, hop count, and event audit log.

---

### C. Nearby Discovery & Relay

#### C1. Nearby Devices & Radar
- **Purpose:** Visualize discoverable peers in physical proximity.
- **Elements:** Radar range rings (Immediate &lt;2m, Near &lt;10m, Far &lt;30m), rotating radar beam, peer nodes with RSSI signal bars, "Pause Scanning" toggle.
- **Behavior:** Distinguishes unverified detected peers from trusted contacts. Unknown peers are never automatically added to contacts.

#### C2. Sync Progress Modal
- **Purpose:** Explain microsecond Merkle synchronization stages.
- **Stages:**
  1. Handshake & Mutual Authentication
  2. Merkle Root Hash Exchange
  3. Difference Branch Traversal
  4. Anti-Packet & Cancellation Ingestion
  5. Payload Transit
  6. Cryptographic Receipt Verification
- **Behavior:** Fully idempotent. Resumes safely if connection drops mid-transfer without duplicating messages.

#### C3. Relay Preferences
- **Purpose:** Let users manage mesh participation.
- **Elements:** Relay participation toggle, max storage allocation (e.g. 50 MB), battery conservation (disable below 20%), Wi-Fi-only uplink toggle.
- **Behavior:** Fully opt-in. Preserves user bandwidth and battery.

---

### D. Settings & Diagnostics

#### D1. Settings Overview
- **Sections:** Account & Keys, Privacy & Security, Mesh & Connectivity, Storage & Data, Gateway Server Sync, About OffMesh.

#### D2. Gateway Server Sync
- **Elements:** Server URL, connection status, last sync timestamp, pending upload queue count, "Sync Now" manual trigger, debug logs.

---

## 4. Error and Empty-State Microcopy

- **Bluetooth Unavailable:** *"Nearby discovery isn't available right now. Check device settings and permissions."*
- **Peer Left Range:** *"The other device is no longer nearby. Your saved progress is safe."*
- **No Internet:** *"No internet connection. Messages remain queued while OffMesh searches for nearby mesh routes."*
- **Server Offline:** *"Couldn't sync with the gateway server. We'll automatically retry when connected."*
- **Queue Full:** *"Storage limit reached. Clear completed message cache in Settings to accept new packets."*
