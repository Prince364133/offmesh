import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'models.dart';

class OffMeshCrypto {
  /// Computes SHA-256 of concatenated byte lists
  static Uint8List sha256(List<List<int>> parts) {
    final output = <int>[];
    for (final p in parts) {
      output.addAll(p);
    }
    return Uint8List.fromList(crypto.sha256.convert(output).bytes);
  }

  /// Converts bytes to lowercase hex string
  static String hex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Converts hex string to byte array
  static Uint8List unhex(String hexStr) {
    final clean = hexStr;
    if (clean.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(clean)) {
      throw const FormatException('Invalid hex');
    }
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Computes Node ID from Ed25519 and X25519 public keys:
  /// id = sha256(signPub || dhPub), matching core Identity.idOf.
  static Uint8List idOf(Uint8List signPub, Uint8List dhPub) {
    if (signPub.length != 32 || dhPub.length != 32) {
      throw const FormatException('Public keys must contain 32 bytes');
    }
    return sha256([signPub, dhPub]);
  }

  /// Parses a canonical contact card NL1:...
  static Contact parseCard(String card) {
    final trimmed = card.trim();
    if (trimmed.length > 178 || !trimmed.startsWith('NL1:')) {
      throw FormatException('Not a valid NearLink card (missing NL1: prefix)');
    }
    final b64 = trimmed.substring(4);
    final normalized = base64Url.normalize(b64);
    final bytes = base64Url.decode(normalized);
    if (base64Url.encode(bytes).replaceAll('=', '') != b64) {
      throw const FormatException('Noncanonical base64');
    }

    if (bytes.length < 2 + 32 + 32) {
      throw FormatException('Card buffer too short');
    }

    var offset = 0;
    final nameLen = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;

    if (nameLen > 64 || offset + nameLen + 32 + 32 != bytes.length) {
      throw FormatException('Malformed card length fields');
    }

    final nameBytes = bytes.sublist(offset, offset + nameLen);
    offset += nameLen;
    final name = utf8.decode(nameBytes);

    final signPub = Uint8List.fromList(bytes.sublist(offset, offset + 32));
    offset += 32;
    final dhPub = Uint8List.fromList(bytes.sublist(offset, offset + 32));
    offset += 32;

    final id = idOf(signPub, dhPub);

    return Contact(
      name: name,
      idHex: hex(id),
      signPubHex: hex(signPub),
      encPubHex: hex(dhPub),
      cardString: trimmed,
    );
  }

  /// Generates canonical card string from components
  static String formatCard(String name, Uint8List signPub, Uint8List dhPub) {
    final nameBytes = utf8.encode(name);
    final nameLen = nameBytes.length;
    if (nameLen > 64 ||
        utf8.decode(nameBytes) != name ||
        signPub.length != 32 ||
        dhPub.length != 32) {
      throw const FormatException('Invalid name or public key length');
    }
    final out = BytesBuilder();
    out.addByte((nameLen >> 8) & 0xff);
    out.addByte(nameLen & 0xff);
    out.add(nameBytes);
    out.add(signPub);
    out.add(dhPub);

    final b64 = base64Url.encode(out.toBytes()).replaceAll('=', '');
    return 'NL1:$b64';
  }

  /// Symmetrical safety code: compare out loud (like Signal's safety numbers)
  static String safetyCode(Uint8List idA, Uint8List idB) {
    if (idA.length != 32 || idB.length != 32) {
      throw const FormatException('Identity hashes must contain 32 bytes');
    }
    final cmp = _compareBytes(idA, idB);
    final lo = cmp <= 0 ? idA : idB;
    final hi = cmp <= 0 ? idB : idA;

    final hash = sha256([utf8.encode('NL-safety'), lo, hi]);

    final hexStr = hex(hash).substring(0, 20);
    // Format into 5-character groups
    final buffer = StringBuffer();
    for (var i = 0; i < hexStr.length; i += 5) {
      if (i > 0) buffer.write(' ');
      buffer.write(hexStr.substring(i, i + 5));
    }
    return buffer.toString();
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    final minLen = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < minLen; i++) {
      final diff = a[i] - b[i];
      if (diff != 0) return diff;
    }
    return a.length - b.length;
  }
}

typedef NearLinkCrypto = OffMeshCrypto;
