---
sidebar_position: 4
title: Google Play Data Safety
description: Official Google Play Console Data Safety questionnaire mapping for OffMesh.
---

# Google Play Data Safety Specification

**Target Platform:** Google Play Console Data Safety Form  
**Application ID:** `net.offmesh.app`  
**Publisher:** Simplicion Private Limited  
**Direct Public Web URL:** [https://offmesh.simplicion.com/data-safety](/data-safety)

---

## Google Play Questionnaire Mapping

| Questionnaire Item | Response | Notes |
| :--- | :--- | :--- |
| **Data Collection** | **No data collected** | OffMesh does not collect, log, or transmit personal user data or telemetry. |
| **Data Sharing** | **No data shared** | Zero data shared with third parties, advertisers, or analytics networks. |
| **Encryption in Transit** | **Yes** | All peer-to-peer and client-to-gateway transit is encrypted (Curve25519, ChaCha20-Poly1305, TLS 1.3). |
| **Account Deletion** | **Yes** | Self-service key wipe available in Settings &gt; Storage &amp; Data. |
| **Target Audience** | **General Audiences** | App does not target children under 13. |

---

## Granular Data Type Declarations

* **Location:** Not collected. `ACCESS_FINE_LOCATION` requested solely due to Android BLE beacon scanning requirements; GPS coordinates are never accessed.
* **Personal Info:** Not collected. No names, phone numbers, or email addresses required or stored.
* **Financial Info:** Not collected. Completely free application.
* **Messages:** Not collected. End-to-end encrypted; server holds only blind, opaque ciphertext with 7-day TTL.
* **Photos & Videos:** Not collected. Encrypted locally; no cloud photo hosting.
* **Contacts:** Not collected. Zero address book permissions.
* **Device Identifiers:** Not collected. Ephemeral Ed25519 keys only.
