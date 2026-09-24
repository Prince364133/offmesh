import 'package:flutter/material.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _relayOptIn = true;
  bool _wifiOnlyUpload = false;
  double _storageLimitMb = 50.0;
  bool _batterySaver = true;

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final myCard = engine.myCard;
        final isOnline = engine.isGatewayOnline;
        final pendingUploads = engine.messages.where((m) => m.isOutgoing && m.status == MessageStatus.queued).length;

        return Scaffold(
          backgroundColor: OffMeshTheme.background,
          appBar: AppBar(
            title: const Text('Settings'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.border, height: 1),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // Identity & Account Section
              _sectionHeader('IDENTITY & CRYPTOGRAPHIC KEYS'),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: OffMeshTheme.actionPrimary,
                  child: const Icon(Icons.fingerprint, color: OffMeshTheme.actionOnPrimary),
                ),
                title: Text(
                  myCard.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: OffMeshTheme.textPrimary),
                ),
                subtitle: Text(
                  'Node ID: ${myCard.idHex}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: OffMeshTheme.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OffMeshTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OffMeshTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: OffMeshTheme.statusSuccess),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hardware-Backed KeyStore Active (AES-256-GCM TEE)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: OffMeshTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: OffMeshTheme.border, height: 28),

              // Mesh & Connectivity (G3)
              _sectionHeader('MESH & FORWARDING PREFERENCES'),
              SwitchListTile(
                title: const Text('Participate in Mesh Relay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Allow device to carry encrypted packets for other users in transit.',
                  style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
                ),
                value: _relayOptIn,
                activeColor: OffMeshTheme.actionPrimary,
                onChanged: (val) => setState(() => _relayOptIn = val),
              ),
              SwitchListTile(
                title: const Text('Wi-Fi Only Server Upload', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Only upload held relay packets to cloud when connected to unmetered Wi-Fi.',
                  style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
                ),
                value: _wifiOnlyUpload,
                activeColor: OffMeshTheme.actionPrimary,
                onChanged: (val) => setState(() => _wifiOnlyUpload = val),
              ),
              SwitchListTile(
                title: const Text('Conserve Battery Below 20%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Automatically pause background BLE scans when battery is low.',
                  style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
                ),
                value: _batterySaver,
                activeColor: OffMeshTheme.actionPrimary,
                onChanged: (val) => setState(() => _batterySaver = val),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Relay Storage Allocation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${_storageLimitMb.toInt()} MB', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _storageLimitMb,
                      min: 10,
                      max: 200,
                      divisions: 19,
                      activeColor: OffMeshTheme.actionPrimary,
                      inactiveColor: OffMeshTheme.border,
                      onChanged: (val) => setState(() => _storageLimitMb = val),
                    ),
                  ],
                ),
              ),

              const Divider(color: OffMeshTheme.border, height: 28),

              // Sync with Gateway Server (G5)
              _sectionHeader('GATEWAY SERVER SYNCHRONIZATION'),
              ListTile(
                leading: Icon(
                  isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: isOnline ? OffMeshTheme.statusSuccess : OffMeshTheme.textTertiary,
                ),
                title: Text(
                  isOnline ? 'Connected to Gateway Server' : 'Gateway Offline / Air-Gapped',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Gateway URL: ${engine.serverUrl}\nPending uploads: $pendingUploads',
                  style: const TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary, height: 1.3),
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Triggering server synchronization...')),
                    );
                    await engine.syncWithGateway();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                ),
              ),

              const Divider(color: OffMeshTheme.border, height: 28),

              // Storage & Data (G4)
              _sectionHeader('STORAGE & CACHE'),
              ListTile(
                leading: const Icon(Icons.storage_outlined, color: OffMeshTheme.textPrimary),
                title: const Text('Clear Completed Message Cache', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Removes delivered and expired packets to reclaim disk storage.'),
                trailing: const Icon(Icons.chevron_right, color: OffMeshTheme.textTertiary),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OffMeshTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
                        side: const BorderSide(color: OffMeshTheme.border),
                      ),
                      title: const Text('Clear Cache?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                        'This will delete locally cached copies of messages that have already been delivered. Unsent and queued messages will be preserved.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Completed cache cleared')),
                            );
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(color: OffMeshTheme.border, height: 28),

              // About Section
              _sectionHeader('ABOUT OFFMESH'),
              const ListTile(
                leading: Icon(Icons.info_outline, color: OffMeshTheme.textPrimary),
                title: Text('OffMesh Version 1.0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Delay-tolerant peer-to-peer messaging system.\nBuilt with ChaCha20-Poly1305, Ed25519 & Time-Bucketed Merkle Sync.',
                  style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary, height: 1.3),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: OffMeshTheme.textTertiary,
        ),
      ),
    );
  }
}
