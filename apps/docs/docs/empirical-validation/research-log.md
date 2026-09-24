---
sidebar_position: 3
title: Research Log & Literature Review
description: Initial research questions, hardware constraints, findings from existing decentralized protocols, and open research directions.
---

# Research Log & Literature Review

---

## Research Questions & Findings

### RQ1. Which smartphone radios can exchange data with zero internet?
- **Finding:** Bluetooth Classic RFCOMM, Bluetooth Low Energy (BLE), Wi-Fi Direct (P2P), Wi-Fi Aware (NAN), and local phone hotspot networks all operate without cellular data or an internet connection. Cellular basebands and GNSS receivers cannot be repurposed for peer-to-peer ad-hoc data. Radio reach is physically local (10–50 meters); wider reach occurs exclusively when moving people carry packets.

### RQ2. Can smartphones form an autonomous Bluetooth Mesh?
- **Finding:** Standard SIG Bluetooth Mesh on Android and iOS treats smartphones as provisioners and proxy clients via GATT, not as autonomous relay nodes. Relying on SIG Bluetooth Mesh is rejected. Multi-hop routing must be executed at the application layer.

### RQ3. Lessons from prior peer-to-peer implementations
- **Briar:** Uses Bluetooth Classic, Wi-Fi, and removable SD cards offline; Tor when online. Direct delivery between contacts without stranger relaying. GPLv3 licensed.
- **Bridgefy:** Propagated BLE mesh broadcasts, but suffered repeated critical protocol vulnerabilities (USENIX Security 2022) due to unauthenticated metadata and improper key bindings. Lesson: adopting modern cryptography libraries is not enough; the protocol framing itself must strictly bind recipient identities and message identifiers to signatures.
- **Serval Project:** Relied on ad-hoc Wi-Fi modes requiring rooted Android devices, making it unusable on commercial consumer smartphones.

### RQ4. How should messages propagate across intermittent encounters?
- **Finding:** Delay-Tolerant Networking (DTN) literature demonstrates that epidemic flooding causes severe battery and storage exhaustion. Binary Spray-and-Wait (Spyropoulos et al. 2005) bounds maximum copies to $L=8$, providing 95–100% delivery ratios while cutting transmissions by 60%.

### RQ5. Background execution constraints in modern mobile operating systems
- **Finding:** Modern Android (Android 12–15) strictly enforces foreground service types (`connectedDevice`). Unrestricted background Bluetooth inquiry scans are heavily throttled. BLE advertising with rotating service tokens is mandatory for rapid sub-second peer rendezvous.

---

## Open Research Directions

1. **Physical Field Mobility Latency:** Evaluating real-world delivery latency distributions using real pedestrian traces on university campuses.
2. **Aggressive OEM Battery Task Killers:** Evaluating long-term background synchronization survival across Xiaomi (MIUI/HyperOS), Samsung (OneUI), and BBK (ColorOS) battery policies.
3. **Ratchet Sessions for Long-Term Contacts:** Upgrading from one-shot ephemeral-static X25519 to an offline-compatible Double Ratchet once initial contact is confirmed.
