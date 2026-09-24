import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';
import 'crypto.dart';

class NearLinkEngine extends ChangeNotifier {
  static final NearLinkEngine instance = NearLinkEngine._internal();

  // Service UUID for NearLink BLE Mesh Rendezvous
  static final Guid nearlinkBleUuid = Guid('00006e4c-0000-1000-8000-00805f9b34fb');

  // Node identity
  late Contact me;
  final List<Contact> contacts = [];
  final List<MessageItem> messages = [];
  final Map<String, DiscoveredPeer> discoveredPeers = {};

  NearLinkEngine._internal() {
    final rnd = Random(42);
    final signPub = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    final dhPub = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    final cardStr = NearLinkCrypto.formatCard('MobileUser', signPub, dhPub);
    me = NearLinkCrypto.parseCard(cardStr);
  }

  // Backend Gateway configuration
  String backendUrl = 'http://10.0.2.2:3000'; // 10.0.2.2 points to host from Android emulator
  bool isConnectedToBackend = false;
  String latestServerMerkleRoot = '0000000000000000000000000000000000000000000000000000000000000000';
  WebSocketChannel? _wsChannel;

  // BLE state
  bool isBleScanning = false;
  StreamSubscription? _scanSub;

  Future<void> init() async {
    // Add demo contact
    try {
      final demoContact = NearLinkCrypto.parseCard(
        'NL1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw',
      );
      if (!contacts.any((c) => c.idHex == demoContact.idHex)) {
        contacts.add(demoContact);
      }
    } catch (_) {}

    notifyListeners();

    // Start auto BLE scan if supported
    try {
      startBleScan();
    } catch (e) {
      debugPrint('BLE Scan not supported on this host: $e');
    }

    // Try backend connection
    checkBackendHealth();
  }

  // ---------------------------------------------------------------- Messages
  MessageItem sendMessage(Contact recipient, String text) {
    final msgId = NearLinkCrypto.hex(
      NearLinkCrypto.sha256([
        utf8.encode(recipient.idHex),
        utf8.encode(text),
        utf8.encode(DateTime.now().millisecondsSinceEpoch.toString()),
      ]),
    ).substring(0, 32);

    final msg = MessageItem(
      id: msgId,
      toIdHex: recipient.idHex,
      fromIdHex: me.idHex,
      text: text,
      isOutgoing: true,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.queued,
    );

    messages.insert(0, msg);
    notifyListeners();

    // Opportunistically sync to backend if online
    if (isConnectedToBackend) {
      _uploadBundleToGateway(msg);
    }
    return msg;
  }

  void markMessageForwarded(String msgId, [String? relay]) {
    for (final m in messages) {
      if (m.id == msgId && m.status == MessageStatus.queued) {
        m.status = MessageStatus.forwarded;
        m.relayHandoffs++;
      }
    }
    notifyListeners();
  }

  void markMessageDelivered(String msgId) {
    _applyReceiptPrune(msgId);
  }

  void addContact(String cardString) {
    final c = NearLinkCrypto.parseCard(cardString);
    if (!contacts.any((existing) => existing.idHex == c.idHex)) {
      contacts.add(c);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- BLE Radar
  Future<void> startBleScan() async {
    if (isBleScanning) return;
    try {
      isBleScanning = true;
      notifyListeners();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final isMesh = r.advertisementData.serviceUuids.contains(nearlinkBleUuid);
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : 'Bluetooth Device';

          discoveredPeers[r.device.remoteId.str] = DiscoveredPeer(
            name: name,
            address: r.device.remoteId.str,
            rssi: r.rssi,
            lastSeen: DateTime.now(),
            isNearLinkPeer: isMesh,
          );
        }
        notifyListeners();
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint('BLE scan error: $e');
    } finally {
      isBleScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopBleScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    isBleScanning = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Gateway Sync
  Future<void> checkBackendHealth() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/health')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isConnectedToBackend = true;
        latestServerMerkleRoot = data['merkleRootHex'] ?? latestServerMerkleRoot;
        notifyListeners();

        // Connect WebSocket if not connected
        _connectGatewayWs();
      } else {
        isConnectedToBackend = false;
        notifyListeners();
      }
    } catch (_) {
      isConnectedToBackend = false;
      notifyListeners();
    }
  }

  void _connectGatewayWs() {
    try {
      final wsUrl = backendUrl.replaceFirst('http', 'ws');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws?idHex=${me.idHex}'));
      _wsChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data);
            if (msg['type'] == 'ANTI_PACKET_PRUNE') {
              final prunedMsgId = msg['data']['msgIdHex'];
              _applyReceiptPrune(prunedMsgId);
            }
          } catch (_) {}
        },
        onError: (_) {
          isConnectedToBackend = false;
          notifyListeners();
        },
        onDone: () {
          isConnectedToBackend = false;
          notifyListeners();
        },
      );
    } catch (_) {}
  }

  Future<void> syncMerkleTreeWithBackend() async {
    if (!isConnectedToBackend) await checkBackendHealth();
    if (!isConnectedToBackend) return;

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/sync/merkle/reconcile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rootHashHex': latestServerMerkleRoot,
          'dayHashes': {},
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['inSync'] == true) {
          debugPrint('[Merkle] Already synchronized in microseconds');
        } else {
          final missing = data['missingRecords'] as List?;
          if (missing != null) {
            for (final item in missing) {
              _applyReceiptPrune(item['id']);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Merkle sync failed: $e');
    }
  }

  void _uploadBundleToGateway(MessageItem msg) {
    // Demo simulated upload to backend
    Timer(const Duration(milliseconds: 800), () {
      msg.status = MessageStatus.forwarded;
      msg.relayHandoffs++;
      notifyListeners();
    });
  }

  void _applyReceiptPrune(String msgId) {
    for (final m in messages) {
      if (m.id == msgId && m.status != MessageStatus.delivered) {
        m.status = MessageStatus.delivered;
        m.deliveredAtMs = DateTime.now().millisecondsSinceEpoch;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }
}
