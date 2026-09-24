---
sidebar_position: 2
title: Privacy Policy
description: Full text of the OffMesh Privacy Policy by Simplicion Private Limited.
---

# Privacy Policy

**Effective Date:** September 24, 2026  
**Developer / Publisher:** Simplicion Private Limited  
**Application Identifier:** `net.offmesh.app`  
**Direct Public Web URL:** [https://offmesh.simplicion.com/privacy](/privacy)

---

## 1. Zero Data Harvesting Principle

OffMesh is engineered as an offline-first, decentralized delay-tolerant messaging engine. **We do not collect, monetize, sell, or share personal user data.**

* **No Phone Numbers or Emails:** We do not require, collect, or store phone numbers, email addresses, real names, or user profiles.
* **No Address Book Access:** The application never reads, queries, or transmits your phone's address book or contacts.
* **No Location Tracking:** We do not collect, log, or transmit device GPS coordinates.
* **Zero Third-Party Trackers:** OffMesh contains **zero** advertising SDKs, behavioral analytics trackers, or telemetry libraries (no Firebase Analytics, Facebook SDK, or AppsFlyer).

---

## 2. Cryptographic Security & Local Processing

### 2.1 Hardware-Backed Key Storage
All cryptographic keypairs (Ed25519 for identity/signing, Curve25519 for ECDH encryption) are generated locally on the user's physical phone and secured inside the Android KeyStore (Trusted Execution Environment / Secure Element). Private keys never leave the device.

### 2.2 End-to-End Encryption (E2EE)
All messages are encrypted using **Curve25519 ECDH** and **ChaCha20-Poly1305 AEAD**. Only the intended recipient holding the matching private key can decrypt the message contents.

### 2.3 Store-and-Forward Relaying
Intermediate relay devices participating in opportunistic mesh networking carry only opaque, sealed binary envelopes. Relay devices cannot inspect, read, alter, or forge message content.

### 2.4 Cloud Gateway Buffer
When intermediate relays have internet access, they may deliver sealed packets to the Cloud Gateway buffer. Packets are stored temporarily with an automatic Time-To-Live (TTL, default 7 days) and are permanently purged upon verified delivery or expiry.

---

## 3. Android Runtime Permissions

| Permission | Technical Need | Data Stored Externally |
| :--- | :--- | :--- |
| `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` | Discovers nearby OffMesh peers and transmits encrypted binary packets. | None |
| `ACCESS_FINE_LOCATION`, `NEARBY_WIFI_DEVICES` | Mandatory Android OS requirement for scanning local BLE radio beacons. | None (GPS coordinates are never accessed or logged). |
| `POST_NOTIFICATIONS` | Alerts user of incoming peer messages. | None |
| `CAMERA` (Optional) | Scans a peer's physical QR contact card to import public keys. | None (Processed in volatile memory and discarded immediately). |

---

## 4. Contact & Inquiries

**Simplicion Private Limited**  
Address: Dpt 808b F-79&80 Dlf Prime Tower, Okhla Industrial Area Phase-i, New Delhi - 110020, India  
Email: [simplicion.com@gmail.com](mailto:simplicion.com@gmail.com)  
Website: [https://simplicion.com/](https://simplicion.com/)
