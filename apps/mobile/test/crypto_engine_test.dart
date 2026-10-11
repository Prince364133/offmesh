import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offmesh/core/crypto.dart';
import 'package:offmesh/core/engine_adapter.dart';
import 'package:offmesh/core/models.dart';
import 'package:offmesh/core/engine.dart';

import 'test_engine_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canonical public identity helpers', () {
    test(
      'identity is SHA-256(signPub || dhPub), not an incompatible domain hash',
      () {
        final sign = Uint8List.fromList(List.generate(32, (i) => i));
        final dh = Uint8List.fromList(List.generate(32, (i) => i + 32));
        final card = OffMeshCrypto.formatCard('Alice', sign, dh);
        final contact = OffMeshCrypto.parseCard(card);
        expect(contact.name, 'Alice');
        // SHA-256 of bytes 0..63, also computed by Java Identity.idOf.
        expect(
          contact.idHex,
          'fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108',
        );
        expect(contact.cardString, card);
      },
    );

    test('rejects trailing bytes, padded base64, oversized names and malformed keys', () {
      final card = testContact('Alice', 1).cardString;
      final bytes = base64Url.decode(base64Url.normalize(card.substring(4)));
      final trailing =
          'NL1:${base64Url.encode([...bytes, 0]).replaceAll('=', '')}';
      expect(() => OffMeshCrypto.parseCard(trailing), throwsFormatException);
      expect(() => OffMeshCrypto.parseCard('$card='), throwsFormatException);
      expect(
        () => OffMeshCrypto.formatCard('a' * 65, Uint8List(32), Uint8List(32)),
        throwsFormatException,
      );
      expect(
        () => OffMeshCrypto.idOf(Uint8List(31), Uint8List(32)),
        throwsFormatException,
      );
      expect(() => OffMeshCrypto.unhex('a'), throwsFormatException);
      expect(() => OffMeshCrypto.unhex('gg'), throwsFormatException);
    });

    test(
      'safety code is symmetric, 20 hexadecimal characters in four groups',
      () {
        final a = Uint8List(32);
        final b = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final code = OffMeshCrypto.safetyCode(a, b);
        expect(code, OffMeshCrypto.safetyCode(b, a));
        expect(
          RegExp(r'^[0-9a-f]{5}( [0-9a-f]{5}){3}$').hasMatch(code),
          isTrue,
        );
        expect(
          () => OffMeshCrypto.safetyCode(Uint8List(1), b),
          throwsFormatException,
        );
      },
    );
  });

  group('Native-backed injectable state', () {
    late TestEngineAdapter adapter;
    late OffMeshEngine engine;
    setUp(() {
      adapter = TestEngineAdapter();
      engine = OffMeshEngine(adapter: adapter);
    });
    tearDown(() => engine.dispose());

    test(
      'initialization is idempotent and does not seed demo contacts',
      () async {
        await Future.wait([engine.init(), engine.init()]);
        expect(adapter.initializeCalls, 1);
        await engine.init();
        expect(adapter.initializeCalls, 1);
        expect(engine.contacts, isEmpty);
        expect(engine.messages, isEmpty);
        expect(engine.me.idHex, adapter.state.me.idHex);
        expect(
          () => engine.contacts.add(adapter.alice),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'initialization failure does not invent identity and can be retried',
      () async {
        adapter.failInitialize = true;
        await expectLater(engine.init(), throwsStateError);
        expect(engine.isReady, isFalse);
        expect(engine.lastError, contains('authentication failed'));
        adapter.failInitialize = false;
        await engine.init();
        expect(engine.isReady, isTrue);
      },
    );

    test('only committed native messages appear, no timer-driven forwarding', () async {
      await engine.init();
      final contact = await engine.addContactFromCardString(
        adapter.alice.cardString,
      );
      adapter.failSave = true;
      await expectLater(
        engine.sendMessage(contact, 'not persisted'),
        throwsStateError,
      );
      expect(engine.messages, isEmpty);
      adapter.failSave = false;
      await engine.sendMessage(contact, 'Persisted');
      expect(engine.messages.single.status, MessageStatus.queued);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(engine.messages.single.status, MessageStatus.queued);
      expect(engine.messages.single.relayHandoffs, 0);
      // A new projection restores the adapter's persisted identity and history.
      final restarted = OffMeshEngine(adapter: adapter);
      await restarted.init();
      expect(restarted.me.idHex, engine.me.idHex);
      expect(restarted.messages.single.text, 'Persisted');
      restarted.dispose();
    });

    test(
      'failed gateway sync never marks queued messages forwarded or delivered',
      () async {
        await engine.init();
        final contact = await engine.addContactFromCardString(
          adapter.alice.cardString,
        );
        await engine.sendMessage(contact, 'Pending');
        await expectLater(engine.syncWithGateway(), throwsUnsupportedError);
        expect(engine.messages.single.status, MessageStatus.queued);
        expect(engine.lastSyncResult, isNull);
        expect(engine.isBusy, isFalse);
        expect(engine.lastError, contains('No messages were uploaded'));
      },
    );

    test(
      'TCP completion and connection errors reflect adapter results',
      () async {
        await engine.init();
        await engine.syncTcp('127.0.0.1', 47700);
        expect(adapter.tcpCalls, 1);
        expect(engine.lastSyncResult, contains('0 sent'));
        adapter.failTcp = true;
        await expectLater(engine.syncTcp('127.0.0.1', 47700), throwsStateError);
        expect(engine.lastSyncResult, isNull);
        expect(engine.lastError, contains('Connection refused'));
      },
    );

    test(
      'validates canonical UTF-8 message size before crossing bridge',
      () async {
        await engine.init();
        final contact = await engine.addContactFromCardString(
          adapter.alice.cardString,
        );
        await expectLater(
          engine.sendMessage(contact, '😀' * 1001),
          throwsArgumentError,
        );
        expect(adapter.sendCalls, 0);
      },
    );
  });

  test(
    'platform bridge routes calls; missing plugin has no demo fallback',
    () async {
      const channel = MethodChannel('test.offmesh/engine');
      const adapter = PlatformEngineAdapter(channel: channel);
      final calls = <MethodCall>[];
      final me = testContact('Native identity', 5);
      final map = {
        'me': {
          'name': me.name,
          'idHex': me.idHex,
          'signPubHex': me.signPubHex,
          'encPubHex': me.encPubHex,
          'cardString': me.cardString,
        },
        'contacts': [],
        'messages': [],
        'storageProtection': 'Android Keystore',
        'cryptoProvider': 'BC',
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'syncTcp') {
              return {
                'snapshot': map,
                'completed': true,
                'bundlesSent': 2,
                'bundlesReceived': 1,
                'receiptsReceived': 0,
              };
            }
            return map;
          });
      expect((await adapter.initialize()).me.idHex, me.idHex);
      await adapter.addContact(me.cardString);
      await adapter.sendMessage(me.idHex, 'text');
      expect((await adapter.syncTcp('127.0.0.1', 47700)).bundlesSent, 2);
      expect(calls.map((c) => c.method), [
        'initialize',
        'addContact',
        'sendMessage',
        'syncTcp',
      ]);
      expect(calls.last.arguments, {'host': '127.0.0.1', 'port': 47700});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(adapter.initialize(), throwsUnsupportedError);
    },
  );
}
