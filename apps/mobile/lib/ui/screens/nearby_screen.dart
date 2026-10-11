import 'package:flutter/material.dart';

import '../../core/engine.dart';
import '../theme.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '47700');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = EngineScope.of(context);
    final peers = engine.discoveredPeers.values.toList();
    return Scaffold(
      backgroundColor: OffMeshTheme.background,
      appBar: AppBar(title: const Text('Nearby Devices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Manual TCP exchange',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the address of an existing canonical OffMesh TCP listener on your LAN. '
            'This performs a real foreground NLv1 session. The app does not start a listener, '
            'create a hotspot or discover TCP addresses automatically. '
            'The link is not mutually authenticated; message payloads remain end-to-end sealed.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _host,
            enabled: !engine.isBusy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Peer host or IP address',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _port,
            enabled: !engine.isBusy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'TCP port'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: engine.isBusy ? null : () => _syncTcp(engine),
            icon: engine.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(
              engine.isBusy
                  ? 'Engine operation in progress…'
                  : 'Exchange over TCP',
            ),
          ),
          if (engine.lastSyncResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(engine.lastSyncResult!),
            ),
          if (engine.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                engine.lastError!,
                style: const TextStyle(color: OffMeshTheme.statusError),
              ),
            ),
          const Divider(height: 32),
          const Text(
            'Bluetooth observations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discovery only. Advertised names and service UUIDs are unverified. '
            'No Bluetooth message transport is implemented, and signal strength does not determine distance.',
          ),
          OutlinedButton.icon(
            onPressed: () => engine.isBleScanning
                ? engine.stopBleScan()
                : engine.startBleScan(),
            icon: Icon(
              engine.isBleScanning ? Icons.stop : Icons.bluetooth_searching,
            ),
            label: Text(
              engine.isBleScanning ? 'Stop scan' : 'Scan for 15 seconds',
            ),
          ),
          if (engine.scanError != null)
            Text(
              engine.scanError!,
              style: const TextStyle(color: OffMeshTheme.statusError),
            ),
          Text(
            engine.isBleScanning
                ? 'Scanning…'
                : 'Scan stopped; observations may be stale.',
          ),
          if (peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No Bluetooth observations. Start a scan with Bluetooth enabled and allow the requested permissions.',
              ),
            ),
          for (final peer in peers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth),
              title: Text(peer.name),
              subtitle: Text(
                '${peer.signalStrength} (${peer.rssi} dBm) • ${peer.address}\n'
                '${peer.isNearLinkPeer ? "Advertises OffMesh UUID (unverified)" : "Generic BLE advertisement"}\n'
                'Observed ${peer.lastSeen.toLocal()}',
              ),
              isThreeLine: true,
              // Deliberately no Sync button: scanning cannot establish an NLv1 transport.
            ),
        ],
      ),
    );
  }

  Future<void> _syncTcp(OffMeshEngine engine) async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text);
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid host and port (1–65535).')),
      );
      return;
    }
    try {
      await engine.syncTcp(host, port);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(engine.lastSyncResult!)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('TCP exchange not completed: $e')));
    }
  }
}
