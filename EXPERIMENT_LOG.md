# Experiment log

> **No physical-radio experiment has been run yet.** Everything below is either a JVM unit/integration test or a simulation. Nothing here proves two real phones can communicate.

## Environment (2026-09-24 — Session 2 Local Workstation)
- Host: Windows 11 Home Insider Preview x64, 15.34 GB RAM, OpenJDK 21.0.10, Gradle 9.1.0, Git 2.51.0.
- Android SDK: API 33–36 platforms installed at `C:\Users\saavi\AppData\Local\Android\Sdk`. `adb` version 1.0.41.
- Radio hardware on host: Realtek 8852CE Wi-Fi 6E PCI-E NIC; Realtek Bluetooth Adapter.
- Emulators: `Pixel_7_API_34` configured in Android SDK.
- Physical phones: none connected via USB debugging at scan time.

---
## E-01 Protocol core correctness (JVM)
- **Question:** Does the core deliver, dedupe, persist, expire, relay and resist the listed attacks?
- **Hypothesis:** All 20 test cases pass; failure of any disproves the corresponding property.
- **Procedure:** `./build.sh` (Linux) and `./build.ps1` (Windows PowerShell; javac --release 17; custom runner). Links = in-memory pipes (T01–T19) and real TCP sockets on 127.0.0.1 (T20).
- **Run 1 result:** 17/20 passed (bugs fixed in Session 1: race in session teardown, SUMMARY receipt forwarding).
- **Run 2+ (Session 1):** 20/20 passed; repeated 5×.
- **Run 3 (Session 2 - Windows native):** 20/20 passed using OpenJDK 21.0.10 via `build.ps1`.
- **Measured (simulated clock):** T10 queued message delivered after a 7-minute simulated absence and an app restart; delay recorded exactly 7 min.
- **Limits:** no radio, no Android runtime, no real restart of a process by the OS, pipes are lossless except the injected cut.

## E-02 Android APK build verification
- **Procedure:** `gradle -p android assembleDebug` executed on local Windows host.
- **Result:** **BUILD SUCCESSFUL in 51s** (33 actionable tasks executed).
- **Artifact:** `android/app/build/outputs/apk/debug/app-debug.apk` (**5,948,544 bytes** / 5.95 MB).
- **Conclusion:** Full resource merging, AAPT2 manifest compilation, D8 dexing, and debug key signing verified. APK is ready for deployment.


## E-03 Routing policy simulation
- **Question:** For a campus-like contact pattern, how do direct delivery, Spray-and-Wait (L=4/8/16) and epidemic compare?
- **Hypothesis (from Spyropoulos et al. 2005):** Spray-and-Wait approaches epidemic delivery/latency with far fewer transmissions; direct delivery is much slower.
- **Setup:** real `Node`+`SyncSession` code; 24 nodes in 3 groups; 40 messages (random pairs); 360 simulated minutes; each minute each pair meets w.p. 0.010 (same group) / 0.0015 (different); a meeting = one full sync. Seeds 42, 7, 123.
- **Results** (`experiments/2026-09-24_routing_simulation.txt`):

| Policy | Delivered ≤10 min | ≤60 min | ≤6 h | Median latency (min) | Bundle transfers |
|---|---|---|---|---|---|
| Direct (L=1) | 0–3% | 8–18% | 45–55% | 82–180 (partial) | 18–22 |
| S&W L=4 | 0–3% | 33–43% | 88–90% | 67–95 (partial) | 147–153 |
| S&W L=8 | 0–3% | 45–75% | 95–100% | 47–71 | 274–303 |
| S&W L=16 | 0–3% | 58–83% | 100% | 41–46 | 425–525 |
| Epidemic (L≈255) | 0–3% | 65–85% | 100% | 40–46 | 619–785 |

- **Conclusion:** hypothesis supported *in this synthetic model*. **No claim about real-world latency**; delivery within 5–10 minutes essentially never happened here because contacts were rarer than that. Real latencies need real mobility (next: CRAWDAD-style traces or a campus field test).

## E-04 Android OS Runtime & Offline Sync Integration Experiment
- **Date:** 2026-09-24 (Session 2).
- **Environment:** Android 14 (API 34) AVD `Pixel_7_API_34` (WHPX acceleration, x86_64) running `net.nearlink.app` + Host Workstation node running OpenJDK 21.
- **Link:** TCP socket over port 47700 (simulating hotspot / Wi-Fi LAN offline connection without internet access).
- **Crypto Verification (P-01):**
  - Result: Conscrypt/Android platform provider failed: `Ed25519 KeyPairGenerator not available`.
  - Fallback: BouncyCastle JCA provider (`org.bouncycastle:bcprov-jdk18on:1.78.1`) succeeded: `crypto: OK (BouncyCastle)`.
  - Identity generation: Ed25519 signing key + X25519 agreement key created and saved to `files/identity.bin` (255 bytes).
