import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/haven_engine.dart';
import '../../core/models.dart';
import '../theme.dart';
import 'couple_pairing_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  MessageItem? _replyingTo;
  StreamSubscription? _signalSub;
  bool _isRecordingVoice = false;
  int _voiceRecordingSeconds = 0;
  Timer? _voiceTimer;
  bool _voiceIsViewOnce = false;

  // Active audio player playback state
  String? _playingVoiceMsgId;
  int _voicePlaybackSeconds = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _signalSub = HavenEngine.instance.signalEvents.listen((event) {
      if (!mounted) return;
      final signalType = event['signalType'] as String? ?? '';
      final fromName = event['fromName'] as String? ?? 'Your partner';
      String msg = '';
      IconData icon = Icons.notifications;

      if (signalType == 'BUZZ') {
        msg = '$fromName sent you a heartbeat buzz! 📳';
        icon = Icons.vibration;
      } else if (signalType == 'RING') {
        msg = '$fromName triggered an emergency ringtone and vibration alarm! 🚨🔔';
        icon = Icons.notifications_active;
      } else if (signalType == 'FLASHLIGHT') {
        msg = '$fromName turned on your flashlight! 🔦';
        icon = Icons.flash_on;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: OffMeshTheme.passionRose,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    _voiceTimer?.cancel();
    _playbackTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startVoiceRecording() {
    final haven = HavenEngine.instance;
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    setState(() {
      _isRecordingVoice = true;
      _voiceRecordingSeconds = 0;
      _voiceIsViewOnce = false;
    });
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _voiceRecordingSeconds++);
      }
    });
  }

  Future<void> _stopAndSendVoice(Contact recipient) async {
    _voiceTimer?.cancel();
    final duration = _voiceRecordingSeconds > 0 ? _voiceRecordingSeconds : 2;
    final isViewOnce = _voiceIsViewOnce;
    setState(() {
      _isRecordingVoice = false;
      _voiceIsViewOnce = false;
    });

    try {
      // Simulate ephemeral voice note upload with 7-day TTL
      final dummyAudioBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      await HavenEngine.instance.uploadEphemeralMedia(
        filename: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/m4a',
        bytes: dummyAudioBytes,
        blockSaving: HavenEngine.instance.myPermissions.blockSaving,
        durationSeconds: duration,
        maxViews: isViewOnce ? 1 : 0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice note: $e')),
        );
      }
    }
  }

  void _cancelVoiceRecording() {
    _voiceTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _voiceIsViewOnce = false;
    });
  }

  void _togglePlayVoiceNote(MessageItem msg, HavenEngine haven) {
    if (msg.isConsumed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This View Once voice note has already expired')),
      );
      return;
    }

    if (_playingVoiceMsgId == msg.id) {
      _playbackTimer?.cancel();
      setState(() => _playingVoiceMsgId = null);
      return;
    }

    _playbackTimer?.cancel();
    setState(() {
      _playingVoiceMsgId = msg.id;
      _voicePlaybackSeconds = 0;
    });

    final totalSeconds = (msg.audioDuration != null && msg.audioDuration! > 0) ? msg.audioDuration! : 5;
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_playingVoiceMsgId != msg.id) {
        timer.cancel();
        return;
      }

      setState(() => _voicePlaybackSeconds++);

      if (_voicePlaybackSeconds >= totalSeconds) {
        timer.cancel();
        setState(() {
          _playingVoiceMsgId = null;
          _voicePlaybackSeconds = 0;
        });

        // View Once voice notes self-destruct upon listening
        if (msg.maxViews == 1) {
          await haven.consumeMediaView(msg.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('👁️ View Once voice note has expired and self-destructed'),
                backgroundColor: OffMeshTheme.passionRose,
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _sendMessage(Contact recipient) async {
    final haven = HavenEngine.instance;
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await haven.sendMessage(
        recipient,
        text,
        replyToId: _replyingTo?.id,
        replyToText: _replyingTo != null
            ? (_replyingTo!.text.length > 40 ? '${_replyingTo!.text.substring(0, 40)}...' : _replyingTo!.text)
            : null,
      );
      _textCtrl.clear();
      setState(() => _replyingTo = null);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _sendQuickReaction(Contact recipient, String emoji) {
    final haven = HavenEngine.instance;
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    haven.sendMessage(recipient, emoji);
  }

  void _showChatSettingsSheet(BuildContext context, HavenEngine haven) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final myPerms = haven.myPermissions;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
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
                      const Row(
                        children: [
                          Icon(Icons.security, color: OffMeshTheme.passionRose, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Chat Privacy & Permissions',
                            style: TextStyle(
                              color: OffMeshTheme.textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Control what your partner can remotely trigger and protect chat privacy.',
                        style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: OffMeshTheme.borderRomantic),
                      const Text(
                        'PARTNER REMOTE HARDWARE CONSENT',
                        style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow partner to vibrate phone', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Partner can buzz you with heartbeat pulses', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.allowVibrate,
                        activeTrackColor: OffMeshTheme.passionRose,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(allowVibrate: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow partner emergency alarm & ringtone', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Partner can trigger an emergency ringtone and vibration alarm by holding for 3s', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.allowRing,
                        activeTrackColor: Colors.redAccent,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(allowRing: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow partner to pulse flashlight', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Partner can turn on your camera torch for 2.5s', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.allowFlashlight,
                        activeTrackColor: OffMeshTheme.passionRose,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(allowFlashlight: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      const Divider(color: OffMeshTheme.borderRomantic),
                      const Text(
                        'ANTI-SURVEILLANCE & MEDIA SECURITY',
                        style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Block screenshots & app preview', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Natively enforces Android FLAG_SECURE', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.blockScreenshots,
                        activeTrackColor: OffMeshTheme.passionRose,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(blockScreenshots: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Block saving photos & videos', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Recipients can only view media inside the app', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.blockSaving,
                        activeTrackColor: OffMeshTheme.passionRose,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(blockSaving: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Block copying message text', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 14)),
                        subtitle: const Text('Disables clipboard export of confidential texts', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                        value: myPerms.blockCopying,
                        activeTrackColor: OffMeshTheme.passionRose,
                        activeThumbColor: Colors.white,
                        onChanged: (val) async {
                          final updated = myPerms.copyWith(blockCopying: val);
                          await haven.updatePermissions(updated);
                          setModalState(() {});
                        },
                      ),
                      const Divider(color: OffMeshTheme.borderRomantic),
                      const Text(
                        'CHAT WALLPAPER',
                        style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildWallpaperChoice(ctx, 'Velvet', null),
                          const SizedBox(width: 8),
                          _buildWallpaperChoice(ctx, 'Rose', 'preset_rose'),
                          const SizedBox(width: 8),
                          _buildWallpaperChoice(ctx, 'Stars', 'preset_stars'),
                          const SizedBox(width: 8),
                          _buildWallpaperChoice(ctx, 'Black', 'preset_black'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWallpaperChoice(BuildContext context, String label, String? key) {
    final haven = HavenEngine.instance;
    final isSelected = haven.chatCustomization.wallpaperUrl == key;

    return Expanded(
      child: InkWell(
        onTap: () {
          haven.updateChatCustomization(wallpaperUrl: key);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? OffMeshTheme.passionRose.withOpacity(0.2) : OffMeshTheme.romanticSurfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.borderRomantic,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? OffMeshTheme.passionRose : OffMeshTheme.textWhite,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showPlusActionsSheet(BuildContext context, HavenEngine haven, Contact recipient) {
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    final partnerPerms = haven.partnerPermissions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OffMeshTheme.borderRomantic,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Partner Remote Actions & Media',
                  style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.vibration,
                      label: 'Buzz Phone',
                      color: Colors.amber,
                      enabled: partnerPerms.allowVibrate,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await haven.sendRemoteSignal('BUZZ');
                          messenger.showSnackBar(
                            const SnackBar(content: Text('📳 Heartbeat buzz sent to partner phone!')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      },
                    ),
                    _HoldToRingAlarmButton(
                      enabled: partnerPerms.allowRing,
                      messenger: ScaffoldMessenger.of(context),
                      onTriggered: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await haven.sendRemoteSignal('RING');
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('🚨 Emergency ringtone & vibration alarm triggered on partner device!'),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.flash_on,
                      label: 'Torch Pulse',
                      color: Colors.orangeAccent,
                      enabled: partnerPerms.allowFlashlight,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await haven.sendRemoteSignal('FLASHLIGHT');
                          messenger.showSnackBar(
                            const SnackBar(content: Text('🔦 Partner camera flashlight turned on!')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.photo_library,
                      label: 'Photos',
                      color: OffMeshTheme.passionRose,
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _promptSendEphemeralPhoto(context, haven);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.videocam,
                      label: 'Video',
                      color: Colors.blueAccent,
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _promptSendEphemeralVideo(context, haven);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.mic,
                      label: 'Voice Note',
                      color: Colors.purpleAccent,
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _startVoiceRecording();
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.favorite,
                      label: 'Love Heart',
                      color: Colors.pink,
                      enabled: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendQuickReaction(recipient, '❤️');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label is disabled by partner\'s chat settings')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 86,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitExceededAlert(BuildContext context, {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OffMeshTheme.passionRose),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _promptSendEphemeralPhoto(BuildContext context, HavenEngine haven, {int initialCount = 1}) {
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    bool blockSaving = true;
    int maxViews = 1;
    bool watermarkEnabled = true;
    int selectedCount = initialCount;
    final countCtrl = TextEditingController(text: initialCount.toString());

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              backgroundColor: OffMeshTheme.romanticSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: OffMeshTheme.passionRose, size: 22),
                  SizedBox(width: 8),
                  Text('N-View Ephemeral Photo', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set self-destruction limits to prevent photos from lingering or leaking.',
                      style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NUMBER OF IMAGES',
                      style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: countCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Number of photos to share',
                        hintStyle: const TextStyle(color: OffMeshTheme.textMuted),
                        filled: true,
                        fillColor: OffMeshTheme.romanticSurfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: OffMeshTheme.borderRomantic),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val) ?? 1;
                        selectedCount = parsed;
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'MAX VIEW LIMIT',
                      style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: OffMeshTheme.romanticSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OffMeshTheme.borderRomantic),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: maxViews,
                          isExpanded: true,
                          dropdownColor: OffMeshTheme.romanticSurface,
                          style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('👁️ 1 View (Self-destruct after 1st view)')),
                            DropdownMenuItem(value: 2, child: Text('👁️ 2 Views (Self-destruct after 2 views)')),
                            DropdownMenuItem(value: 3, child: Text('👁️ 3 Views (Self-destruct after 3 views)')),
                            DropdownMenuItem(value: 4, child: Text('👁️ 4 Views (Self-destruct after 4 views)')),
                            DropdownMenuItem(value: 5, child: Text('👁️ 5 Views (Self-destruct after 5 views)')),
                            DropdownMenuItem(value: 0, child: Text('⏳ 7-Day Ephemeral (Unlimited for 7 days)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => maxViews = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anti-Leak Steganographic Watermark', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13)),
                      subtitle: const Text('Overlays recipient ID diagonally to prevent 2nd phone camera leaks', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                      value: watermarkEnabled,
                      activeColor: OffMeshTheme.passionRose,
                      onChanged: (val) {
                        setDlgState(() => watermarkEnabled = val ?? true);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Block Saving to Device Gallery', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13)),
                      subtitle: const Text('Recipient cannot export or save photo', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                      value: blockSaving,
                      activeColor: OffMeshTheme.passionRose,
                      onChanged: (val) {
                        setDlgState(() => blockSaving = val ?? true);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: OffMeshTheme.passionRose),
                  onPressed: () async {
                    Navigator.pop(dlgCtx);
                    int countToSend = selectedCount > 0 ? selectedCount : 1;
                    if (countToSend > 50) {
                      _showLimitExceededAlert(
                        context,
                        title: 'Selection Limit Exceeded',
                        message: 'A maximum of 50 images can be shared at once. Only the first 50 images will be sent.',
                      );
                      countToSend = 50;
                    }
                    for (int i = 0; i < countToSend; i++) {
                      final dummyBytes = Uint8List.fromList([1, 2, 3, 4 + i]);
                      await haven.uploadEphemeralMedia(
                        filename: 'ephemeral_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                        mimeType: 'image/jpeg',
                        bytes: dummyBytes,
                        blockSaving: blockSaving,
                        maxViews: maxViews,
                        watermarkEnabled: watermarkEnabled,
                      );
                    }
                  },
                  child: const Text('Send Protected Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptSendEphemeralVideo(BuildContext context, HavenEngine haven) {
    if (!haven.subscription.hasChatAccess) {
      _showSubscriptionPaywallSheet(context, haven);
      return;
    }
    bool blockSaving = true;
    int maxViews = 1;
    bool watermarkEnabled = true;
    int durationSec = 60;
    final durationCtrl = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              backgroundColor: OffMeshTheme.romanticSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.blueAccent, size: 22),
                  SizedBox(width: 8),
                  Text('Share Protected Video', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share encrypted video with automatic 7-day or N-view self-destruction.',
                      style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'MAX VIEW LIMIT',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: OffMeshTheme.romanticSurfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: OffMeshTheme.borderRomantic),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: maxViews,
                          isExpanded: true,
                          dropdownColor: OffMeshTheme.romanticSurface,
                          style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('👁️ 1 View (Self-destruct after 1st view)')),
                            DropdownMenuItem(value: 2, child: Text('👁️ 2 Views (Self-destruct after 2 views)')),
                            DropdownMenuItem(value: 3, child: Text('👁️ 3 Views (Self-destruct after 3 views)')),
                            DropdownMenuItem(value: 4, child: Text('👁️ 4 Views (Self-destruct after 4 views)')),
                            DropdownMenuItem(value: 5, child: Text('👁️ 5 Views (Self-destruct after 5 views)')),
                            DropdownMenuItem(value: 0, child: Text('⏳ 7-Day Ephemeral (Unlimited for 7 days)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => maxViews = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'DURATION (SECONDS)',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Duration in seconds',
                        hintStyle: const TextStyle(color: OffMeshTheme.textMuted),
                        filled: true,
                        fillColor: OffMeshTheme.romanticSurfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: OffMeshTheme.borderRomantic),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val) ?? 60;
                        durationSec = parsed;
                      },
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anti-Leak Watermark', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13)),
                      subtitle: const Text('Overlays recipient ID diagonally to prevent leaks', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                      value: watermarkEnabled,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setDlgState(() => watermarkEnabled = val ?? true);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Block Saving to Device Gallery', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13)),
                      subtitle: const Text('Recipient cannot export or save video', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                      value: blockSaving,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setDlgState(() => blockSaving = val ?? true);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    Navigator.pop(dlgCtx);
                    int finalSec = durationSec > 0 ? durationSec : 60;
                    if (finalSec > 300) {
                      finalSec = 300;
                      _showLimitExceededAlert(
                        context,
                        title: 'Video Clipped to 5 Minutes',
                        message: 'Videos are capped at a maximum of 5 minutes. This video has automatically been clipped to 5:00 minutes.',
                      );
                    }
                    final dummyBytes = Uint8List.fromList([5, 6, 7, 8]);
                    await haven.uploadEphemeralMedia(
                      filename: 'ephemeral_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
                      mimeType: 'video/mp4',
                      bytes: dummyBytes,
                      blockSaving: blockSaving,
                      maxViews: maxViews,
                      durationSeconds: finalSec,
                      watermarkEnabled: watermarkEnabled,
                    );
                  },
                  child: const Text('Send Protected Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessageOptions(BuildContext context, MessageItem msg, HavenEngine haven) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: OffMeshTheme.passionRose),
                title: const Text('Reply to message', style: TextStyle(color: OffMeshTheme.textWhite)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = msg);
                },
              ),
              if (msg.isOutgoing && !msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blueAccent),
                  title: const Text('Edit message', style: TextStyle(color: OffMeshTheme.textWhite)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptEditMessage(context, msg, haven);
                  },
                ),
              if (!msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.amber),
                  title: const Text('Copy message', style: TextStyle(color: OffMeshTheme.textWhite)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (haven.myPermissions.blockCopying) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Copying is blocked by Chat Privacy Settings')),
                      );
                    } else {
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied to clipboard')),
                      );
                    }
                  },
                ),
              if (msg.mediaUrl != null && !msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.greenAccent),
                  title: const Text('Save to Gallery', style: TextStyle(color: OffMeshTheme.textWhite)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (msg.blockSaving || haven.myPermissions.blockSaving) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🚫 Saving is blocked by the sender')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved to device gallery')),
                      );
                    }
                  },
                ),
              if (!msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Unsend / Delete message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    haven.deleteMessage(msg.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _promptEditMessage(BuildContext context, MessageItem msg, HavenEngine haven) {
    final editCtrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OffMeshTheme.romanticSurface,
          title: const Text('Edit Message', style: TextStyle(color: OffMeshTheme.textWhite)),
          content: TextField(
            controller: editCtrl,
            style: const TextStyle(color: OffMeshTheme.textWhite),
            decoration: const InputDecoration(hintText: 'Edit your message...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: OffMeshTheme.passionRose),
              onPressed: () {
                haven.editMessage(msg.id, editCtrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final haven = HavenEngine.instance;

    return ListenableBuilder(
      listenable: haven,
      builder: (context, _) {
        final couple = haven.coupleInfo;
        final isPaired = haven.isPaired;
        final messages = haven.messages;
        final partnerContact = haven.contacts.isNotEmpty
            ? haven.contacts.first
            : (couple != null
                ? Contact(
                    name: couple.partnerName,
                    idHex: couple.partner.id,
                    signPubHex: couple.partner.signPublicKey,
                    encPubHex: couple.partner.encPublicKey,
                    cardString: '',
                  )
                : null);
        final hasChatAccess = haven.subscription.hasChatAccess;

        return Scaffold(
          backgroundColor: OffMeshTheme.romanticBackground,
          appBar: AppBar(
            backgroundColor: OffMeshTheme.romanticBackground,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: OffMeshTheme.textWhite),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: isPaired && couple != null
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: OffMeshTheme.passionRose,
                        child: Text(
                          couple.partnerName.isNotEmpty ? couple.partnerName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                couple.partnerName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: OffMeshTheme.textWhite),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 14),
                            ],
                          ),
                          Text(
                            couple.daysTogether != null
                                ? 'Together for ${couple.daysTogether} days 💕'
                                : 'E2EE Couple Sanctuary',
                            style: const TextStyle(fontSize: 11, color: OffMeshTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 22),
                      SizedBox(width: 8),
                      Text('Sanctuary', style: TextStyle(color: OffMeshTheme.textWhite, fontWeight: FontWeight.bold)),
                    ],
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: OffMeshTheme.passionRose),
                tooltip: 'Girls\' Safety & Harassment Shield',
                onPressed: () => _showSafetyShieldMenu(context, haven),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: OffMeshTheme.passionRose),
                tooltip: 'Chat Settings & Permissions',
                onPressed: () => _showChatSettingsSheet(context, haven),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.borderRomantic, height: 1),
            ),
          ),
          body: Container(
            decoration: _buildWallpaperDecoration(haven.chatCustomization.wallpaperUrl),
            child: Column(
              children: [
                // If not paired yet, show banner to invite partner
                if (!isPaired)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OffMeshTheme.romanticSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_border, color: OffMeshTheme.passionRose),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Connect with your partner using their private @username.',
                            style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CouplePairingScreen()),
                            );
                          },
                          child: const Text('Find Love', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // Messages List
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: OffMeshTheme.passionRose.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 48),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your Secret Sanctuary',
                                style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'End-to-end encrypted. Zero server leaks.\nSend a love note below 💕',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return GestureDetector(
                              onLongPress: () => _showMessageOptions(context, msg, haven),
                              child: _buildMessageBubble(msg),
                            );
                          },
                        ),
                ),

                // Replying Preview Banner
                if (_replyingTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: OffMeshTheme.romanticSurfaceSubtle,
                    child: Row(
                      children: [
                        const Icon(Icons.reply, color: OffMeshTheme.passionRose, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Replying to message:', style: TextStyle(color: OffMeshTheme.passionRose, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                _replyingTo!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: OffMeshTheme.textMuted, size: 18),
                          onPressed: () => setState(() => _replyingTo = null),
                        ),
                      ],
                    ),
                  ),

                // Quick Love Reactions Bar (Only enabled if subscription is active)
                if (partnerContact != null && !_isRecordingVoice && hasChatAccess)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['❤️', '💕', '🥰', '🌹', '✨', '😘', '💍'].map((emoji) {
                        return GestureDetector(
                          onTap: () => _sendQuickReaction(partnerContact, emoji),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        );
                      }).toList(),
                    ),
                  ),

                // Input Bar with WhatsApp-style UX OR Locked Paywall Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: OffMeshTheme.romanticSurface,
                    border: Border(top: BorderSide(color: OffMeshTheme.borderRomantic, width: 1)),
                  ),
                  child: SafeArea(
                    child: !hasChatAccess
                        ? _buildLockedChatInputBar(context, haven)
                        : _isRecordingVoice
                            ? Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: _cancelVoiceRecording,
                                  ),
                                  const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recording audio... 0:${_voiceRecordingSeconds.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  // WhatsApp-style View Once (1) toggle
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _voiceIsViewOnce = !_voiceIsViewOnce);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 1),
                                          content: Text(_voiceIsViewOnce
                                              ? '👁️ Voice note set to View Once (1 View)'
                                              : 'Voice note set to standard delivery'),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: _voiceIsViewOnce ? OffMeshTheme.passionRose : Colors.white24,
                                        border: Border.all(
                                          color: _voiceIsViewOnce ? Colors.white : Colors.white38,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.looks_one, color: _voiceIsViewOnce ? Colors.white : Colors.white70, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '1 View',
                                            style: TextStyle(
                                              color: _voiceIsViewOnce ? Colors.white : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: OffMeshTheme.passionRose,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: () {
                                      if (partnerContact != null) _stopAndSendVoice(partnerContact);
                                    },
                                    child: const Text('Send Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  // Plus Action Button
                                  IconButton(
                                    icon: const Icon(Icons.add_circle, color: OffMeshTheme.passionRose, size: 28),
                                    onPressed: () {
                                      if (partnerContact != null) {
                                        _showPlusActionsSheet(context, haven, partnerContact);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please connect with your partner first.')),
                                        );
                                      }
                                    },
                                  ),
                                  // Universal Keyboard Input with Sticker Insertion support
                                  Expanded(
                                    child: TextField(
                                      controller: _textCtrl,
                                      style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 15),
                                      maxLines: null,
                                      textInputAction: TextInputAction.send,
                                      contentInsertionConfiguration: ContentInsertionConfiguration(
                                        allowedMimeTypes: const ['image/png', 'image/gif', 'image/jpeg', 'image/webp'],
                                        onContentInserted: (KeyboardInsertedContent data) async {
                                          // Sticker insertion from Gboard, SwiftKey, iOS Keyboard!
                                          if (data.data != null && partnerContact != null) {
                                            await haven.uploadEphemeralMedia(
                                              filename: 'sticker_${DateTime.now().millisecondsSinceEpoch}.png',
                                              mimeType: data.mimeType,
                                              bytes: data.data!,
                                            );
                                          }
                                        },
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (_) {
                                        if (partnerContact != null) _sendMessage(partnerContact);
                                      },
                                      decoration: InputDecoration(
                                        hintText: isPaired ? 'Message your love...' : 'Send secret message...',
                                        hintStyle: const TextStyle(color: OffMeshTheme.textDarker),
                                        fillColor: OffMeshTheme.romanticSurfaceSubtle,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Voice or Send Button
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: OffMeshTheme.passionRose,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: _sending
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Icon(
                                              _textCtrl.text.trim().isEmpty ? Icons.mic : Icons.send,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                      onPressed: () {
                                        if (partnerContact == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Please connect with your partner first.')),
                                          );
                                          return;
                                        }
                                        if (_textCtrl.text.trim().isEmpty) {
                                          _startVoiceRecording();
                                        } else {
                                          _sendMessage(partnerContact);
                                        }
                                      },
                                    ),
                                  ),
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

  Widget _buildLockedChatInputBar(BuildContext context, HavenEngine haven) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OffMeshTheme.romanticSurfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: OffMeshTheme.passionRose.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: OffMeshTheme.passionRose, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '3-Day Free Trial Expired',
                  style: TextStyle(
                    color: OffMeshTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Chat input is locked. Unlock Sanctuary for \$5/mo.',
                  style: TextStyle(
                    color: OffMeshTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OffMeshTheme.passionRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showSubscriptionPaywallSheet(context, haven),
            child: const Text(
              'Unlock (\$5/mo)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionPaywallSheet(BuildContext context, HavenEngine haven) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sub = haven.subscription;
            final isBusy = haven.isBusy;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: OffMeshTheme.passionRose.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 36),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unlock Haven Sanctuary',
                        style: TextStyle(
                          color: OffMeshTheme.textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.isTrialActive
                            ? 'Your 3-day free trial has ${sub.trialDaysRemaining} day(s) remaining.'
                            : 'Your 3-day free trial has ended. Subscribe to unlock chat input.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: OffMeshTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: OffMeshTheme.romanticSurfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.6)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Haven Sanctuary Plan',
                                  style: TextStyle(
                                    color: OffMeshTheme.textWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: OffMeshTheme.passionRose,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '\$5.00 / month',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: OffMeshTheme.borderRomantic),
                            const SizedBox(height: 8),
                            _buildFeatureRow(Icons.lock, 'Unlimited End-to-End Encrypted Couple Chat'),
                            _buildFeatureRow(Icons.vibration, 'Remote Partner Signals (Buzz, Bell, Torch)'),
                            _buildFeatureRow(Icons.hourglass_bottom, '7-Day Ephemeral Media with Save Blocking'),
                            _buildFeatureRow(Icons.security, 'Anti-Surveillance FLAG_SECURE Protection'),
                            _buildFeatureRow(Icons.bluetooth, 'Offline Bluetooth Mesh Chat Fallback'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OffMeshTheme.passionRose,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isBusy
                              ? null
                              : () async {
                                  try {
                                    setSheetState(() {});
                                    await haven.subscribeMonthly();
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('🎉 Welcome to Haven Sanctuary! Unlimited chat unlocked.'),
                                          backgroundColor: OffMeshTheme.passionRose,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text('Subscription failed: $e')),
                                      );
                                    }
                                  }
                                },
                          child: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Subscribe for \$5 / month',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Renews monthly at \$5. Cancel anytime. First 3 days free upon account creation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: OffMeshTheme.textDarker, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: OffMeshTheme.passionRose, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildWallpaperDecoration(String? wallpaperKey) {
    if (wallpaperKey == 'preset_rose') {
      return const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF200914), Color(0xFF0B0B10)],
          radius: 1.2,
        ),
      );
    } else if (wallpaperKey == 'preset_stars') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF130E26), Color(0xFF07060E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (wallpaperKey == 'preset_black') {
      return const BoxDecoration(color: Color(0xFF050508));
    }

    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF100B14), Color(0xFF08060B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _buildMessageBubble(MessageItem msg) {
    final haven = HavenEngine.instance;
    final isOut = msg.isOutgoing;
    final timeStr = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(msg.timestampMs));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isOut
                  ? const LinearGradient(
                      colors: [OffMeshTheme.bubbleOutgoing, OffMeshTheme.bubbleOutgoingEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isOut ? null : OffMeshTheme.bubbleIncoming,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(OffMeshTheme.radiusBubble),
                topRight: const Radius.circular(OffMeshTheme.radiusBubble),
                bottomLeft: Radius.circular(isOut ? OffMeshTheme.radiusBubble : 4),
                bottomRight: Radius.circular(isOut ? 4 : OffMeshTheme.radiusBubble),
              ),
              boxShadow: isOut
                  ? [
                      BoxShadow(
                        color: OffMeshTheme.passionRose.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Quoted reply banner
                if (msg.replyToText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                    ),
                    child: Text(
                      msg.replyToText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),

                // Self-Destructed Media Placeholder
                if (msg.isConsumed) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_delete, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '💥 Photo Self-Destructed (View limit reached)',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ] else if (msg.mediaUrl != null && (msg.mediaMimeType?.startsWith('image/') == true || msg.mediaMimeType?.startsWith('video/') == true)) ...[
                  // Protected N-View Photo or Video Card
                  Builder(
                    builder: (ctx) {
                      final isVideo = msg.mediaMimeType?.startsWith('video/') == true;
                      final durationSec = msg.audioDuration ?? 60;
                      final durMin = durationSec ~/ 60;
                      final durRemSec = durationSec % 60;
                      final durationLabel = '$durMin:${durRemSec.toString().padLeft(2, '0')}';

                      return GestureDetector(
                        onTap: () => _openProtectedMediaViewer(context, msg, HavenEngine.instance),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            color: Colors.black38,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(isVideo ? Icons.videocam : Icons.photo, size: 48, color: Colors.white38),
                                if (isVideo)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white54, width: 1.5),
                                    ),
                                    child: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                                  ),
                                // View budget counter badge
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: msg.remainingViews <= 1 ? Colors.redAccent.withOpacity(0.9) : (isVideo ? Colors.blueAccent.withOpacity(0.9) : OffMeshTheme.passionRose.withOpacity(0.9)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(isVideo ? Icons.videocam : Icons.remove_red_eye, color: Colors.white, size: 11),
                                        const SizedBox(width: 4),
                                        Text(
                                          msg.maxViews > 0
                                              ? '${msg.remainingViews} View(s) Left'
                                              : (isVideo ? 'Video ($durationLabel)' : '7-Day Ephemeral'),
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isVideo ? Icons.timer : Icons.timer_outlined, color: Colors.white70, size: 10),
                                        const SizedBox(width: 4),
                                        Text(isVideo ? 'Max 5:00 ($durationLabel)' : 'Expires in 7 days', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                        if (msg.blockSaving) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.lock, color: Colors.amber, size: 10),
                                          const SizedBox(width: 2),
                                          const Text('View Only', style: TextStyle(color: Colors.amber, fontSize: 10)),
                                        ],
                                        if (msg.watermarkEnabled) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified_user, color: Colors.cyanAccent, size: 10),
                                          const SizedBox(width: 2),
                                          const Text('Watermarked', style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                ],

                // Voice Note Audio Card
                if (msg.mediaMimeType?.startsWith('audio/') == true) ...[
                  if (msg.isConsumed) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock, size: 16, color: Colors.white60),
                          SizedBox(width: 6),
                          Text(
                            'Voice note opened and expired',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    if (msg.maxViews == 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.looks_one, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '1 View Voice Note',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Builder(
                      builder: (ctx) {
                        final isPlaying = _playingVoiceMsgId == msg.id;
                        final totalSec = (msg.audioDuration != null && msg.audioDuration! > 0) ? msg.audioDuration! : 5;
                        final currentSec = isPlaying ? _voicePlaybackSeconds : 0;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _togglePlayVoiceNote(msg, haven),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPlaying ? OffMeshTheme.passionRose : Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: List.generate(14, (i) {
                                final isHighlighted = isPlaying && (i / 14 <= currentSec / totalSec);
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  width: 3,
                                  height: (i % 3 + 1) * 6.0 + 4,
                                  decoration: BoxDecoration(
                                    color: isHighlighted ? OffMeshTheme.passionRose : Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPlaying
                                  ? '0:${currentSec.toString().padLeft(2, '0')} / 0:${totalSec.toString().padLeft(2, '0')}'
                                  : '0:${totalSec.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                ],

                // Message Text
                Text(
                  msg.isDeleted ? '🚫 This message was deleted' : msg.text,
                  style: TextStyle(
                    color: isOut ? OffMeshTheme.bubbleOutgoingText : OffMeshTheme.bubbleIncomingText,
                    fontSize: 15,
                    fontStyle: msg.isDeleted ? FontStyle.italic : FontStyle.normal,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg.isEdited) ...[
                      const Text('edited ', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isOut ? Colors.white70 : OffMeshTheme.textDarker,
                      ),
                    ),
                    if (isOut) ...[
                      const SizedBox(width: 4),
                      if (msg.status == MessageStatus.queued)
                        const Icon(Icons.access_time, size: 12, color: Colors.white60)
                      else if (msg.status == MessageStatus.expired)
                        const Icon(Icons.error_outline, size: 12, color: Colors.orangeAccent)
                      else
                        const Icon(Icons.done_all, size: 12, color: Colors.white70),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSafetyShieldMenu(BuildContext context, HavenEngine haven) {
    final couple = haven.coupleInfo;
    final partnerId = couple?.partner.id ?? (haven.contacts.isNotEmpty ? haven.contacts.first.idHex : '');
    final partnerName = couple?.partnerName ?? 'Partner';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OffMeshTheme.romanticSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
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
                  const Row(
                    children: [
                      Icon(Icons.shield, color: OffMeshTheme.passionRose, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Girls\' Safety & Guardian',
                          style: TextStyle(
                            color: OffMeshTheme.textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Immediate safeguards to prevent harassment, stop contact, and incinerate chat data.',
                    style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: OffMeshTheme.borderRomantic),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                    ),
                    title: const Text('Block & Sever Connection', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Instantly disconnects from $partnerName and blocks all future messages', style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmBlockUser(context, haven, partnerId, partnerName);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                    ),
                    title: const Text('Emergency Mutual Nuke', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Instantly and mutually incinerates all messages and ephemeral media on both phones', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmNukeConversation(context, haven, partnerId, partnerName);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.masks, color: Colors.purpleAccent, size: 20),
                    ),
                    title: Text(
                      haven.isGhostModeActive ? 'Disable Ghost Persona' : 'Enable Incognito Ghost Persona',
                      style: const TextStyle(color: OffMeshTheme.textWhite, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      haven.isGhostModeActive
                          ? 'Active alias: @${haven.ghostPersona.aliasName}'
                          : 'Chat anonymously without revealing your real username or profile',
                      style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 11),
                    ),
                    trailing: Switch(
                      value: haven.isGhostModeActive,
                      activeTrackColor: OffMeshTheme.passionRose,
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        haven.toggleGhostMode(val);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? '👻 Ghost Persona activated (@${haven.ghostPersona.aliasName})' : 'Ghost Persona disabled'),
                            backgroundColor: OffMeshTheme.passionRose,
                          ),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                    ),
                    title: const Text('Girls\' Safety & Anti-Leak Guide', style: TextStyle(color: OffMeshTheme.textWhite)),
                    subtitle: const Text('Learn how OffMesh protects against screen recording and 2nd phone photo leaks', style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 11)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSafetyGuideDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmBlockUser(BuildContext context, HavenEngine haven, String targetId, String targetName) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Block User & Sever Chat?', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to block $targetName? They will not be able to send you messages or remote signals, and your couple connection will be severed immediately.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await haven.blockUser(targetId, reason: 'Safety block');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🛡️ $targetName has been blocked and connection severed.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Block failed: $e')),
                  );
                }
              }
            },
            child: const Text('Block & Sever', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmNukeConversation(BuildContext context, HavenEngine haven, String targetId, String targetName) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text('Mutual Emergency Nuke?', style: TextStyle(color: Colors.orangeAccent, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will permanently incinerate all chat messages, ephemeral media, and cached photos on BOTH your phone and your partner\'s phone. This action CANNOT be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              try {
                await haven.nukeConversation(targetId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔥 Conversation nuked! All chat messages and media incinerated on both devices.'),
                      backgroundColor: Colors.deepOrange,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Nuke failed: $e')),
                  );
                }
              }
            },
            child: const Text('Incinerate Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSafetyGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: OffMeshTheme.passionRose, size: 22),
            SizedBox(width: 8),
            Text('Girls\' Privacy & Safety Guide', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔒 1. Anti-Surveillance FLAG_SECURE', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('Hardware-level protection prevents screenshots, screen recordings, and app preview multitasking snooping.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),
              Text('📷 2. Defeating the "Analog Hole" (2nd Phone Cameras)', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('When you send watermarked photos, a diagonal steganographic overlay embeds the recipient\'s ID across the image. If they photograph their screen with a second phone, the leak directly incriminates them.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),
              Text('👁️ 3. Granular N-View Ephemeral Media', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('Set photos to 1, 2, 3, 4, or 5 views. Once opened for the designated count, the photo auto-destructs and is zeroed from server storage.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),
              Text('👻 4. Incognito Ghost Personas', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('Chat with unfamiliar users using an auto-generated pseudonym without revealing your real username, phone, or email.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 12),
              Text('🔥 5. Emergency Mutual Nuke', style: TextStyle(color: OffMeshTheme.passionRose, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text('Instantly triggers bidirectional destruction of all chat history and remote files.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OffMeshTheme.passionRose),
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openProtectedMediaViewer(BuildContext context, MessageItem msg, HavenEngine haven) {
    if (msg.isConsumed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This media has already self-destructed')),
      );
      return;
    }

    // Consume 1 view count
    haven.consumeMediaView(msg.id);

    final partnerName = haven.coupleInfo?.partnerName ?? 'Partner';
    final recipientId = msg.toIdHex.length > 8 ? msg.toIdHex.substring(0, 8) : msg.toIdHex;
    final viewCountNow = msg.viewCount + 1;
    final remainingNow = msg.maxViews > 0 ? (msg.maxViews - viewCountNow > 0 ? msg.maxViews - viewCountNow : 0) : 999;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dlgCtx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo Display Canvas
              Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: const Color(0xFF0A0A0E),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Simulated High-res Photo or Video Canvas
                      Builder(
                        builder: (ctx) {
                          final isVideo = msg.mediaMimeType?.startsWith('video/') == true;
                          final durationSec = msg.audioDuration ?? 60;
                          final durMin = durationSec ~/ 60;
                          final durRemSec = durationSec % 60;
                          final durationLabel = '$durMin:${durRemSec.toString().padLeft(2, '0')}';

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (isVideo ? Colors.blueAccent : OffMeshTheme.passionRose).withOpacity(0.15),
                                ),
                                child: Icon(
                                  isVideo ? Icons.play_circle_fill : Icons.lock_clock,
                                  size: 72,
                                  color: isVideo ? Colors.blueAccent : OffMeshTheme.passionRose,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                isVideo
                                    ? 'E2EE Ephemeral Video ($durationLabel)'
                                    : (msg.text.isNotEmpty && !msg.text.startsWith('📷') ? msg.text : 'E2EE Ephemeral Image'),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isVideo
                                    ? 'Max 5-minute video • Auto-destructs upon view limit'
                                    : 'Decrypted locally in device secure memory',
                                style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),

                      // Dynamic Steganographic Anti-Leak Watermark Overlay
                      if (msg.watermarkEnabled)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(7, (i) {
                                  return Opacity(
                                    opacity: 0.18,
                                    child: Text(
                                      'CONFIDENTIAL • RECIPIENT: @$partnerName • ID: #$recipientId • DO NOT LEAK',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Top Status Bar
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(dlgCtx),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.6)),
                      ),
                      child: Text(
                        msg.maxViews > 0
                            ? 'View $viewCountNow of ${msg.maxViews} ($remainingNow left)'
                            : '7-Day Ephemeral',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Warning Banner
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg.watermarkEnabled
                              ? 'Protected: Screenshot blocked. Watermark will expose secondary camera leaks.'
                              : 'Protected: Screenshot blocked by FLAG_SECURE.',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HoldToRingAlarmButton extends StatefulWidget {
  final bool enabled;
  final ScaffoldMessengerState messenger;
  final Future<void> Function() onTriggered;

  const _HoldToRingAlarmButton({
    super.key,
    required this.enabled,
    required this.messenger,
    required this.onTriggered,
  });

  @override
  State<_HoldToRingAlarmButton> createState() => _HoldToRingAlarmButtonState();
}

class _HoldToRingAlarmButtonState extends State<_HoldToRingAlarmButton> {
  Timer? _holdTimer;
  double _progress = 0.0;
  bool _isHolding = false;
  bool _triggered = false;
  int _elapsedMs = 0;
  static const int _holdTotalMs = 3000;
  static const int _tickIntervalMs = 50;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onPressDown() {
    if (!widget.enabled) {
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Alarm Ring is disabled by partner\'s chat settings'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _holdTimer?.cancel();
    setState(() {
      _isHolding = true;
      _triggered = false;
      _progress = 0.0;
      _elapsedMs = 0;
    });
    HapticFeedback.lightImpact();

    _holdTimer = Timer.periodic(const Duration(milliseconds: _tickIntervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsedMs += _tickIntervalMs;
      if (_elapsedMs >= _holdTotalMs) {
        timer.cancel();
        setState(() {
          _progress = 1.0;
          _isHolding = false;
          _triggered = true;
        });
        HapticFeedback.heavyImpact();
        widget.onTriggered();
      } else {
        setState(() {
          _progress = _elapsedMs / _holdTotalMs;
        });
      }
    });
  }

  void _onPressUpOrCancel() {
    if (!_isHolding && !_triggered) return;
    final wasHolding = _isHolding;
    final didTrigger = _triggered;

    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHolding = false;
        _progress = 0.0;
        _elapsedMs = 0;
      });
    }

    if (wasHolding && !didTrigger) {
      HapticFeedback.selectionClick();
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('⚠️ Hold for 3 seconds to trigger emergency ringtone & vibration on partner device.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const redAccent = Colors.redAccent;
    final secondsRemaining = ((_holdTotalMs - _elapsedMs) / 1000).ceil();

    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.4,
      child: Listener(
        key: const Key('btn_alarm_ring_hold'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onPressDown(),
        onPointerUp: (_) => _onPressUpOrCancel(),
        onPointerCancel: (_) => _onPressUpOrCancel(),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isHolding)
                      CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 3.5,
                        valueColor: const AlwaysStoppedAnimation<Color>(redAccent),
                        backgroundColor: redAccent.withOpacity(0.2),
                      ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _isHolding
                            ? redAccent.withOpacity(0.35)
                            : redAccent.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: redAccent,
                          width: _isHolding ? 2.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: redAccent.withOpacity(_isHolding ? 0.6 : 0.25),
                            blurRadius: _isHolding ? 14 : 6,
                            spreadRadius: _isHolding ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isHolding
                            ? Text(
                                '${secondsRemaining}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : const Icon(
                                Icons.notifications_active,
                                color: redAccent,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Alarm Ring',
                style: TextStyle(
                  color: OffMeshTheme.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: redAccent.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: redAccent.withOpacity(0.4), width: 0.8),
                ),
                child: const Text(
                  'Hold 3s',
                  style: TextStyle(
                    color: redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

