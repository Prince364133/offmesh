import 'package:flutter_test/flutter_test.dart';
import 'package:offmesh/core/haven_e2ee.dart';
import 'package:offmesh/core/haven_engine.dart';
import 'package:offmesh/core/models.dart';

void main() {
  group('Haven E2EE Cryptography & Couple Haven Tests', () {
    test('1. End-to-End Encryption and Decryption round-trip succeeds with zero knowledge', () async {
      // 1. Generate identity keys for Alice and Bob
      final aliceKeys = await havenCrypto.generateIdentity();
      final bobKeys = await havenCrypto.generateIdentity();

      expect(aliceKeys.signPubKeyHex.length, 64);
      expect(aliceKeys.encPubKeyHex.length, 64);
      expect(bobKeys.signPubKeyHex.length, 64);
      expect(bobKeys.encPubKeyHex.length, 64);

      // 2. Alice seals an intimate love message for Bob
      const loveLetter = 'My dearest love, privacy is our sanctuary. ❤️';
      final envelope = await havenCrypto.encryptMessage(
        plaintext: loveLetter,
        recipientEncPubHex: bobKeys.encPubKeyHex,
        myKeys: aliceKeys,
      );

      expect(envelope.ciphertextBase64.isNotEmpty, true);
      expect(envelope.wireBundleBase64.isNotEmpty, true);
      expect(envelope.signatureHex.length, 128);

      // Verify that ciphertext does NOT contain plaintext
      expect(envelope.wireBundleBase64.contains(loveLetter), false);

      // 3. Bob opens and verifies the sealed envelope using his private keys
      final decrypted = await havenCrypto.decryptMessage(
        wireBundleBase64: envelope.wireBundleBase64,
        senderSignPubHex: aliceKeys.signPubKeyHex,
        myKeys: bobKeys,
      );

      expect(decrypted, loveLetter);
    });

    test('2. Decoy Calculator PIN verification unlocks stealth sanctuary', () {
      final engine = HavenEngine.instance;

      expect(engine.isStealthUnlocked, false);

      // Wrong pin fails
      final wrong = engine.verifyPin('9999');
      expect(wrong, false);
      expect(engine.isStealthUnlocked, false);

      // Default pin '1234' succeeds
      final correct = engine.verifyPin('1234');
      expect(correct, true);
      expect(engine.isStealthUnlocked, true);
    });

    test('3. Stealth Settings and Ghost Notification Camouflage', () {
      final settings = StealthSettings(
        appDisguise: 'CALCULATOR',
        decoyPin: '4321',
        notifDisguiseMode: 'CAMOUFLAGE',
        fakeSenderTitle: 'Google Drive',
        fakeBodyPreview: '3 items synchronized successfully',
      );

      final json = settings.toJson();
      expect(json['appDisguise'], 'CALCULATOR');
      expect(json['decoyPin'], '4321');
      expect(json['fakeSenderTitle'], 'Google Drive');

      final deserialized = StealthSettings.fromJson(json);
      expect(deserialized.appDisguise, 'CALCULATOR');
      expect(deserialized.fakeBodyPreview, '3 items synchronized successfully');
    });
  });
}
