# Experiment log

> **No physical-radio experiment has been run yet.** Everything below is either a JVM unit/integration test or a simulation. Nothing here proves two real phones can communicate.

## Environment (2026-09-24)
- Build/test host: cloud Linux container, Ubuntu 24.04.4, x86_64, 2 vCPU, 7.8 GiB RAM, OpenJDK 21.0.10, Gradle 8.14.3, no Bluetooth/Wi-Fi hardware, no Android SDK. Google Maven, Maven Central and dl.google.com are **blocked** by egress policy → no APK can be built here.
- `android.jar` stubs (API 33/34/35) obtained from GitHub (Sable/android-platforms) for **type-checking only**.
- User's linked PC "prince-gupta": Windows x64; home contains `.android`, `.gradle`, `flutter_sdk` (suggests Android tooling). **No folder connected; no phones detected** — not inspected.

---
## E-01 Protocol core correctness (JVM)
- **Question:** Does the core deliver, dedupe, persist, expire, relay and resist the listed attacks?
- **Hypothesis:** All 20 test cases pass; failure of any disproves the corresponding property.
- **Procedure:** `./build.sh` (javac --release 17; custom runner). Links = in-memory pipes (T01–T19) and real TCP sockets on 127.0.0.1 (T20).
- **Run 1 result:** 17/20 passed. Two real bugs found:
  1. T07/T20 — race: session stopped waiting when the peer disconnected in the same 50 ms window as the final ACK → reported "incomplete" although the message was delivered. Fix: re-check completion after reader exit.
  2. T11 — receipts not forwarded back to the original sender because the SUMMARY merged "seen" and "have receipt". Fix: SUMMARY carries two lists.
- **Run 2+:** 20/20 passed; repeated 5× → 20/20 each time (no flakiness observed). Output: `experiments/2026-09-24_core_tests.txt`.
- **Measured (simulated clock):** T10 queued message delivered after a 7-minute simulated absence and an app restart; delay recorded exactly 7 min (clock is simulated — this validates bookkeeping, not radio latency).
- **Limits:** no radio, no Android runtime, no real restart of a process by the OS, pipes are lossless except the injected cut.

## E-02 Android code type-check
- `javac` of `android/app/src/main/java` + `core/src` against API-35 `android.jar`: **compiles with 0 errors.**
- **Not verified:** resource/manifest processing (aapt2), dexing (D8), API-level lint vs minSdk 31, runtime behaviour. **No APK exists.**

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

---
## Planned physical experiments (need ≥2 Android 12+ phones)
| ID | Question | Success criterion (defined before running) |
|---|---|---|
| P-01 | Crypto provider support on each phone | App shows `Crypto: OK (...)` |
| P-02 | BT RFCOMM sync with airplane mode ON, BT re-enabled, Wi-Fi off, no SIM data | 20/20 messages delivered, sender shows DELIVERED for all; record per-message latency |
| P-03 | LAN sync over phone hotspot with mobile data OFF | same as P-02 |
| P-04 | Range: repeat P-02 at 1, 5, 10, 20, 30 m indoor & outdoor LOS | report success ratio per distance; no range claim beyond measured points |
| P-05 | Interrupted transfer: walk out of range mid-sync | no duplicates, eventual delivery on return |
| P-06 | Delayed delivery: B away 10 min, returns; MeshService auto-retry (no taps) | delivered within ≤ 2 retry periods (≤ 3 min) of return |
| P-07 | 3 phones A→R→B, A and B never in range | B receives; A eventually DELIVERED via R |
| P-08 | Screen off / Doze / OEM battery saver for 30 min | does the service still sync? (expected to vary by OEM) |
| P-09 | Force-stop & reboot with queued messages | messages still queued and delivered afterwards |
| P-10 | Battery: 1 h service running, screen off | % drop vs baseline |
