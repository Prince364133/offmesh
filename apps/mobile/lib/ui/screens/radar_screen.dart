import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/engine.dart';
import '../theme.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
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
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.radar, color: NearLinkTheme.accentCyan),
                SizedBox(width: 8),
                Text('Mesh Radar'),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  engine.isBleScanning ? Icons.stop_circle_outlined : Icons.refresh,
                  color: engine.isBleScanning ? Colors.redAccent : NearLinkTheme.accentCyan,
                ),
                tooltip: engine.isBleScanning ? 'Stop BLE Scan' : 'Start BLE Scan',
                onPressed: () {
                  if (engine.isBleScanning) {
                    engine.stopBleScan();
                  } else {
                    engine.startBleScan();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Radar animated visualizer
              SizedBox(
                height: 240,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(220, 220),
                        painter: _RadarPainter(
                          progress: _anim.value,
                          peerCount: peers.length,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Status banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: NearLinkTheme.surfaceElevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Radios: ${peers.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: NearLinkTheme.textPrimary),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: engine.isBleScanning ? NearLinkTheme.accentCyan : NearLinkTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          engine.isBleScanning ? 'Scanning BLE...' : 'Idle',
                          style: TextStyle(
                            fontSize: 12,
                            color: engine.isBleScanning ? NearLinkTheme.accentCyan : NearLinkTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Discovered Peers List
              Expanded(
                child: peers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bluetooth_searching, size: 48, color: NearLinkTheme.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'Scanning for nearby mesh devices...\nKeep Bluetooth enabled.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NearLinkTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: peers.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, i) {
                          final p = peers[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: p.isNearLinkPeer
                                    ? NearLinkTheme.accentCyan.withOpacity(0.2)
                                    : NearLinkTheme.surfaceElevated,
                                child: Icon(
                                  p.isNearLinkPeer ? Icons.hub : Icons.bluetooth,
                                  color: p.isNearLinkPeer ? NearLinkTheme.accentCyan : NearLinkTheme.textSecondary,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (p.isNearLinkPeer)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: NearLinkTheme.accentCyan.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'NEARLINK PEER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: NearLinkTheme.accentCyan,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${p.address} • ${p.signalStrength} (${p.rssi} dBm)',
                                style: const TextStyle(fontSize: 12, color: NearLinkTheme.textSecondary),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.sync, color: NearLinkTheme.accentCyan),
                                tooltip: 'Sync with device',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Synchronizing with ${p.name}...')),
                                  );
                                },
                              ),
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
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final int peerCount;

  _RadarPainter({required this.progress, required this.peerCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = NearLinkTheme.border.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric rings
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * (i / 4), ringPaint);
    }

    // Crosshairs
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), ringPaint);

    // Rotating scan beam
    final beamPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          NearLinkTheme.accentCyan.withOpacity(0.0),
          NearLinkTheme.accentCyan.withOpacity(0.3),
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, beamPaint);

    // Center pulse
    final centerPaint = Paint()..color = NearLinkTheme.accentCyan;
    canvas.drawCircle(center, 4, centerPaint);

    // Simulated blips
    if (peerCount > 0) {
      final blipPaint = Paint()..color = NearLinkTheme.accentCyan;
      for (var i = 0; i < peerCount; i++) {
        final angle = (i * 1.618) * math.pi * 2;
        final r = maxRadius * (0.3 + (i % 3) * 0.25);
        final blipOffset = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        canvas.drawCircle(blipOffset, 3.5, blipPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
