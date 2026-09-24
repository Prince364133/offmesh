---
sidebar_position: 3
title: Account & Data Deletion
description: Instructions for deleting OffMesh cryptographic keys, local database, and server buffers.
---

# Account & Data Deletion Instructions

**Compliance Reference:** Google Play Store Account Deletion Policy  
**Application ID:** `net.offmesh.app`  
**Publisher:** Simplicion Private Limited  
**Direct Public Web URL:** [https://offmesh.simplicion.com/deletion](/deletion)

---

## 1. Decentralized Identity Model

OffMesh accounts are decentralized cryptographic keypairs (Ed25519 identity keys and Curve25519 encryption keys) generated on your physical smartphone. Because Simplicion Private Limited does not maintain centralized user databases, usernames, passwords, or phone registries, **deleting your account means permanently zeroizing your cryptographic keys and local data store**.

---

## 2. In-App Self-Service Wipe (Instant)

To delete all keys, local conversation history, and cached relay bundles immediately:

1. Open **OffMesh** on your Android smartphone.
2. Tap the **Settings** tab in the bottom navigation bar.
3. Select **Storage & Data**.
4. Scroll to the bottom and tap **Wipe All Keys & Local Data**.
5. Tap **Confirm Permanent Deletion** on the confirmation dialog.

### Immediate Effects of In-App Wipe:
* **Hardware KeyStore Purge:** Private signing and encryption keys are permanently erased from Android KeyStore hardware.
* **Database Zeroization:** All local SQLite tables, message history, and cached media are erased from flash memory.
* **Relay Cache Flushed:** All opportunistic bundles cached for mesh forwarding are purged.
* The app returns to its factory uninitialized state.

---

## 3. Server-Held Transient Packets Deletion

* **Automatic Expiry (TTL):** Any encrypted bundles temporarily waiting in the Cloud Gateway buffer expire automatically after their Time-To-Live (default 7 days) and are permanently purged by automated background workers.
* **Delivery Receipt Purge:** As soon as an anti-packet receipt is received, the server copy is deleted immediately.

---

## 4. Manual Deletion Requests via Support

Users may also request manual verification and immediate purge of any pending encrypted bundles matching their device fingerprint by emailing [simplicion.com@gmail.com](mailto:simplicion.com@gmail.com) with the subject line:  
`OffMesh Data Deletion Request - [Public Device Fingerprint]`. All requests are processed within 24 to 48 hours.
