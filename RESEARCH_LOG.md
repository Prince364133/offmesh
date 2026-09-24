# Research log

## Session 1 — 2026-09-24

### RQ1. Which phone radios can exchange data with no internet?
Bluetooth Classic/BLE, Wi-Fi Direct, Wi-Fi Aware and hotspot-LAN all work without internet or cellular (Wi-Fi Aware docs: connects "without an access point"; Nearby: "regardless of network connectivity"). Cellular and GNSS cannot be used for phone-to-phone data by an app. **Finding:** radio range is local (tens of metres); reach beyond that comes only from devices moving.

### RQ2. Can phones form a Bluetooth Mesh?
Standard SIG Bluetooth Mesh on phones is used through GATT proxy for provisioning/control (Nordic library self-describes as "Provisioner and Configurator"). **Finding:** don't depend on SIG Mesh; do multi-hop at the application layer (what Briar/Bridgefy/Serval do in different forms).

### RQ3. What do existing systems teach us?
- **Briar:** BT + Wi-Fi + removable storage offline, Tor online, no central server, Mailbox for asynchronous delivery. Delivers directly between contacts (no stranger relaying of private messages per our reading — verify in source). GPLv3.
- **Bridgefy:** BLE mesh broadcast; repeatedly broken (CT-RSA 2021, USENIX Sec 2022) even after adopting libsignal. Lesson: integrate security into the relay protocol, authenticate everything relays act on, verify keys, bound parser input.
- **Serval:** Wi-Fi mesh + Rhizome store-and-forward; development largely stalled since ~2016; early root requirement shows Wi-Fi ad-hoc is not app-accessible on stock phones.

### RQ4. How should messages move when contacts are intermittent?
DTN literature: store-carry-forward; epidemic routing maximises delivery at high cost; Spray-and-Wait bounds copies to L. RFC 9171 contributes lifetime, creation timestamp + sequence identity, hop limits. **Adopted:** binary Spray-and-Wait with lifetime, hop limit, signed receipts as anti-packets.

### RQ5. Long distance with no infrastructure and no extra hardware?
Not possible as a direct link. Satellite messaging on Android 15+ is OEM/carrier-controlled and not open to arbitrary app data (AOSP docs). LoRa needs an accessory radio. GPS is receive-only. **Smallest constraint change:** allow an accessory (LoRa/Meshtastic) or carrier satellite service, or accept human-carried multi-hop latency.

### RQ6. Android background execution
`connectedDevice` foreground service is the documented fit for BT/network peers. Android 15 blocks some FGS types from boot receivers (dataSync). OEM battery managers are an unknown → experiment P-08.

### New (2026) fact that affects design
Nearby Connections will stop auto-enabling radios (late 2026). Any transport must guide the user to turn Bluetooth/Wi-Fi on.

## Open questions
1. Which Android versions' platform JCA provides Ed25519/X25519/ChaCha20-Poly1305? (App self-test answers this per device.)
2. Does insecure RFCOMM connect without a pairing dialog on current OEM builds?
3. Real contact frequencies on a campus → real latency distribution.
4. Background survival on Xiaomi/Samsung/Oppo/Vivo battery policies.
5. Can BLE advertising of a rotating token replace slow Classic discovery (≈12 s scan) for finding peers?
6. Briar source: confirm its exact transports and whether it ever relays for non-contacts.
