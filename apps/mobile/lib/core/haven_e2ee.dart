import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'crypto.dart';

class HavenE2EEKeys {
  final SimpleKeyPair signKeyPair;
  final SimpleKeyPair encKeyPair;
  final Uint8List signPubKeyBytes;
  final Uint8List encPubKeyBytes;

  HavenE2EEKeys({
    required this.signKeyPair,
    required this.encKeyPair,
    required this.signPubKeyBytes,
    required this.encPubKeyBytes,
  });

  String get signPubKeyHex => OffMeshCrypto.hex(signPubKeyBytes);
  String get encPubKeyHex => OffMeshCrypto.hex(encPubKeyBytes);
  String get idHex => OffMeshCrypto.hex(OffMeshCrypto.idOf(signPubKeyBytes, encPubKeyBytes));
}

class HavenEncryptedEnvelope {
  final String ephPublicKeyHex;
  final String nonceHex;
  final String ciphertextBase64;
  final String signatureHex;
  final String wireBundleBase64;

  HavenEncryptedEnvelope({
    required this.ephPublicKeyHex,
    required this.nonceHex,
    required this.ciphertextBase64,
    required this.signatureHex,
    required this.wireBundleBase64,
  });
}

class HavenE2EEService {
  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();
  final Cipher _aead = Chacha20.poly1305Aead();

  HavenE2EEKeys? _keys;
  HavenE2EEKeys? get keys => _keys;

  /// Generates a fresh device cryptographic identity.
  Future<HavenE2EEKeys> generateIdentity() async {
    final signKeyPair = await _ed25519.newKeyPair();
    final encKeyPair = await _x25519.newKeyPair();

    final signPub = await signKeyPair.extractPublicKey();
    final encPub = await encKeyPair.extractPublicKey();

    final signBytes = Uint8List.fromList(signPub.bytes);
    final encBytes = Uint8List.fromList(encPub.bytes);

    _keys = HavenE2EEKeys(
      signKeyPair: signKeyPair,
      encKeyPair: encKeyPair,
      signPubKeyBytes: signBytes,
      encPubKeyBytes: encBytes,
    );
    return _keys!;
  }

  /// Encrypts a message destined for [recipientEncPubHex] with sender [myKeys].
  Future<HavenEncryptedEnvelope> encryptMessage({
    required String plaintext,
    required String recipientEncPubHex,
    required HavenE2EEKeys myKeys,
  }) async {
    final recipientPubKeyBytes = OffMeshCrypto.unhex(recipientEncPubHex);
    final recipientSimpleKey = SimplePublicKey(recipientPubKeyBytes, type: KeyPairType.x25519);

    // Generate ephemeral X25519 keypair for Perfect Forward Secrecy per message
    final ephKeyPair = await _x25519.newKeyPair();
    final ephPubKey = await ephKeyPair.extractPublicKey();
    final ephPubKeyBytes = Uint8List.fromList(ephPubKey.bytes);

    // Compute Diffie-Hellman shared secret between ephemeral key and recipient's encryption key
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephKeyPair,
      remotePublicKey: recipientSimpleKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();

    // Derive 32-byte encryption key + 12-byte nonce via HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 44);
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecretBytes),
      nonce: utf8.encode('Haven-Couple-E2EE-v1'),
      info: utf8.encode('Handshake-AEAD'),
    );
    final derivedBytes = await derivedKey.extractBytes();
    final aeadKey = SecretKey(derivedBytes.sublist(0, 32));
    final nonce = derivedBytes.sublist(32, 44);

    // Encrypt plaintext with ChaCha20-Poly1305 AEAD
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await _aead.encrypt(
      plaintextBytes,
      secretKey: aeadKey,
      nonce: nonce,
      aad: ephPubKeyBytes,
    );

    final ciphertextWithTag = Uint8List.fromList([...secretBox.cipherText, ...secretBox.mac.bytes]);
    final ciphertextBase64 = base64Encode(ciphertextWithTag);

    // Sign (ephPubKey + ciphertextWithTag) with sender's Ed25519 key
    final signData = Uint8List.fromList([...ephPubKeyBytes, ...ciphertextWithTag]);
    final signature = await _ed25519.sign(signData, keyPair: myKeys.signKeyPair);
    final signatureHex = OffMeshCrypto.hex(signature.bytes);

    // Build standard wire bundle JSON
    final wirePayload = {
      'v': 1,
      'eph': OffMeshCrypto.hex(ephPubKeyBytes),
      'nonce': OffMeshCrypto.hex(nonce),
      'ct': ciphertextBase64,
      'sig': signatureHex,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    final wireBundleBase64 = base64Encode(utf8.encode(jsonEncode(wirePayload)));

    return HavenEncryptedEnvelope(
      ephPublicKeyHex: OffMeshCrypto.hex(ephPubKeyBytes),
      nonceHex: OffMeshCrypto.hex(nonce),
      ciphertextBase64: ciphertextBase64,
      signatureHex: signatureHex,
      wireBundleBase64: wireBundleBase64,
    );
  }

  /// Decrypts a received wire bundle or envelope using recipient's [myKeys].
  Future<String> decryptMessage({
    required String wireBundleBase64,
    required String senderSignPubHex,
    required HavenE2EEKeys myKeys,
  }) async {
    try {
      final decodedJson = utf8.decode(base64Decode(wireBundleBase64));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;

      final ephPubKeyBytes = OffMeshCrypto.unhex(map['eph'] as String);
      final ciphertextWithTag = base64Decode(map['ct'] as String);
      final signatureHex = map['sig'] as String;

      // Verify sender signature
      final senderSignPubBytes = OffMeshCrypto.unhex(senderSignPubHex);
      final signData = Uint8List.fromList([...ephPubKeyBytes, ...ciphertextWithTag]);
      final valid = await _ed25519.verify(
        signData,
        signature: Signature(OffMeshCrypto.unhex(signatureHex), publicKey: SimplePublicKey(senderSignPubBytes, type: KeyPairType.ed25519)),
      );

      if (!valid) {
        throw StateError('Sender signature verification failed (tampered bundle)');
      }

      // Compute shared secret using my X25519 private key and ephemeral public key
      final ephSimpleKey = SimplePublicKey(ephPubKeyBytes, type: KeyPairType.x25519);
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: myKeys.encKeyPair,
        remotePublicKey: ephSimpleKey,
      );
      final sharedSecretBytes = await sharedSecret.extractBytes();

      // Derive symmetric key & nonce
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 44);
      final derivedKey = await hkdf.deriveKey(
        secretKey: SecretKey(sharedSecretBytes),
        nonce: utf8.encode('Haven-Couple-E2EE-v1'),
        info: utf8.encode('Handshake-AEAD'),
      );
      final derivedBytes = await derivedKey.extractBytes();
      final aeadKey = SecretKey(derivedBytes.sublist(0, 32));
      final nonce = derivedBytes.sublist(32, 44);

      // ChaCha20-Poly1305 MAC tag is last 16 bytes
      final cipherTextOnly = ciphertextWithTag.sublist(0, ciphertextWithTag.length - 16);
      final macBytes = ciphertextWithTag.sublist(ciphertextWithTag.length - 16);

      final decryptedBytes = await _aead.decrypt(
        SecretBox(cipherTextOnly, nonce: nonce, mac: Mac(macBytes)),
        secretKey: aeadKey,
        aad: ephPubKeyBytes,
      );

      return utf8.decode(decryptedBytes);
    } catch (e) {
      return '[Encrypted message: could not decrypt ($e)]';
    }
  }
}

final havenCrypto = HavenE2EEService();