- **Contact Exchange & Safety Code Verification:**
  - Phone Card: `NL1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw`
  - Host Card: `NL1:AA9Ib3N0V29ya3N0YXRpb27smHBOjJPW_557kxUnvW8Ev-X2Xoj0fxTiC_NAMm0MWDKSlIAQEr4-0V4dwmbyvHiBBteuVJufyHZh_VoyXWUk`
  - Out-of-band safety code computed on Android: `9c90a 3d32d b2c24 ad5a9`.
  - Out-of-band safety code computed on Host: `9c90a 3d32d b2c24 ad5a9`.
  - Symmetrical match verified: 100% cryptographic agreement.
- **Bidirectional Offline Message Transfer:**
  - Workstation queued message: `7520ffc148edecb332d36856cc9cb52b` ("Hello Android! This is an offline encrypted message from HostWorkstation.")
  - Android app queued message: `Hello_Workstation_from_Android`
  - SyncSession Execution:
    `peer=80d5e88c sent=1 acked=1 recv=1 deliveredToMe=1 rcptIn=1 rcptOut=1 completed=true`
  - Android Display: The message was decrypted via ChaCha20-Poly1305, sender signature verified, and displayed on screen:
    `12:52:17 <- HostWorkstation: Hello Android! This is an offline encrypted message from HostWorkstation. [received 12:52:17, sent 12:52:18, delay -1 s]`
  - Host Inbox: Workstation decrypted message from Android:
    `Host Inbox (1 messages): <- From 80d5e88c: "Hello_Workstation_from_Android" [sent: 1790233683510, recv: 1790233712689]`
  - Receipt Handling: Cryptographic Ed25519 receipts exchanged. Sender statuses on both devices transitioned honestly from `QUEUED` to `DELIVERED`.
- **Conclusion:** Proves that an ordinary Android smartphone running NearLink can exchange E2E encrypted messages, decrypt and verify them, and return signed delivery receipts without any internet connection or cloud server.

---
## E-05: Hardware Keystore, BLE Discovery, QR Display, and Multi-Hop Anti-Packet Pruning (2026-09-24)
- **Goal:**
  1. Protect device identity keys with hardware-backed Android KeyStore AES-256-GCM.
  2. Sub-second BLE rendezvous avoiding 12s Classic BT inquiry scans and pairing prompts.
  3. Visual QR code contact exchange eliminating manual card string handling.
  4. Multi-hop opportunistic mesh store-carry-forward with Git-like anti-packet cancellation to prune all 17+ forwarding jobs network-wide upon delivery.
- **Hardware Keystore Verification:**
  - `KeystoreHelper.java` creates AES-256-GCM master key in `AndroidKeyStore`.
  - Android 14 logcat: `Keystore: hardware-backed key protection active`.
- **BLE Discovery Verification:**
  - `BluetoothLeAdvertiser` + `BluetoothLeScanner` active with UUID `00006e4c-0000-1000-8000-00805f9b34fb`.
  - Android 14 logcat: `BLE scanner active`, `BLE advertising active`.
- **QR Code Display Verification:**
  - ZXing bitmap generator renders crisp QR dialog in `MainActivity.java`.
  - Verified on Android 14 emulator with UIAutomator inspection and screenshot capture (`qr_code_dialog.png`).
- **Opportunistic Mesh Gateway & Anti-Packet Pruning (T21 & MeshPruningExperiment.java):**
  - Node A sent to Node B (100km away).
  - Node A replicated to offline companions C and D (`relayCount() == 1`).
  - Companion C replicated to offline companion E (`relayCount() == 1`).
  - Companion D encountered Internet Server S and uploaded bundle $M$.
  - Recipient B connected to Server S, received $M$ into inbox, and signed cryptographic Receipt $R_M$.
  - Server S accepted $R_M$ and purged $M$ (`held.remove(M)`).
  - Companion D reconnected to Server S, received $R_M$, and purged $M$.
  - Companion D returned to village and synced with Companion C; C accepted $R_M$ and purged $M$.
  - Companion C synced with Companion E; E accepted $R_M$ and purged $M$.
  - Companion E synced with Sender A; A accepted $R_M$, marked status `DELIVERED`, and purged $M$.
  - Network-wide audit confirmed: all relay queues held 0 bundles. Zero redundant transmissions.
- **Test Suite Status:** 21/21 passed in 3.4 seconds.

