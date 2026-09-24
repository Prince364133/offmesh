# Next steps

## Blockers (need you)
1. **Physical phones.** ≥2 Android 12+ phones (3 for relay tests) with USB debugging. Tell me the models/Android versions.
2. **A place to build the APK.** Your PC appears to have Android tooling. Either open `android/` in Android Studio (it will download AGP/Gradle/BouncyCastle) and run, or connect a folder in the Claude desktop app so I can place the project there and try building it for you.

## Next experiments (in order)
P-01 crypto self-test on each phone → P-02 BT sync in airplane mode (+BT) → P-03 hotspot LAN sync → P-06 delayed delivery via auto-retry → P-07 three-phone relay → P-04 range sweep → P-08 background/Doze → P-10 battery. Procedures and pass criteria: EXPERIMENT_LOG.md.

## Next implementation tasks
1. QR code display/scan for contact cards (needs a QR library or camera intent).
2. BLE advertisement of a rotating token so phones find each other without the 12 s Classic scan and without "discoverable" prompts.
3. Rotating HELLO identifiers (tracking resistance).
4. Keystore-wrapped identity key.
5. Transport #3: Wi-Fi Aware where `FEATURE_WIFI_AWARE` exists; evaluate Nearby Connections as optional (Play-services) transport.
6. Replace synthetic contact model with a real mobility trace; add PRoPHET for comparison.
