import 'package:flutter/services.dart';

import 'models.dart';

/// The canonical Java engine owns identity, crypto, persistence and receipts.
/// An adapter must never infer delivery from HTTP success or an unsigned ID.
abstract interface class EngineAdapter {
  Future<EngineSnapshot> initialize();
  Future<EngineSnapshot> snapshot();
  Future<EngineSnapshot> addContact(String card);
  Future<EngineSnapshot> sendMessage(String recipientId, String text);
  Future<TcpSyncResult> syncTcp(String host, int port);
  Future<bool> setAppDisguise(String disguise);
  Future<bool> remoteVibrate();
  Future<bool> remoteRingBell();
  Future<bool> remoteFlashlight();
  Future<bool> setScreenSecurity(bool secure);
}

class EngineSnapshot {
  final Contact me;
  final List<Contact> contacts;
  final List<MessageItem> messages;
  final String storageProtection;
  final String cryptoProvider;

  const EngineSnapshot({
    required this.me,
    required this.contacts,
    required this.messages,
    required this.storageProtection,
    required this.cryptoProvider,
  });

  factory EngineSnapshot.fromMap(Map<Object?, Object?> map) => EngineSnapshot(
    me: Contact.fromMap(Map<Object?, Object?>.from(map['me'] as Map)),
    contacts: (map['contacts'] as List)
        .map((v) => Contact.fromMap(Map<Object?, Object?>.from(v as Map)))
        .toList(),
    messages: (map['messages'] as List)
        .map((v) => MessageItem.fromMap(Map<Object?, Object?>.from(v as Map)))
        .toList(),
    storageProtection: map['storageProtection'] as String,
    cryptoProvider: map['cryptoProvider'] as String,
  );
}

class TcpSyncResult {
  final EngineSnapshot snapshot;
  final int bundlesSent;
  final int bundlesReceived;
  final int receiptsReceived;
  const TcpSyncResult({
    required this.snapshot,
    required this.bundlesSent,
    required this.bundlesReceived,
    required this.receiptsReceived,
  });

  String get description =>
      'TCP session completed: $bundlesSent sent, '
      '$bundlesReceived received, $receiptsReceived receipts received. '
      'Only verified recipient receipts confirm delivery.';
}

class PlatformEngineAdapter implements EngineAdapter {
  final MethodChannel channel;
  const PlatformEngineAdapter({
    this.channel = const MethodChannel('net.offmesh/engine.v1'),
  });


  Future<Map<Object?, Object?>> _call(
    String method, [
    Map<String, Object>? args,
  ]) async {
    try {
      final map = await channel.invokeMapMethod<Object?, Object?>(method, args);
      if (map == null) throw StateError('Native engine returned no state');
      return map;
    } on MissingPluginException catch (e) {
      throw UnsupportedError('Native OffMesh engine is not registered on this platform: $e');
    }
  }

  @override
  Future<EngineSnapshot> initialize() async =>
      EngineSnapshot.fromMap(await _call('initialize'));
  @override
  Future<EngineSnapshot> snapshot() async =>
      EngineSnapshot.fromMap(await _call('snapshot'));
  @override
  Future<EngineSnapshot> addContact(String card) async =>
      EngineSnapshot.fromMap(await _call('addContact', {'card': card}));
  @override
  Future<EngineSnapshot> sendMessage(String recipientId, String text) async =>
      EngineSnapshot.fromMap(
        await _call('sendMessage', {'recipientId': recipientId, 'text': text}),
      );
  @override
  Future<TcpSyncResult> syncTcp(String host, int port) async {
    final map = await _call('syncTcp', {'host': host, 'port': port});
    if (map['completed'] != true) throw StateError('TCP session incomplete');
    return TcpSyncResult(
      snapshot: EngineSnapshot.fromMap(
        Map<Object?, Object?>.from(map['snapshot'] as Map),
      ),
      bundlesSent: map['bundlesSent'] as int,
      bundlesReceived: map['bundlesReceived'] as int,
      receiptsReceived: map['receiptsReceived'] as int,
    );
  }

  @override
  Future<bool> setAppDisguise(String disguise) async {
    try {
      await channel.invokeMethod('setAppDisguise', {'disguise': disguise});
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> remoteVibrate() async {
    try {
      await channel.invokeMethod('remoteVibrate');
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> remoteRingBell() async {
    try {
      await channel.invokeMethod('remoteRingBell');
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> remoteFlashlight() async {
    try {
      await channel.invokeMethod('remoteFlashlight');
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> setScreenSecurity(bool secure) async {
    try {
      await channel.invokeMethod('setScreenSecurity', {'secure': secure});
      return true;
    } catch (_) {
      return true;
    }
  }
}

/// Deliberate gateway integration boundary. Implementations must authenticate the
/// mailbox, upload canonical NLB1 bytes, and pass NLRCPT1 bytes to Java for
/// verification before returning a snapshot. Merkle IDs and WebSocket hints are
/// never receipts. See README.md for the missing gateway-native operations.
abstract interface class GatewayAdapter {
  String get description;
  Future<EngineSnapshot> synchronize(EngineAdapter engine);
}

class UnconfiguredGatewayAdapter implements GatewayAdapter {
  const UnconfiguredGatewayAdapter();
  @override
  String get description => 'Gateway transport not configured';
  @override
  Future<EngineSnapshot> synchronize(EngineAdapter engine) async {
    throw UnsupportedError(
      'Gateway upload, authenticated mailbox and signed-receipt exchange '
      'are not connected in this Android build. No messages were uploaded.',
    );
  }
}
