# Status — 2026-09-24 (end of session 1)

**Stage:** 1 complete; 2–5 implemented in code and verified in JVM tests/simulation; **0 physical-device experiments.**

## Demonstrated (with evidence)
- Protocol core: E2E encryption + signatures, persistent queue across restarts, dedupe, replay rejection, expiry, signed delivery receipts, honest statuses, interruption-safe transfer, 2-hop relay, storage/flood limits, parser fuzzing — **20/20 tests pass**, repeated 5× (JVM only).
- Sync over real TCP sockets on loopback (not radio).
- Routing simulation: Spray-and-Wait L=8 ≈ epidemic delivery with ~40% of its transfers (synthetic contacts).
- Android sources type-check against the API-35 SDK stub with 0 errors.

## Not demonstrated
- Any communication between physical phones. Any range. Any real latency. APK build. Background behaviour. Battery use. Crypto provider support on real devices.

## Failed / rejected approaches
- Building the APK in the cloud container: Google Maven / Maven Central / dl.google.com blocked.
- SIG Bluetooth Mesh, GNSS, arbitrary-frequency transmission, NFC — rejected with evidence (FEASIBILITY.md).

## Milestones vs brief §17
| # | Criterion | State |
|---|---|---|
| 1 | Two Android devices exchange a message offline | **untested** (code ready) |
| 2 | Receiver displays correct message | JVM ✔, device untested |
| 3 | Sender gets ack when delivery confirmed | JVM ✔ |
| 4 | Survives app restart | JVM ✔ (file store) |
| 5 | Queued message delivered when recipient returns | JVM ✔ |
| 6 | Duplicates handled per protocol | JVM ✔ |
| 7 | Honest failure reporting | JVM ✔ (EXPIRED / NOT confirmed) |
| 8 | Rebuildable from documented source | core ✔ (`./build.sh`); Android needs Android Studio on your PC |
