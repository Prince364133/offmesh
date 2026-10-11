import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'crypto.dart';
import 'engine_adapter.dart';
import 'models.dart';

/// Observable projection of persistent native state. No Dart signing keys,
/// placeholder identities, optimistic delivery, or demo contacts.
class OffMeshEngine extends ChangeNotifier {
  static final OffMeshEngine instance = OffMeshEngine();
  static final Guid offmeshBleUuid = Guid(
    '00006e4c-0000-1000-8000-00805f9b34fb',
  );

  final EngineAdapter adapter;
  final GatewayAdapter gateway;
  OffMeshEngine({
    this.adapter = const PlatformEngineAdapter(),
    this.gateway = const UnconfiguredGatewayAdapter(),
  });

  EngineSnapshot? _snapshot;
  Future<void>? _initializing;
  bool _disposed = false;
  bool _busy = false;
  bool get isReady => _snapshot != null;
  bool get isBusy => _busy;
  Contact get me => _snapshot!.me;
  Contact get myCard => me;
  List<Contact> get contacts =>
      List.unmodifiable(_snapshot?.contacts ?? const <Contact>[]);
  List<MessageItem> get messages =>
      List.unmodifiable(_snapshot?.messages ?? const <MessageItem>[]);
  String get storageProtection => _snapshot?.storageProtection ?? 'Unavailable';
  String get cryptoProvider => _snapshot?.cryptoProvider ?? 'Unavailable';
  String get gatewayDescription => gateway.description;
  String? lastError;
  String? lastSyncResult;

  Future<void> init() {
    if (isReady) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _apply(await adapter.initialize());
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _initializing = null;
      _notify();
    }
  }

  void _apply(EngineSnapshot state) {
    _snapshot = EngineSnapshot(
      me: state.me,
      contacts: List.unmodifiable(state.contacts),
      messages: List.unmodifiable(
        [...state.messages]
          ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs)),
      ),
      storageProtection: state.storageProtection,
      cryptoProvider: state.cryptoProvider,
    );
  }

  Future<T> _operation<T>(Future<T> Function() action) async {
    if (!isReady) throw StateError('Engine is not initialized');
    if (_busy) throw StateError('Another engine operation is in progress');
    _busy = true;
    lastError = null;
    _notify();
    try {
      return await action();
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> refresh() => _operation(() async {
    _apply(await adapter.snapshot());
  });

  Future<Contact> addContactFromCardString(String card) => _operation(() async {
    final parsed = OffMeshCrypto.parseCard(card.trim());
    if (parsed.idHex == me.idHex)
      throw ArgumentError('Cannot add your own card');
    _apply(await adapter.addContact(parsed.cardString));
    return contacts.firstWhere((c) => c.idHex == parsed.idHex);
  });

  Future<void> sendMessage(Contact recipient, String text) =>
      _operation(() async {
        if (text.trim().isEmpty) throw ArgumentError('Message cannot be empty');
        if (utf8.encode(text).length > 4000)
          throw ArgumentError('Message exceeds 4000 UTF-8 bytes');
        if (!contacts.any((c) => c.idHex == recipient.idHex))
          throw ArgumentError('Unknown recipient');
        _apply(await adapter.sendMessage(recipient.idHex, text));
      });

  Future<void> syncWithGateway() => _operation(() async {
    lastSyncResult = null;
    _apply(await gateway.synchronize(adapter));
    lastSyncResult =
        'Gateway exchange completed. Check individual message statuses.';
  });

  Future<void> syncTcp(String host, int port) => _operation(() async {
    lastSyncResult = null;
    try {
      final result = await adapter.syncTcp(host, port);
      _apply(result.snapshot);
      lastSyncResult = result.description;
    } catch (_) {
      // A failed session may still have persisted a valid incoming bundle or
      // receipt. Refresh actual native state, but preserve the failure outcome.
      try {
        _apply(await adapter.snapshot());
      } catch (_) {
        /* Keep last known state. */
      }
      rethrow;
    }
  });

  String getSafetyCodeFor(Contact c) => OffMeshCrypto.safetyCode(
    OffMeshCrypto.unhex(me.idHex),
    OffMeshCrypto.unhex(c.idHex),
  );

  // BLE is observation only, not a message transport. No automatic scan at boot.
  final Map<String, DiscoveredPeer> _discoveredPeers = {};
  Map<String, DiscoveredPeer> get discoveredPeers =>
      Map.unmodifiable(_discoveredPeers);
  bool isBleScanning = false;
  String? scanError;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanStateSub;

  Future<void> startBleScan() async {
    if (isBleScanning) return;
    scanError = null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      scanError = 'BLE observation is available on Android only.';
      _notify();
      return;
    }
    try {
      if (!await FlutterBluePlus.isSupported)
        throw UnsupportedError('Bluetooth LE is unavailable');
      await _scanSub?.cancel();
      await _scanStateSub?.cancel();
      _discoveredPeers.clear();
      _scanStateSub = FlutterBluePlus.isScanning.listen((scanning) {
        isBleScanning = scanning;
        _notify();
      });
      _scanSub = FlutterBluePlus.onScanResults.listen(
        (results) {
          final now = DateTime.now();
          _discoveredPeers.removeWhere(
            (_, p) => now.difference(p.lastSeen) > const Duration(seconds: 30),
          );
          for (final result in results) {
            _discoveredPeers[result.device.remoteId.str] = DiscoveredPeer(
              name: result.advertisementData.advName.isNotEmpty
                  ? result.advertisementData.advName
                  : 'Bluetooth device',
              address: result.device.remoteId.str,
              rssi: result.rssi,
              lastSeen: now,
              isNearLinkPeer: result.advertisementData.serviceUuids.contains(
                offmeshBleUuid,
              ),
            );
          }
          _notify();
        },
        onError: (Object error) {
          scanError = error.toString();
          _notify();
        },
      );
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      scanError = 'Scan failed: $e';
      isBleScanning = false;
      await _scanSub?.cancel();
      await _scanStateSub?.cancel();
      _notify();
    }
  }

  Future<void> stopBleScan() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      scanError = 'Could not stop scan: $e';
    } finally {
      await _scanSub?.cancel();
      await _scanStateSub?.cancel();
      isBleScanning = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stopBleScan());
    super.dispose();
  }
}

class EngineScope extends InheritedNotifier<OffMeshEngine> {
  const EngineScope({
    super.key,
    required OffMeshEngine engine,
    required super.child,
  }) : super(notifier: engine);
  static OffMeshEngine of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EngineScope>()!.notifier!;
}

typedef NearLinkEngine = OffMeshEngine;
