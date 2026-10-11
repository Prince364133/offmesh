# OffMesh implementation and production-release plan

## Goal and release rule
Deliver a real Android text messenger: create a protected identity, exchange contacts, persist queued messages, transfer encrypted bundles directly and through consenting relays, verify recipient receipts, and optionally use an authenticated internet gateway. Existing UI controls must execute real operations or be explicitly unavailable. No release is called production-ready solely because it compiles.

Scope: Android first, one-to-one text, Bluetooth and local TCP, optional gateway. iOS/web/desktop mesh, groups, attachments, a ratcheting protocol, and guaranteed emergency delivery are not supported features of this release. They must not be advertised as implemented.

## Baseline audit
The initial Flutter application has deterministic placeholder identities, memory-only state, timer-based simulated upload, scan-only BLE, false completed-sync UI, and no bundle crypto. The Java core has real tested protocol logic but is disconnected. Backend identity, bundle, and receipt formats differ from Java; mailbox/socket authorization, receipt recipient binding, expiry cleanup, migrations, and shutdown require repair. Documentation overstates capabilities.

## Work packages

### WP1: Canonical engine and Android runtime
- Use Java core's existing NL1/NLB1 wire format and SHA256(signPub || dhPub) identity, not a new incompatible Dart protocol.
- Harden protocol parsing, receipt-before-bundle handling, time/size quotas, bounded sync summaries, persistence failures, and unsupported message types.
- Add regression tests for forged/early receipts, interrupted transfer, persistence/restart, input bounds, and exported canonical fixtures.
- Compile the core into Android and expose the platform bridge specified in `docs/NATIVE_BRIDGE.md`.
- Use real secure key generation and Android Keystore AES-GCM wrapping of private identity and stored messaging state. Report hardware backing from runtime evidence, not a static string.
- Implement TCP listener/connect and Bluetooth RFCOMM listener/connect; BLE rendezvous advertising/scanning where available.
- Implement foreground-service lifecycle, runtime permission results, timeouts, cleanup, and explicit relay opt-in.
- Implement a real authenticated gateway client using the contract in `docs/PROTOCOL_CONTRACT.md`.
- Implement persisted settings, local deletion, queued-only cancellation, completed-history clearing, contact verification, and identity reset.

### WP2: Flutter application
- Replace the demo engine with an injectable platform adapter and typed snapshots/events.
- Represent unsupported platforms honestly; never generate placeholder identity or success.
- Add loading/error/onboarding/permission states, QR scanning/display, contact verification, valid conversation filtering, and real async operation status.
- Connect Nearby actions, relay/storage/battery/network controls, gateway URL/sync, cache clearing, cancellation, deletion, reset, and contact-to-chat navigation.
- Enforce text limits and truthful status labels. RSSI is approximate signal strength, not measured metres or bearing.
- Add adapter, state, and widget regression tests. Keep Flutter analyzer clean.

### WP3: Gateway
- Decode the canonical Java bundles/receipts and distinguish identity hashes from signing keys.
- Require proof of key possession for registration, issue single-use challenges, and bind bearer sessions to identities.
- Authorize mailbox and WebSocket connections; unauthenticated users cannot claim another identity.
- Verify receipt signature AND binding to the stored bundle's recipient/id/expiry. Relay receipt upload remains possible without pretending relay == recipient.
- Persist opaque packets and full receipts; safely handle duplicate/racing writes, receipt-before-upload, errors, and TTL.
- Add checked-in migrations and migration commands, strict config, rate/size/resource limits, dependency readiness, and graceful shutdown.
- Make Merkle hashing deterministic/idempotent and restorable, but do not require it for correct delivery. Notifications are hints; clients verify full receipts.
- Write hermetic protocol/auth/route tests plus explicitly gated real PostgreSQL/Redis integration tests. No tests accept 400/500 as successful registration.

### WP4: Delivery, public claims, and release gates
- Fix root scripts/package manager consistency, pinned toolchain guidance, CI Java/Flutter/backend checks, real dependency integration tests, and fail-closed release signing.
- Correct README/status/security/privacy/deletion claims to match current behavior; clearly distinguish tests from hardware evidence.
- Remove claims of Double Ratchet, certified security, measured physical performance, or implemented unsupported features.
- Supply deployment and migration/rollback/backup guidance, secret templates, TLS/private-infrastructure requirements, and a physical-device test checklist.

## Integration order
1. Freeze canonical contract and bridge.
2. Implement WP1-WP4 in parallel with disjoint file ownership.
3. Run Java fixtures through backend and Flutter contact parsers; repair mismatches.
4. Run Java tests, backend typecheck/tests/integration (if infrastructure available), Flutter analyzer/tests, Android APK build, docs/landing builds.
5. Inspect real runtime via emulator if available. Do not count emulator TCP as physical Bluetooth proof.
6. Review changes and resolve reproducible issues. Record external blockers separately.

## Acceptance scenarios
- New installs create different keys; reboot/restart retains the same identity.
- Contact QR roundtrip yields the same canonical node ID; imported contact is not auto-marked verified.
- A sends to B over local transport: B decrypts once; A only shows delivered after valid signed receipt.
- A queues offline, restarts, connects later: no lost queued message.
- A -> R -> B then B -> R -> A with no A/B encounter: delivered with opaque relay data.
- Forged or wrong-recipient receipt, changed expiry, malformed packet, replay, over-limit traffic, and unknown sender are rejected without corruption.
- Interrupted transfers can retry without duplicate inbox items or lost copy budget.
- A relay opt-out prevents carrying third-party new packets; storage/network/battery controls affect actual behavior.
- Gateway rejects unauthorized mailbox/socket claims; healthy readiness requires backing services; TTL and receipt pruning actually remove payloads.
- App and server shutdown release resources. Test processes exit naturally.

## External production gates (cannot be replaced by code generation)
- At least three physical Android phones, preferably across manufacturers and Android versions, for actual offline radio and relay testing.
- Screen-off/Doze/OEM-background behavior and battery measurements over a representative pilot period.
- Independent review of custom cryptographic protocol and application security; this protocol does not provide forward secrecy.
- Owner-approved production domain/TLS, gateway credentials, private PostgreSQL/Redis, backups, and monitoring.
- Owner-controlled release/upload signing keys, Play Console configuration, and accurate policy/legal approval.
- Installation and upgrade/migration validation against actual prior distributed builds.

## Reporting
Implementation completion, automated validation, and production release approval are separate statuses. Track final commands, failures, and outstanding gates in `RELEASE_READINESS.md`. Do not fabricate hardware or deployment success.
