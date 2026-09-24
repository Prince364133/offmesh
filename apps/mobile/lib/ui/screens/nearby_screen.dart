import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final peers = engine.discoveredPeers.values.toList();

        return Scaffold(
          backgroundColor: OffMeshTheme.background,
          appBar: AppBar(
            title: const Text('Nearby Devices'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.border, height: 1),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  if (engine.isBleScanning) {
                    engine.stopBleScan();
                  } else {
                    engine.startBleScan();
                  }
                },
                icon: Icon(
                  engine.isBleScanning ? Icons.stop : Icons.play_arrow,
                  size: 16,
                  color: engine.isBleScanning ? OffMeshTheme.statusError : OffMeshTheme.actionPrimary,
                ),
                label: Text(
                  engine.isBleScanning ? 'Stop' : 'Scan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: engine.isBleScanning ? OffMeshTheme.statusError : OffMeshTheme.actionPrimary,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Minimal Monochrome Radar Visualizer (C1)
              Container(
                height: 230,
                width: double.infinity,
                color: OffMeshTheme.surfaceSubtle,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: _MonochromeRadarPainter(
                          progress: _anim.value,
                          peerCount: peers.length,
                          isScanning: engine.isBleScanning,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Proximity legend & status row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: OffMeshTheme.surface,
                  border: Border(bottom: BorderSide(color: OffMeshTheme.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: engine.isBleScanning ? OffMeshTheme.statusSuccess : OffMeshTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          engine.isBleScanning ? 'Scanning radios active' : 'Scanning paused',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OffMeshTheme.textPrimary),
                        ),
                      ],
                    ),
                    Text(
                      '${peers.length} peer${peers.length == 1 ? "" : "s"} nearby',
                      style: const TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              // Nearby Peers List
              Expanded(
                child: peers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.radar, size: 40, color: OffMeshTheme.textTertiary),
                              const SizedBox(height: 12),
                              const Text(
                                'No peers in range',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: OffMeshTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Keep Bluetooth and Wi-Fi enabled. Other OffMesh devices will appear automatically as people walk by.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: OffMeshTheme.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: peers.length,
                        separatorBuilder: (_, __) => const Divider(color: OffMeshTheme.border, height: 1, indent: 68),
                        itemBuilder: (context, i) {
                          final p = peers[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: p.isNearLinkPeer ? OffMeshTheme.actionPrimary : OffMeshTheme.surfaceSubtle,
                              child: Icon(
                                p.isNearLinkPeer ? Icons.hub : Icons.bluetooth,
                                size: 18,
                                color: p.isNearLinkPeer ? OffMeshTheme.actionOnPrimary : OffMeshTheme.textSecondary,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: OffMeshTheme.textPrimary),
                                  ),
                                ),
                                if (p.isNearLinkPeer)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: OffMeshTheme.actionSecondary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'MESH PEER',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OffMeshTheme.actionSecondaryText),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${p.signalStrength} (${p.rssi} dBm) • ${p.address}',
                              style: const TextStyle(fontSize: 11, color: OffMeshTheme.textSecondary),
                            ),
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () => _showSyncProgressModal(context, p),
                              child: const Text('Sync', style: TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSyncProgressModal(BuildContext context, DiscoveredPeer peer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OffMeshTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: OffMeshTheme.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Reconciling with ${peer.name}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: OffMeshTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Microsecond Merkle Tree anti-entropy reconciliation (C4):',
                  style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                _syncStageRow(1, 'Secure link & mutual authentication', true),
                _syncStageRow(2, 'Exchange Time-Bucketed Merkle Roots (32 B)', true),
                _syncStageRow(3, 'Anti-packet reconciliation & local pruning', true),
                _syncStageRow(4, 'Compare pending forwarding queues', true),
                _syncStageRow(5, 'Encrypted bundle payload transit', true),
                _syncStageRow(6, 'Mutual session completion', true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Synchronized successfully with ${peer.name}')),
                          );
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _syncStageRow(int step, String title, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? OffMeshTheme.actionPrimary : OffMeshTheme.surfaceSubtle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: completed ? OffMeshTheme.actionOnPrimary : OffMeshTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
                color: OffMeshTheme.textPrimary,
              ),
            ),
          ),
          if (completed)
            const Icon(Icons.check, size: 14, color: OffMeshTheme.statusSuccess),
        ],
      ),
    );
  }
}

class _MonochromeRadarPainter extends CustomPainter {
  final double progress;
  final int peerCount;
  final bool isScanning;

  _MonochromeRadarPainter({
    required this.progress,
    required this.peerCount,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = OffMeshTheme.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric range rings: Immediate (<2m), Near (<10m), Far (<30m)
    canvas.drawCircle(center, maxRadius * 0.33, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.66, ringPaint);
    canvas.drawCircle(center, maxRadius, ringPaint);

    // Crosshairs
    final crossHairPaint = Paint()
      ..color = OffMeshTheme.border
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crossHairPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crossHairPaint);

    // Rotating scan beam (Restrained Monochrome)
    if (isScanning) {
      final beamPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi * 2,
          colors: [
            OffMeshTheme.actionPrimary.withOpacity(0.0),
            OffMeshTheme.actionPrimary.withOpacity(0.15),
          ],
          stops: const [0.75, 1.0],
          transform: GradientRotation(progress * math.pi * 2),
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

      canvas.drawCircle(center, maxRadius, beamPaint);
    }

    // Center marker (My Phone)
    final centerPaint = Paint()..color = OffMeshTheme.actionPrimary;
    canvas.drawCircle(center, 4, centerPaint);

    // Detected peer markers
    if (peerCount > 0) {
      final peerPaint = Paint()..color = OffMeshTheme.actionPrimary;
      for (var i = 0; i < peerCount; i++) {
        final angle = (i * 1.618) * math.pi * 2;
        final r = maxRadius * (0.25 + (i % 3) * 0.28);
        final blipOffset = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        canvas.drawCircle(blipOffset, 4, peerPaint);

        // Subtle outer pulse on peer
        final pulsePaint = Paint()
          ..color = OffMeshTheme.borderStrong
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(blipOffset, 7, pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonochromeRadarPainter old) => true;
}
