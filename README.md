# NearLink — offline phone-to-phone messaging (research prototype)

Delay-tolerant, end-to-end-encrypted text messaging between ordinary Android phones **with no internet, no cellular service and no server**, over Bluetooth or a local Wi-Fi hotspot. Messages that can't be delivered now wait on the phone (or on participating phones that carry them) until a contact happens, then are delivered and confirmed with a signed receipt.

**What it is not:** a long-range or worldwide network. Range is local radio range; beyond that, messages move only as fast as people carrying phones. See FEASIBILITY.md.

## Current capabilities (see STATUS.md for evidence)
- ✔ Tested on JVM: encryption/signatures, queue that survives restarts, dedupe/replay protection, expiry, 2-hop relaying (Spray-and-Wait), signed delivery receipts, honest statuses, flood/storage limits.
- ✔ Tested: sync over TCP loopback.
- ✘ Not yet tested on real phones. No APK has been built yet.

## Layout
```
core/src       transport-independent engine (pure Java 17, no dependencies)
core/test      test suite (Tests.java) and routing simulator (Simulator.java)
android/       Android app (Bluetooth RFCOMM + hotspot TCP), compiles core/src in
experiments/   raw outputs of every run
*.md           research notes (FEASIBILITY, ARCHITECTURE, SECURITY, EXPERIMENT_LOG, ...)
```

## Build & test the core (any OS with JDK 17+)
```
./build.sh                                   # compiles + runs 20 tests
java -cp build/core:build/test net.nearlink.core.Simulator 42    # routing simulation
```

## Build the Android app
1. Install Android Studio (recent, with SDK 35). Open the `android/` folder; let it sync (downloads Android Gradle Plugin 8.5.x and BouncyCastle). If asked, let it create the Gradle wrapper.
2. Run on two Android 12+ phones (USB debugging), or *Build > Build APK(s)* and install the APK on both.

## Reproduce the offline test (P-02)
On **both** phones: remove/disable SIM data, turn **Airplane mode ON**, then turn **Bluetooth ON** again (Wi-Fi stays off).
1. Open NearLink on both → grant Nearby devices + Notifications → check the status line says `Crypto: OK`.
2. Tap **Start service** on both.
3. Exchange contacts: on phone A tap *Copy my card*, get it to phone B (for now: read it off the screen/QR app or share before going offline) and *Add contact*; repeat B→A. Compare the **safety code** shown in the event log on both phones.
4. Phone B: tap **Discoverable**. Phone A: **Scan BT**, then tap phone B in the list (first sync; afterwards the service retries automatically every 90 s).
5. Send a message on A. Status should go *Queued* → *Delivered*. B shows the text, send time, receive time and delay.
6. Delayed delivery: walk B out of range, send from A, return after 10 min, don't touch anything; note when it arrives.

Hotspot variant (P-03): A turns on its hotspot with mobile data OFF; B joins it; B enters A's IP (shown in A's status line, usually `192.168.x.1` on `ap0/wlan`) and taps *Sync over Wi-Fi/hotspot*.

Please record results in EXPERIMENT_LOG.md (models, Android versions, distance, indoor/outdoor, messages sent/received, latencies).
