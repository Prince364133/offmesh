# Engineering decisions

**D-01 Target a local delay-tolerant network, not a long-range channel.** Alternatives: GNSS, arbitrary-frequency transmission, Bluetooth Mesh, satellite, LoRa. Reason: phones cannot transmit to GNSS; radios are firmware-locked and licensed; standard BT Mesh libraries let phones act only as provisioner/proxy clients; satellite messaging is carrier-controlled and closed to arbitrary third-party data; LoRa needs extra hardware. (FEASIBILITY.md §2)

**D-02 First transports: Bluetooth Classic RFCOMM + TCP over hotspot/LAN.** Alternatives: Nearby Connections (needs Google Play services; late-2026 change requires user to enable radios manually), Wi-Fi Aware (only on devices with FEATURE_WIFI_AWARE), Wi-Fi Direct (connection prompts), BLE GATT (small MTU, peripheral support varies). Reason: pure AOSP APIs on all Android 12+ phones, simplest to reason about; Briar uses the same class of transports. Revisit after first device tests.

**D-03 Transport-independent core in plain Java, no third-party deps.** Lets us test the protocol here (Maven/Google repos are blocked in the build container) and reuse unchanged in the app. Android compiles `core/src` directly.

**D-04 Application-level store-carry-forward with binary Spray-and-Wait (default L=8).** Alternatives: epidemic (most transfers/storage), direct delivery (low delivery ratio), PRoPHET (RFC 6693; needs encounter history — later). Our simulation: L=8 reached 95–100% delivery at 6 h with ~40% of epidemic's transfers (3 seeds). (EXPERIMENT_LOG E-03)

**D-05 E2E: ephemeral-static X25519 + HKDF + ChaCha20-Poly1305, sign-then-encrypt with Ed25519.** Alternatives: libsignal (best practice, but needs interactive sessions/prekeys; hard with one-shot offline contacts; and dependency unavailable here), OpenPGP. Reason: one-shot messages to a statically known key work with zero round trips. Cost: no forward secrecy (documented).

**D-06 Publicly verifiable receipts.** Lets relays purge delivered messages without trusting anyone; costs metadata privacy. Chosen for storage efficiency; revisit.

**D-07 Only verified receipts produce "Delivered".** Link-level ACKs are unauthenticated and only mean "a device stored a copy".

**D-08 Accept messages only from contacts (default).** Limits spam; trade-off: strangers can't reach you.

**D-09 Whole-state atomic snapshot persistence.** Simple and crash-safe at prototype scale (hundreds of messages); replace with SQLite/Room when scale requires.

**D-10 minSdk 31 + crypto self-test with BouncyCastle fallback.** We could not verify which Android versions' platform provider implements Ed25519/X25519/ChaCha20-Poly1305 at runtime; the app tests at start-up and reports which provider is in use.
