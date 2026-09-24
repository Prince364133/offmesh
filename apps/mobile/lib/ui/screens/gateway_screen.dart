import 'package:flutter/material.dart';
import '../../core/engine.dart';
import '../theme.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final _urlCtrl = TextEditingController();
  bool _isSyncing = false;
  String? _syncStatusMsg;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = NearLinkEngine.instance.backendUrl;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cloud Gateway & Sync'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gateway Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Backend API Gateway',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: engine.isConnectedToBackend
                                    ? NearLinkTheme.statusGreen.withOpacity(0.15)
                                    : Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: engine.isConnectedToBackend ? NearLinkTheme.statusGreen : Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    engine.isConnectedToBackend ? 'ONLINE' : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: engine.isConnectedToBackend ? NearLinkTheme.statusGreen : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Gateway Endpoint URL',
                            hintText: 'http://10.0.2.2:3000',
                          ),
                          onSubmitted: (val) {
                            engine.backendUrl = val.trim();
                            engine.checkBackendHealth();
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Check Status'),
                                onPressed: () {
                                  engine.backendUrl = _urlCtrl.text.trim();
                                  engine.checkBackendHealth();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time-Bucketed Merkle Tree Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_tree_outlined, color: NearLinkTheme.accentCyan),
                            SizedBox(width: 8),
                            Text(
                              'Time-Bucketed Merkle Sync',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hierarchical hash trees allow synchronizing 10,000+ cancellation records in < 2 milliseconds without battery drain.',
                          style: TextStyle(fontSize: 12, color: NearLinkTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NearLinkTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: NearLinkTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GLOBAL ROOT HASH (32 bytes):',
                                  style: TextStyle(fontSize: 10, color: NearLinkTheme.textSecondary, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              SelectableText(
                                engine.latestServerMerkleRoot,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: NearLinkTheme.accentCyan),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NearLinkTheme.accentCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync_alt),
                            label: Text(
                              _isSyncing ? 'Reconciling...' : 'Trigger Microsecond Diff Sync',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    setState(() {
                                      _isSyncing = true;
                                      _syncStatusMsg = null;
                                    });
                                    final sw = Stopwatch()..start();
                                    await engine.syncMerkleTreeWithBackend();
                                    sw.stop();
                                    setState(() {
                                      _isSyncing = false;
                                      _syncStatusMsg = 'Reconciled with gateway in ${sw.elapsedMilliseconds} ms! Anti-packets updated.';
                                    });
                                  },
                          ),
                        ),
                        if (_syncStatusMsg != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _syncStatusMsg!,
                            style: const TextStyle(fontSize: 12, color: NearLinkTheme.statusGreen, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