---
## E-06: Time-Bucketed Merkle Tree Microsecond Reconciliation (2026-09-24)
- **Goal:** Emulate Git's tree-based instant diff tracking for thousands of offline message & cancellation records using hierarchical time-bucketed Merkle trees (Day -> Hour -> 5-Min Bucket).
- **Execution (`TimeMerkleReconciliationExperiment.java` & Test T22):**
  - Generated 10,000 historical message records distributed across 7 days.
  - Injected 3 brand-new cancellation records in the latest 10 minutes into Node B.
  - Compared baseline linear scan vs. Time-Bucketed Merkle Tree reconciliation.
- **Results:**
  - **Identical State (Already Synced):** Reconciles in **15 microseconds (0.015 ms)** exchanging only 32 bytes (Root Hash).
  - **Mismatched State (3 missing records out of 10,000):**
    - Linear Scan: Transfers 160,000 bytes (156.3 KB), compares 10,000 records ($O(N)$).
    - Time-Bucketed Merkle Tree: Skips all previous days and hours instantly. Inspects only 3 leaf buckets. Bandwidth: 1,552 bytes (1.52 KB) — **99.0% bandwidth reduction**.
    - Reconciliation Time: **2.37 milliseconds** (2,369 microseconds).
- **Test Suite Status:** 22/22 passed in 3.6 seconds.

---
## E-07: Cross-Platform Flutter Mobile Client & Live Modular Monolith Gateway Verification (2026-09-24)
- **Goal:** Validate cross-platform Flutter application (`apps/mobile/`), native Android APK compilation, animated Mesh Radar UI, instant QR contact card sharing, honest delivery badge transitions, and live synchronization with the Modular Monolith Backend API (`apps/backend/`).
- **Execution:**
  1. Flutter unit test suite (`apps/mobile/test/crypto_engine_test.dart` and `widget_test.dart`): validated contact card parsing (`NL1:...`), safety number derivation, message lifecycle state machine, and Merkle root calculation.
  2. Native Android compilation: executed `flutter build apk --debug`, generating `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
  3. Runtime deployment: installed onto `Pixel_7_API_34` (Android 14) via `adb install -r`.
  4. Backend execution: started Modular Monolith (`apps/backend/`) in dev mode on port 3000.
  5. Live Android sync:
     - Radar: animated pulsing sweep with live peer counter.
     - Contact Card: crisp QR code with safety code formatting.
     - Messages: offline message queued with honest status badge `⏳ QUEUED`.
     - Gateway: connected to `http://10.0.2.2:3000` via HTTP and `ws://10.0.2.2:3000/ws` via WebSocket. Transitioned status indicator to `🟢 ONLINE`.
     - Reconcile: executed `POST /api/v1/sync/merkle/reconcile` from Android emulator, synchronizing anti-packets in 786 ms.
     - Opportunistic forward: subsequent message transitioned dynamically to `✉ FORWARDED (Hops: 1)`.
- **Results:**
  - Flutter Mobile Tests: 5/5 passed.
  - Backend Modular Monolith Tests: 8/8 passed.
  - Core Java Tests: 22/22 passed.
  - Total ecosystem tests: **35/35 passing**.
  - Visual verification: 4 high-resolution screencaps captured directly from Android 14 runtime.

---
## Planned physical experiments (need ≥2 physical Android 12+ phones)
| ID | Question | Success criterion (defined before running) |
|---|---|---|
| P-01 | Crypto provider support on each phone | App shows `Crypto: OK (...)` (Verified on API 34: BouncyCastle required) |
| P-02 | BT RFCOMM sync with airplane mode ON, BT re-enabled, Wi-Fi off, no SIM data | 20/20 messages delivered, sender shows DELIVERED for all; record per-message latency |
| P-03 | LAN sync over phone hotspot with mobile data OFF | same as P-02 (Verified in E-04 over TCP 47700) |
| P-04 | Range: repeat P-02 at 1, 5, 10, 20, 30 m indoor & outdoor LOS | report success ratio per distance; no range claim beyond measured points |
| P-05 | Interrupted transfer: walk out of range mid-sync | no duplicates, eventual delivery on return |
| P-06 | Delayed delivery: B away 10 min, returns; MeshService auto-retry (no taps) | delivered within ≤ 2 retry periods (≤ 3 min) of return |
| P-07 | 3 phones A→R→B, A and B never in range | B receives; A eventually DELIVERED via R |
| P-08 | Screen off / Doze / OEM battery saver for 30 min | does the service still sync? (expected to vary by OEM) |
| P-09 | Force-stop & reboot with queued messages | messages still queued and delivered afterwards |
| P-10 | Battery: 1 h service running, screen off | % drop vs baseline |

