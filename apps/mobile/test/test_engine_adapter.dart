import 'package:offmesh/core/crypto.dart';
import 'package:offmesh/core/engine_adapter.dart';
import 'package:offmesh/core/models.dart';

import 'dart:typed_data';

Contact testContact(String name, int seed) => OffMeshCrypto.parseCard(
  OffMeshCrypto.formatCard(
    name,
    Uint8List.fromList(List.generate(32, (i) => (i + seed) % 256)),
    Uint8List.fromList(List.generate(32, (i) => (i + seed + 32) % 256)),
  ),
);

/// Test-only adapter, deliberately never imported by application code.
class TestEngineAdapter implements EngineAdapter {
  EngineSnapshot state;
  bool failInitialize = false;
  bool failSave = false;
  bool failTcp = false;
  int initializeCalls = 0;
  int sendCalls = 0;
  int tcpCalls = 0;
  final alice = testContact('Alice', 1);

  TestEngineAdapter({bool withContact = false})
    : state = EngineSnapshot(
        me: testContact('Local test identity', 77),
        contacts: withContact ? [testContact('Alice', 1)] : [],
        messages: [],
        storageProtection: 'Test storage only',
        cryptoProvider: 'Test adapter only',
      );

  void replace({List<Contact>? contacts, List<MessageItem>? messages}) {
    state = EngineSnapshot(
      me: state.me,
      contacts: contacts ?? state.contacts,
      messages: messages ?? state.messages,
      storageProtection: state.storageProtection,
      cryptoProvider: state.cryptoProvider,
    );
  }

  @override
  Future<EngineSnapshot> initialize() async {
    initializeCalls++;
    if (failInitialize) throw StateError('Storage authentication failed');
    return state;
  }

  @override
  Future<EngineSnapshot> snapshot() async => state;
  @override
  Future<EngineSnapshot> addContact(String card) async {
    if (failSave) throw StateError('Persistence failed');
    final contact = OffMeshCrypto.parseCard(card);
    replace(
      contacts: [
        ...state.contacts.where((c) => c.idHex != contact.idHex),
        contact,
      ],
    );
    return state;
  }

  @override
  Future<EngineSnapshot> sendMessage(String recipientId, String text) async {
    sendCalls++;
    if (failSave) throw StateError('Persistence failed');
    replace(
      messages: [
        ...state.messages,
        MessageItem(
          id: sendCalls.toRadixString(16).padLeft(32, '0'),
          toIdHex: recipientId,
          fromIdHex: state.me.idHex,
          text: text,
          isOutgoing: true,
          timestampMs: 1700000000000 + sendCalls,
        ),
      ],
    );
    return state;
  }

  @override
  Future<TcpSyncResult> syncTcp(String host, int port) async {
    tcpCalls++;
    if (failTcp) throw StateError('Connection refused');
    return TcpSyncResult(
      snapshot: state,
      bundlesSent: 0,
      bundlesReceived: 0,
      receiptsReceived: 0,
    );
  }

  @override
  Future<bool> setAppDisguise(String disguise) async => true;

  int vibrateCallCount = 0;
  int ringBellCallCount = 0;

  @override
  Future<bool> remoteVibrate() async {
    vibrateCallCount++;
    return true;
  }

  @override
  Future<bool> remoteRingBell() async {
    ringBellCallCount++;
    return true;
  }

  @override
  Future<bool> remoteFlashlight() async => true;

  @override
  Future<bool> setScreenSecurity(bool secure) async => true;
}
