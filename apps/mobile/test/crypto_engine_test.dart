import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearlink_mobile/core/crypto.dart';
import 'package:nearlink_mobile/core/models.dart';
import 'package:nearlink_mobile/core/engine.dart';

void main() {
  group('NearLink Mobile Cryptography & Wire Protocol', () {
    test('1. Contact card formatting and parsing roundtrip', () {
      final signPub = Uint8List.fromList(List.generate(32, (i) => i));
      final dhPub = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      final cardStr = NearLinkCrypto.formatCard('Alice', signPub, dhPub);

      expect(cardStr.startsWith('NL1:'), isTrue);

      final contact = NearLinkCrypto.parseCard(cardStr);
      expect(contact.name, equals('Alice'));
      expect(contact.signPubHex, equals(NearLinkCrypto.hex(signPub)));
      expect(contact.encPubHex, equals(NearLinkCrypto.hex(dhPub)));
      expect(contact.idHex.length, equals(64)); // 32-byte hex ID
    });

    test('2. Safety code generation format (5-char groups)', () {
      final idA = Uint8List(32);
      final idB = Uint8List.fromList(List.generate(32, (i) => i + 1));

      final safetyCode = NearLinkCrypto.safetyCode(idA, idB);
      // Expected: "XXXXX XXXXX XXXXX XXXXX" (4 groups of 5 separated by spaces)
      expect(safetyCode.length, equals(23));
      final groups = safetyCode.split(' ');
      expect(groups.length, equals(4));
      for (final g in groups) {
        expect(g.length, equals(5));
      }
    });

    test('3. Engine message status tracking and honest progression', () {
      final engine = NearLinkEngine.instance;
      expect(engine.me.name, equals('MobileUser'));

      final charlieCard = NearLinkCrypto.formatCard(
        'Charlie',
        Uint8List(32),
        Uint8List(32),
      );
      engine.addContact(charlieCard);
      expect(engine.contacts.any((c) => c.name == 'Charlie'), isTrue);

      final recipient = engine.contacts.firstWhere((c) => c.name == 'Charlie');
      final msg = engine.sendMessage(recipient, 'Hello mesh world!');
      expect(msg.status, equals(MessageStatus.queued));
      expect(msg.relayHandoffs, equals(0));
      expect(msg.statusBadge, equals('QUEUED'));

      // Simulate forwarding hop
      engine.markMessageForwarded(msg.id, 'RelayNode1');
      expect(msg.status, equals(MessageStatus.forwarded));
      expect(msg.relayHandoffs, equals(1));
      expect(msg.statusBadge, contains('FORWARDED (Hops: 1)'));

      // Simulate delivery receipt
      engine.markMessageDelivered(msg.id);
      expect(msg.status, equals(MessageStatus.delivered));
      expect(msg.statusBadge, contains('DELIVERED'));
      expect(msg.deliveredAtMs, isNotNull);
    });

    test('4. Merkle Root Calculation returns deterministic 32-byte hash', () {
      final rootEmpty = NearLinkCrypto.computeMerkleRoot([]);
      expect(rootEmpty.length, equals(64));

      final leafA = NearLinkCrypto.hex(Uint8List(32));
      final leafB = NearLinkCrypto.hex(Uint8List.fromList(List.generate(32, (i) => 0xff)));
      final rootWithLeaves = NearLinkCrypto.computeMerkleRoot([leafA, leafB]);

      expect(rootWithLeaves.length, equals(64));
      expect(rootWithLeaves, isNot(equals(rootEmpty)));
    });
  });
}
