import 'package:flutter/material.dart';
import '../../core/haven_engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pinCtrl = TextEditingController();
  final _fakeTitleCtrl = TextEditingController();
  final _fakeBodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = HavenEngine.instance.stealthSettings;
    _pinCtrl.text = settings.decoyPin;
    _fakeTitleCtrl.text = settings.fakeSenderTitle;
    _fakeBodyCtrl.text = settings.fakeBodyPreview;
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _fakeTitleCtrl.dispose();
    _fakeBodyCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final engine = HavenEngine.instance;
    final updated = engine.stealthSettings.copyWith(
      decoyPin: _pinCtrl.text.trim().isNotEmpty ? _pinCtrl.text.trim() : '1234',
      fakeSenderTitle: _fakeTitleCtrl.text.trim().isNotEmpty ? _fakeTitleCtrl.text.trim() : 'System Update',
      fakeBodyPreview: _fakeBodyCtrl.text.trim().isNotEmpty ? _fakeBodyCtrl.text.trim() : 'Sync completed successfully',
    );
    engine.updateStealthSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stealth & notification preferences saved ✨'),
        backgroundColor: OffMeshTheme.passionRose,
      ),
    );
  }

  void _applyPreset(String title, String body) {
    setState(() {
      _fakeTitleCtrl.text = title;
      _fakeBodyCtrl.text = body;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final engine = HavenEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final settings = engine.stealthSettings;
        final user = engine.currentUser;
        final couple = engine.coupleInfo;

        return Scaffold(
          backgroundColor: OffMeshTheme.romanticBackground,
          appBar: AppBar(
            title: const Text('Stealth & Privacy Settings'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check, color: OffMeshTheme.passionRose),
                tooltip: 'Save Settings',
                onPressed: _saveSettings,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // --- HAVEN SANCTUARY MEMBERSHIP & PLAN ($5/MO) ---
              _header('HAVEN SANCTUARY MEMBERSHIP & BILLING'),
              _buildMembershipCard(context, engine),
              const SizedBox(height: 8),

              const Divider(color: OffMeshTheme.borderRomantic),

              // --- 1. APP NAME & ICON DISGUISE ---
              _header('APP NAME & ICON DISGUISE (DEVICE LAUNCHER)'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Change how this app appears on your phone launcher. Choose an icon & name disguise.',
                  style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),

              _buildDisguiseSelector(settings),

              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.password, color: OffMeshTheme.passionRose),
                title: const Text('Sanctuary Security PIN', style: TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: const Text('Confidential PIN for sanctuary protection', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12)),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: OffMeshTheme.textWhite, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    onChanged: (_) => _saveSettings(),
                  ),
                ),
              ),

              const Divider(color: OffMeshTheme.borderRomantic),

              // --- 2. CAMOUFLAGE / GHOST NOTIFICATIONS ---
              _header('CAMOUFLAGE / GHOST NOTIFICATIONS'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Whenever you receive a message from your partner, customize how the notification looks on your lock screen.',
                  style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),

              // Notification Mode Radio Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _modeChip('CAMOUFLAGE', '🎭 Camouflage (Fake Alert)', settings),
                    _modeChip('DISCREET', '🤫 Discreet (Hidden Text)', settings),
                    _modeChip('NINJA', '🥷 Ninja (Silent Badge)', settings),
                    _modeChip('ROMANTIC', '❤️ Romantic Preview', settings),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Presets
              if (settings.notifDisguiseMode == 'CAMOUFLAGE') ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('Quick Camouflage Presets:', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      _presetButton('System Update', '3 items synchronized successfully'),
                      _presetButton('Google Drive', 'Backup finished (4.2 MB)'),
                      _presetButton('Daily Weather', 'Precipitation expected in 20 min'),
                      _presetButton('Calendar', 'Meeting tomorrow at 10:00 AM'),
                      _presetButton('Battery Saver', 'Battery full (100%)'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Custom Fake Title & Body
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _fakeTitleCtrl,
                        style: const TextStyle(color: OffMeshTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'Disguised Notification Title / Sender',
                          hintText: 'e.g. System Update, News, Reminder',
                          prefixIcon: Icon(Icons.title, color: OffMeshTheme.textMuted),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _fakeBodyCtrl,
                        style: const TextStyle(color: OffMeshTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'Disguised Notification Message / Body',
                          hintText: 'e.g. Sync completed successfully',
                          prefixIcon: Icon(Icons.message_outlined, color: OffMeshTheme.textMuted),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // LIVE NOTIFICATION PREVIEW BANNER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildNotificationPreview(settings),
              ),

              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.grey[900],
                        content: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: OffMeshTheme.passionRose),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settings.notifDisguiseMode == 'CAMOUFLAGE'
                                        ? _fakeTitleCtrl.text
                                        : (couple?.partnerName ?? 'Partner'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    settings.notifDisguiseMode == 'CAMOUFLAGE'
                                        ? _fakeBodyCtrl.text
                                        : (settings.notifDisguiseMode == 'DISCREET' ? 'New private message' : 'Hey sweetheart ❤️'),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview, color: OffMeshTheme.passionRose, size: 18),
                  label: const Text('Test Notification Banner Simulation', style: TextStyle(color: OffMeshTheme.passionRose)),
                ),
              ),

              const Divider(color: OffMeshTheme.borderRomantic),

              // --- 3. ZERO-KNOWLEDGE E2EE STATUS ---
              _header('ZERO-KNOWLEDGE ENCRYPTION & PRIVACY'),
              ListTile(
                leading: const Icon(Icons.security, color: OffMeshTheme.statusOnline),
                title: const Text('Server-Side Zero Knowledge', style: TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: const Text(
                  'Messages are stored strictly as encrypted ciphertext on the server. '
                  'Only your partner\'s device has the decryption key.',
                  style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint, color: OffMeshTheme.passionRose),
                title: Text('My Username: @${user?.username ?? "not signed in"}', style: const TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: Text('Device Public Key: ${engine.deviceKeys?.idHex.substring(0, 16) ?? "Ready"}...', style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 12)),
              ),

              const Divider(color: OffMeshTheme.borderRomantic),

              // --- 4. GIRLS' SAFETY & HARASSMENT GUARDIAN ---
              _header('GIRLS\' SAFETY & HARASSMENT GUARDIAN'),
              SwitchListTile(
                secondary: const Icon(Icons.masks, color: OffMeshTheme.passionRose),
                title: const Text('Incognito Ghost Persona', style: TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: Text(
                  engine.isGhostModeActive
                      ? 'Active: Chatting as @${engine.ghostPersona.aliasName}'
                      : 'Disabled: Your real username @${user?.username ?? ""} is visible',
                  style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                ),
                value: engine.isGhostModeActive,
                activeTrackColor: OffMeshTheme.passionRose,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  engine.toggleGhostMode(val);
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: Colors.purpleAccent),
                title: const Text('Customize Ghost Pseudonym', style: TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: Text('Current Alias: @${engine.ghostPersona.aliasName}', style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.edit, color: OffMeshTheme.textMuted, size: 18),
                onTap: () => _editGhostPersonaDialog(context, engine),
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: Text('Blocked Users (${engine.blockedUsers.length})', style: const TextStyle(color: OffMeshTheme.textWhite)),
                subtitle: const Text('Manage severed connections & stop harassment', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: OffMeshTheme.textMuted),
                onTap: () => _showBlockedUsersSheet(context, engine),
              ),
              ListTile(
                leading: const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                title: const Text('Emergency Mutual Chat Nuke', style: TextStyle(color: Colors.orangeAccent)),
                subtitle: const Text('Instantly destroy active conversation messages & media on both sides', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12)),
                onTap: () {
                  final partnerId = couple?.partner.id;
                  if (partnerId != null) {
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        backgroundColor: OffMeshTheme.romanticSurface,
                        title: const Text('Nuke Chat History?', style: TextStyle(color: Colors.orangeAccent)),
                        content: const Text(
                          'This will bidirectionally destroy all messages and media on both devices.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                            onPressed: () async {
                              Navigator.pop(dlgCtx);
                              await engine.nukeConversation(partnerId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('🔥 Conversation nuked!')),
                                );
                              }
                            },
                            child: const Text('Nuke Now', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active paired conversation to nuke.')),
                    );
                  }
                },
              ),

              const Divider(color: OffMeshTheme.borderRomantic),

              // --- 5. ACCOUNT & LOGOUT ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    engine.logout();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out of Sanctuary.')),
                    );
                  },
                  icon: const Icon(Icons.logout, color: OffMeshTheme.statusError),
                  label: const Text('Log Out of Sanctuary', style: TextStyle(color: OffMeshTheme.statusError)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: OffMeshTheme.statusError)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisguiseSelector(StealthSettings settings) {
    final engine = HavenEngine.instance;
    final options = [
      {'key': 'OFFMESH', 'name': 'OffMesh Haven', 'icon': Icons.favorite, 'desc': 'Original Sanctuary'},
      {'key': 'NOTES', 'name': 'Quick Notes', 'icon': Icons.edit_note, 'desc': 'Yellow Notepad'},
      {'key': 'WEATHER', 'name': 'Daily Weather', 'icon': Icons.cloud, 'desc': 'Forecast Widget'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: options.map((opt) {
          final isSelected = settings.appDisguise == opt['key'];
          return GestureDetector(
            onTap: () {
              final updated = settings.copyWith(appDisguise: opt['key'] as String);
              engine.updateStealthSettings(updated);
            },
            child: Container(
              width: 130,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? OffMeshTheme.passionRose.withOpacity(0.15) : OffMeshTheme.romanticSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.borderRomantic,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(opt['icon'] as IconData, color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.textMuted, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    opt['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? OffMeshTheme.textWhite : OffMeshTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt['desc'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: OffMeshTheme.textDarker, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _modeChip(String mode, String label, StealthSettings settings) {
    final isSelected = settings.notifDisguiseMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          final updated = settings.copyWith(notifDisguiseMode: mode);
          HavenEngine.instance.updateStealthSettings(updated);
        }
      },
      selectedColor: OffMeshTheme.passionRose.withOpacity(0.2),
      side: BorderSide(color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.borderRomantic),
      labelStyle: TextStyle(
        color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.textMuted,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _presetButton(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(title, style: const TextStyle(fontSize: 12, color: OffMeshTheme.textWhite)),
        backgroundColor: OffMeshTheme.romanticSurfaceSubtle,
        side: const BorderSide(color: OffMeshTheme.borderRomantic),
        onPressed: () => _applyPreset(title, body),
      ),
    );
  }

  Widget _buildNotificationPreview(StealthSettings settings) {
    String previewTitle;
    String previewBody;

    switch (settings.notifDisguiseMode) {
      case 'CAMOUFLAGE':
        previewTitle = _fakeTitleCtrl.text.isNotEmpty ? _fakeTitleCtrl.text : 'System Update';
        previewBody = _fakeBodyCtrl.text.isNotEmpty ? _fakeBodyCtrl.text : 'Sync completed successfully';
        break;
      case 'DISCREET':
        previewTitle = HavenEngine.instance.coupleInfo?.partnerName ?? 'Partner';
        previewBody = 'New private message received';
        break;
      case 'NINJA':
        previewTitle = 'Notification';
        previewBody = '1 new item';
        break;
      default:
        previewTitle = HavenEngine.instance.coupleInfo?.partnerName ?? 'Partner';
        previewBody = 'Hey sweetheart ❤️';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OffMeshTheme.borderRomantic),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, size: 14, color: OffMeshTheme.textMuted),
              const SizedBox(width: 6),
              const Text('LOCK SCREEN NOTIFICATION PREVIEW', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const Spacer(),
              const Text('now', style: TextStyle(color: OffMeshTheme.textDarker, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: settings.notifDisguiseMode == 'CAMOUFLAGE' ? Colors.blueGrey[800] : OffMeshTheme.passionRose,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  settings.notifDisguiseMode == 'CAMOUFLAGE' ? Icons.settings : Icons.favorite,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(previewTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(previewBody, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard(BuildContext context, HavenEngine engine) {
    final sub = engine.subscription;
    final isSubscribed = sub.isSubscribed;
    final isTrial = sub.isTrialActive;
    final hasChatAccess = sub.hasChatAccess;

    Color badgeColor;
    String badgeText;
    if (isSubscribed) {
      badgeColor = Colors.greenAccent;
      badgeText = 'ACTIVE (\$5/MO)';
    } else if (isTrial) {
      badgeColor = Colors.amber;
      badgeText = 'FREE TRIAL (${sub.trialDaysRemaining}D LEFT)';
    } else {
      badgeColor = Colors.redAccent;
      badgeText = 'TRIAL EXPIRED — INPUT LOCKED';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasChatAccess ? OffMeshTheme.borderRomantic : Colors.redAccent.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OffMeshTheme.passionRose.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haven Sanctuary Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$5.00 / month • First 3 days free',
                      style: TextStyle(
                        color: OffMeshTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isSubscribed
                ? 'Your sanctuary is active! You have unlimited E2EE chat, remote tactile signals (buzz/bell/torch), 7-day R2 ephemeral media, and anti-surveillance protection.'
                : isTrial
                    ? 'You are on your complimentary 3-day free trial on account creation. When the trial ends, chat input will lock until you subscribe for \$5/mo.'
                    : 'Your 3-day free trial has expired. You can view the app and past chats, but chat input is locked. Subscribe to unlock the Sanctuary.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubscribed ? Colors.grey[800] : OffMeshTheme.passionRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (isSubscribed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your Haven Sanctuary subscription is active at \$5/month.'),
                      backgroundColor: OffMeshTheme.passionRose,
                    ),
                  );
                } else {
                  try {
                    await engine.subscribeMonthly();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Subscribed to Haven Sanctuary (\$5/mo)! Chat input unlocked.'),
                          backgroundColor: OffMeshTheme.passionRose,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Subscription error: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(
                isSubscribed ? 'Active Subscription' : 'Unlock Sanctuary for \$5 / Month',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: OffMeshTheme.passionRose,
      ),
    ),
  );

  void _editGhostPersonaDialog(BuildContext context, HavenEngine engine) {
    final aliasCtrl = TextEditingController(text: engine.ghostPersona.aliasName);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.masks, color: OffMeshTheme.passionRose, size: 22),
            SizedBox(width: 8),
            Text('Customize Ghost Persona', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your ghost alias replaces your real username when chatting with unfamiliar users or random boys.',
              style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: aliasCtrl,
              style: const TextStyle(color: OffMeshTheme.textWhite),
              decoration: const InputDecoration(
                labelText: 'Pseudonym / Alias Name',
                prefixText: '@',
                prefixStyle: TextStyle(color: OffMeshTheme.passionRose),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OffMeshTheme.passionRose),
            onPressed: () async {
              final newName = aliasCtrl.text.trim();
              if (newName.isNotEmpty) {
                await engine.updateGhostPersona(aliasName: newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ghost persona updated to @$newName'),
                      backgroundColor: OffMeshTheme.passionRose,
                    ),
                  );
                }
              }
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text('Save Alias', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsersSheet(BuildContext context, HavenEngine engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final blocked = engine.blockedUsers;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: OffMeshTheme.borderRomantic,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.block, color: Colors.redAccent, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Blocked Users (${blocked.length})',
                          style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Blocked users cannot send you messages, trigger signals, or see your activity.',
                      style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: OffMeshTheme.borderRomantic),
                    if (blocked.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No blocked users.',
                            style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: blocked.length,
                          itemBuilder: (ctx, i) {
                            final b = blocked[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.person_off, color: Colors.white, size: 18),
                              ),
                              title: Text(
                                'User #${b.blockedId.length > 8 ? b.blockedId.substring(0, 8) : b.blockedId}',
                                style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 14),
                              ),
                              subtitle: Text(
                                b.reason ?? 'Blocked for safety',
                                style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 11),
                              ),
                              trailing: TextButton(
                                onPressed: () async {
                                  await engine.unblockUser(b.blockedId);
                                  setSheetState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User unblocked')),
                                    );
                                  }
                                },
                                child: const Text('Unblock', style: TextStyle(color: Colors.cyanAccent)),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
