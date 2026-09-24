---
sidebar_position: 4
title: Bibliography & Standards
description: Official specifications, RFCs, peer-reviewed academic literature, and open-source project references.
---

# Bibliography & Standards

---

## 1. Official Documentation & Specifications

1. **Android Developers** — *Bluetooth permissions guide*.  
   `https://developer.android.com/develop/connectivity/bluetooth/bt-permissions`  
   Details Android 12+ permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`) and Android 11 requirements.
2. **Android Developers** — *Wi-Fi Aware (NAN) overview*.  
   `https://developer.android.com/develop/connectivity/wifi/wifi-aware`  
   Details infrastructure-free peer connectivity without an access point.
3. **Android Developers** — *Foreground service types and policies*.  
   `https://developer.android.com/develop/background-work/services/fgs/service-types`  
   Details `connectedDevice` constraints and Android 15 boot receiver restrictions.
4. **Google Developers** — *Nearby Connections API overview*.  
   `https://developers.google.com/nearby/connections/overview`  
   Details peer rendezvous and 2026 radio activation policy changes.
5. **IETF RFC 9171** — *Bundle Protocol Version 7*, Burleigh, Fall, Birrane, Jan 2022.  
   Foundational concepts for store-carry-forward delay-tolerant network payloads, creation timestamps, and lifetimes.
6. **IETF RFC 5869** — *HMAC-based Extract-and-Expand Key Derivation Function (HKDF)*, Krawczyk & Eronen, 2010.  
   Used for symmetric key derivation from Diffie-Hellman secrets.
7. **IETF RFC 7748 (X25519), RFC 8032 (Ed25519), RFC 8439 (ChaCha20-Poly1305)** —  
   Modern, constant-time cryptographic primitives providing authentication and authenticated encryption.

---

## 2. Peer-Reviewed Academic Papers

8. **Spyropoulos, Psounis, Raghavendra** — *Spray and Wait: An Efficient Routing Scheme for Intermittently Connected Mobile Networks*, ACM SIGCOMM WDTN, 2005.  
   `https://dl.acm.org/doi/10.1145/1080139.1080143`  
   Theoretical foundation for NearLink's binary bundle replication algorithm.
9. **Vahdat & Becker** — *Epidemic Routing for Partially-Connected Ad Hoc Networks*, Duke University Technical Report CS-2000-06, 2000.  
   Theoretical basis for summary vectors and anti-entropy synchronization sessions.
10. **Albrecht, Eikenberg, Paterson** — *Breaking Bridgefy, Again: Adopting libsignal is Not Enough*, USENIX Security Symposium, 2022.  
    Critical analysis of practical vulnerabilities in commercial ad-hoc mesh messaging protocols.

---

## 3. Related Decentralized Projects

11. **Briar Project** — *How Briar Works*.  
    `https://briarproject.org/how-it-works/`  
    Peer-to-peer messaging using Bluetooth Classic, local Wi-Fi, and Tor.
12. **The Serval Project** — *Batphone & Rhizome Store-and-Forward Architecture*.  
    `https://github.com/servalproject/batphone`  
    Early exploration of ad-hoc mesh communication.
13. **Nordic Semiconductor** — *Android-nRF-Mesh-Library*.  
    Demonstration of smartphone Bluetooth Mesh limitations (provisioner/client only).
