import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/haven_engine.dart';
import '../theme.dart';

/// Minimalistic, Elegant 180 Identity & Sovereign Sanctuary Authentication Screen.
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _handleCtrl = TextEditingController();
  String? _error;
  bool _isLoading180 = false;
  bool _isLoadingWhatsApp = false;

  @override
  void dispose() {
    _handleCtrl.dispose();
    super.dispose();
  }

  /// 180 Identity Universal SSO Authentication.
  Future<void> _authenticateWith180({bool isWhatsApp = false}) async {
    setState(() {
      _error = null;
      if (isWhatsApp) {
        _isLoadingWhatsApp = true;
      } else {
        _isLoading180 = true;
      }
    });

    final engine = HavenEngine.instance;
    final handle = _handleCtrl.text.trim().replaceAll('@', '');

    try {
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
      final authCode = isWhatsApp
          ? '180_wa_otp_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix'
          : '180_auth_code_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

      await engine.loginWith180Identity(
        code: authCode,
        username: handle.isNotEmpty ? handle : null,
        displayName: handle.isNotEmpty ? handle : (isWhatsApp ? 'WhatsApp Partner' : '180 Soulmate'),
      );

      widget.onAuthenticated();
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Connection refused') ||
          errStr.contains('errno = 111') ||
          errStr.contains('Failed host lookup')) {
        setState(() => _error =
            'Cannot reach server at ${engine.backendUrl}.\nMake sure phone & PC share Wi-Fi, change IP via ⚙️ icon, or enter offline.');
      } else {
        setState(() => _error = errStr.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading180 = false;
          _isLoadingWhatsApp = false;
        });
      }
    }
  }

  void _loginOffline() {
    final handle = _handleCtrl.text.trim().replaceAll('@', '');
    HavenEngine.instance.loginOffline(
      handle: handle.isNotEmpty ? handle : null,
      displayName: handle.isNotEmpty ? handle : 'Sanctuary Partner',
    );
    widget.onAuthenticated();
  }

  void _showServerSettingsDialog() {
    final engine = HavenEngine.instance;
    final urlCtrl = TextEditingController(text: engine.backendUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OffMeshTheme.romanticSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: OffMeshTheme.passionRose, size: 22),
            SizedBox(width: 10),
            Text('Server Endpoint', style: TextStyle(color: OffMeshTheme.textWhite, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend URL (e.g. host PC IP on Wi-Fi):',
              style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'http://192.168.1.65:3000',
                hintStyle: const TextStyle(color: OffMeshTheme.textDarker),
                filled: true,
                fillColor: OffMeshTheme.romanticBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                engine.setBackendUrl(urlCtrl.text.trim());
              }
              Navigator.pop(ctx);
              setState(() => _error = null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OffMeshTheme.passionRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = HavenEngine.instance;

    return Scaffold(
      backgroundColor: OffMeshTheme.romanticBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: OffMeshTheme.textMuted, size: 20),
            tooltip: 'Server Settings',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Romantic Heart Shield
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: OffMeshTheme.passionRose.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: OffMeshTheme.passionRose.withOpacity(0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: OffMeshTheme.passionRose,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title & Subtitle
                const Text(
                  'OffMesh Haven',
                  style: TextStyle(
                    color: OffMeshTheme.textWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Intimate, Double-Ratchet Encrypted Sanctuary',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OffMeshTheme.passionRoseLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),

                // Partner Handle Input
                TextField(
                  controller: _handleCtrl,
                  style: const TextStyle(color: OffMeshTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'Partner Handle / Alias (Optional)',
                    hintText: 'e.g. romeo, juliet',
                    hintStyle: const TextStyle(color: OffMeshTheme.textDarker),
                    prefixIcon: const Icon(Icons.alternate_email, color: OffMeshTheme.textMuted, size: 20),
                    filled: true,
                    fillColor: OffMeshTheme.romanticSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: OffMeshTheme.borderRomantic),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: OffMeshTheme.borderRomantic),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: OffMeshTheme.passionRoseLight),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Error Banner with option to change endpoint
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OffMeshTheme.statusError.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OffMeshTheme.statusError.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: OffMeshTheme.statusError, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: OffMeshTheme.statusError, fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _showServerSettingsDialog,
                              icon: const Icon(Icons.edit, size: 14, color: OffMeshTheme.passionRoseLight),
                              label: const Text('Change IP', style: TextStyle(color: OffMeshTheme.passionRoseLight, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Primary 1-Tap CTA: Sign in with 180 Profile
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (engine.isBusy || _isLoading180 || _isLoadingWhatsApp)
                        ? null
                        : () => _authenticateWith180(isWhatsApp: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OffMeshTheme.passionRose,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: OffMeshTheme.passionRose.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading180
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_person_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Sign in with 180 Profile',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary 1-Tap CTA: Continue with WhatsApp 1-Tap
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (engine.isBusy || _isLoading180 || _isLoadingWhatsApp)
                        ? null
                        : () => _authenticateWith180(isWhatsApp: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7E34),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                    ),
                    child: _isLoadingWhatsApp
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF25D366)),
                              SizedBox(width: 10),
                              Text(
                                'Continue with WhatsApp 1-Tap',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Offline Sanctuary Direct BLE Mesh Mode CTA
                TextButton.icon(
                  onPressed: _loginOffline,
                  icon: const Icon(Icons.cell_tower_rounded, size: 18, color: OffMeshTheme.textMuted),
                  label: const Text(
                    'Enter Offline Mesh Mode (Direct P2P)',
                    style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
