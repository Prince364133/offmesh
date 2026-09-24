# Bibliography

"Read" = opened this session (2026-09-24) and the cited claim confirmed. "Cited" = identified by search / well-established, full text not re-read this session — verify before relying on specifics.

## Official documentation & specifications
1. Android Developers — *Bluetooth permissions*. https://developer.android.com/develop/connectivity/bluetooth/bt-permissions — **Read.** Android 12+: BLUETOOTH_SCAN / ADVERTISE / CONNECT; `neverForLocation`; Android ≤11 needs ACCESS_FINE_LOCATION.
2. Android Developers — *Wi-Fi Aware overview*. https://developer.android.com/develop/connectivity/wifi/wifi-aware — **Read.** API 26+, `FEATURE_WIFI_AWARE` check, works "without an access point", `getAvailableAwareResources()` for data-path limits; no metre figure given.
3. Android Developers — *Foreground service types*. https://developer.android.com/develop/background-work/services/fgs/service-types — **Read.** `connectedDevice` type and its prerequisites; Android 15 forbids starting dataSync FGS from BOOT_COMPLETED.
4. Google — *Nearby Connections overview*. https://developers.google.com/nearby/connections/overview — **Read.** Uses Bluetooth, BLE, Wi-Fi; "regardless of network connectivity"; encrypted; Play-services SDK.
5. Android Developers Blog — *Upcoming changes to the Nearby Connections API* (July 2026). https://android-developers.googleblog.com/2026/07/upcoming-changes-nearby-connections-api.html — **Read.** API will no longer auto-enable Wi-Fi/Bluetooth; apps must ask users; late 2026.
6. AOSP — *Satellite connectivity*. https://source.android.com/docs/core/connect/satellite — **Read.** Android 15+ NTN support needs OEM `ISatellite` HAL and carrier config; background data restricted to core services/allowlisted apps.
7. RFC 9171 — *Bundle Protocol Version 7*, Burleigh, Fall, Birrane, IETF, Jan 2022. https://www.rfc-editor.org/rfc/rfc9171.html — **Read.** Lifetime, creation timestamp, hop-count block, status reports. Our bundle borrows these concepts (not wire-compatible).
8. RFC 4838 — *Delay-Tolerant Networking Architecture*, Cerf et al., 2007. https://www.rfc-editor.org/rfc/rfc4838 — Cited.
9. RFC 6693 — *PRoPHET routing for intermittently connected networks*, Lindgren et al., 2012. https://www.rfc-editor.org/rfc/rfc6693 — Cited (future routing option).
10. RFC 5869 — *HKDF*, Krawczyk & Eronen, 2010. https://www.rfc-editor.org/rfc/rfc5869 — Test vector 1 used and passed (T02).
11. RFC 7748 (X25519), RFC 8032 (Ed25519), RFC 8439 (ChaCha20-Poly1305), RFC 8410 (SPKI encodings) — Cited; used through JCA.

## Peer-reviewed papers
12. Spyropoulos, Psounis, Raghavendra — *Spray and Wait: an efficient routing scheme for intermittently connected mobile networks*, ACM SIGCOMM WDTN 2005. https://dl.acm.org/doi/10.1145/1080139.1080143 (PDF: http://conferences.sigcomm.org/sigcomm/2005/paper-SpyPso.pdf) — Cited (located; not re-read). Basis of our forwarding rule.
13. Vahdat & Becker — *Epidemic Routing for Partially-Connected Ad Hoc Networks*, Duke tech. report CS-2000-06, 2000 — Cited. Summary-vector anti-entropy idea used in SyncSession.
14. Albrecht, Eikenberg, Paterson — *Breaking Bridgefy, again: Adopting libsignal is not enough*, USENIX Security 2022. https://www.usenix.org/conference/usenixsecurity22/presentation/albrecht — **Read (project page summary** https://eikendev.github.io/breaking-bridgefy-again/). Confidentiality break (~50% success) via implementation flaw, tracking, unauthenticated broadcast, MITM at key exchange, malformed-message DoS.
15. Albrecht, Blasco, Jensen, Mareková — *Mesh Messaging in Large-scale Protests: Breaking Bridgefy*, CT-RSA 2021 — Cited.

## Projects / source
16. Briar — *How it works*. https://briarproject.org/how-it-works/ — **Read.** Syncs over Bluetooth, Wi-Fi, memory cards offline; Tor online; no central server; Briar Mailbox for asynchronous delivery. License GPLv3 (Cited) → code reuse would force GPLv3 on us.
17. Serval Project — https://en.wikipedia.org/wiki/Serval_Project and https://github.com/servalproject/batphone — **Read (Wikipedia).** Wi-Fi mesh + Rhizome store-and-forward; last major release 0.93 (2016); GPLv2/GPLv3. Early versions needed root for Wi-Fi ad-hoc (Cited, blog: http://servalpaul.blogspot.com/2013/04/root-free-operation-of-serval-mesh.html).
18. Nordic Semiconductor — Android-nRF-Mesh-Library. https://github.com/NordicSemiconductor/Android-nRF-Mesh-Library — **Read.** "Provisioner and Configurator library" — phone talks to mesh via GATT proxy, not as relay node.
19. ggwave — https://github.com/ggerganov/ggwave — **Read.** Data-over-sound, FSK, "8-16 bytes/sec".
20. Bridgefy — https://en.wikipedia.org/wiki/Bridgefy — Cited.

## Inaccessible this session
- Briar wiki "How it works" on code.briarproject.org — read timeout.
