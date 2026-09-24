---
sidebar_position: 5
title: Physical Radio Feasibility Matrix
description: Rigorous breakdown of what commercial Android and iOS smartphones can physically do offline across conditions A through E.
---

# Physical Radio Feasibility Matrix

What commercial smartphones can and cannot physically achieve offline without cellular infrastructure or internet access.

---

## 1. Operating Conditions

| Condition | Physical Environment | Achievable Data Path | Verdict |
| :--- | :--- | :--- | :--- |
| **Condition A** | No Internet, Radios Powered On | Direct peer-to-peer radio links (BLE, Wi-Fi Direct, Classic BT) within tens of meters. | **Feasible** — Core prototype baseline. |
| **Condition B** | No Internet, No Cellular Signal | Identical to Condition A; cellular modem status does not affect Wi-Fi/BT transceivers. | **Feasible** — Cellular towers are not required. |
| **Condition C** | Intermittent Encounters (No Static Link) | Store-carry-forward (DTN) routing carried by moving human carriers. | **Feasible** — Latency is governed by human mobility. |
| **Condition D** | No Nearby Compatible Devices | No physical transmission channel exists. Message remains safely queued locally. | **Direct Delivery Impossible** — UI must display `QUEUED`. |
| **Condition E** | Long Distance, Zero Infrastructure, Zero Extra Hardware | Commercial phone radios reach 10–50 meters. | **Direct Link Impossible** — Requires store-carry-forward relay chains or dedicated radio accessories (e.g. LoRa/Meshtastic). |

---

## 2. Comprehensive Technology Feasibility Matrix

| Technology | Internet? | Extra Hardware? | Direct Link? | Multi-Hop? | Range | Throughput | Android Platform Support | Background Reliability | Security Layer |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BLE (GATT / Advertisements)** | No | No | Yes | App-Level | 10–30 m | Low–Med | API 21+; ubiquitous | Background scans throttled by OS | End-to-end payload AEAD |
| **Bluetooth Classic RFCOMM** | No | No | Yes | App-Level | ~10 m | 1–2 Mbps | API 5+; AOSP standard | Supported via `connectedDevice` FGS | End-to-end payload AEAD |
| **Wi-Fi Direct (P2P)** | No | No | Yes | App-Level | 30–80 m | High (>10 Mbps) | API 14+; connection prompts | OS prompt on first link | End-to-end payload AEAD |
| **Wi-Fi Aware (NAN)** | No | No | Yes | App-Level | 30–80 m | High (>10 Mbps) | API 26+; requires `FEATURE_WIFI_AWARE` | Device-specific power limits | End-to-end payload AEAD |
| **Local Hotspot / LAN TCP** | No | No | Via Hotspot | App-Level | 20–50 m | High | Standard BSD sockets | High while hotspot active | End-to-end payload AEAD |
| **Google Nearby Connections** | No | No | Yes | App-Level | 10–50 m | High | Requires Google Play Services | OS prompt; restricted background | Play Services internal encryption |
| **SIG Bluetooth Mesh** | No | Mesh Nodes | No | Managed Flooding | Short | &lt;1 kbps | Smartphone is only a provisioner / client | Poor for peer messaging | Network & App keys |
| **Acoustic Data-over-Sound** | No | No | Yes | No | 1–3 m | 8–16 bytes/s | Standard audio recording permission | Foreground only | None built-in |
| **Optical Screen-to-Camera QR** | No | No | Yes | By Hand | &lt;1 m | ~1 KB / frame | Standard camera permission | Foreground only | Visual channel (MITM-resistant) |
| **NFC** | No | No | Yes | No | ~4 cm | Low | Android Beam deprecated in API 29 | Foreground only | None built-in |
| **Carrier Satellite (NTN)** | No | Carrier Contract | Via Orbit | No | Global | &lt;100 bps | Android 15+ restricted to carrier apps | Carrier restricted | Carrier-managed |
| **LoRa (Meshtastic)** | No | External Radio | Yes | RF Mesh | 1–15 km | Low (&lt;5 kbps) | Connects via BLE to phone accessory | Background accessory service | Channel AES PSK |

---

## 3. Engineering Conclusions

1. **The Feasible Real-World Solution:** A localized, delay-tolerant network built from peer-to-peer smartphone radios (BLE + Wi-Fi Direct + Hotspot TCP). Direct radio links cover tens of meters; physical store-carry-forward extends delivery distance to everywhere people move.
2. **The "Airplane Mode" Reality:** If all radios (Bluetooth and Wi-Fi) are powered down at the OS level, radio transmission is physically impossible. Operating systems completely cut power to baseband transceivers. The app must guide users to re-enable Bluetooth in low-power mode.
3. **Delivery Guarantees:** Delivery cannot be guaranteed if no communication path ever forms. Honest state reporting (`QUEUED`, `FORWARDED`, `DELIVERED`, `EXPIRED`) is a mandatory safety requirement.
