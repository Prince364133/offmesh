import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'models.dart';
import 'haven_e2ee.dart';
import 'engine_adapter.dart';

class PendingOutboxMessage {
  final String msgId;
  final Contact recipient;
  final String text;
  final String? replyToId;
  final String? replyToText;
  final String? mediaUrl;
  final String? mediaMimeType;
  final bool blockSaving;
  final int? audioDuration;
  final int maxViews;
  final bool watermarkEnabled;
  final String wireBundleBase64;

  PendingOutboxMessage({
    required this.msgId,
    required this.recipient,
    required this.text,
    this.replyToId,
    this.replyToText,
    this.mediaUrl,
    this.mediaMimeType,
    this.blockSaving = false,
    this.audioDuration,
    this.maxViews = 1,
    this.watermarkEnabled = true,
    required this.wireBundleBase64,
  });
}

class HavenEngine extends ChangeNotifier {
  static final HavenEngine instance = HavenEngine();

  static const String defaultBackendUrl = 'http://192.168.1.65:3000';
  String backendUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: defaultBackendUrl);
  String get wsUrl => backendUrl.replaceFirst('http', 'ws');

  void setBackendUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    backendUrl = clean;
    notifyListeners();
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final List<PendingOutboxMessage> _outboxQueue = [];
  List<PendingOutboxMessage> get outboxQueue => List.unmodifiable(_outboxQueue);
  int get pendingOutboxCount => _outboxQueue.length;

  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    if (_isOnline) {
      _connectWebSocket();
      flushOutbox();
    }
    notifyListeners();
  }

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String? _sessionToken;
  String? get sessionToken => _sessionToken;

  /// Fast offline sanctuary / BLE mesh login without requiring network connection.
  void loginOffline({String? handle, String? displayName}) {
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : ((handle != null && handle.trim().isNotEmpty) ? handle.trim() : 'Guest Partner');
    final uname = (handle != null && handle.trim().isNotEmpty)
        ? handle.trim().toLowerCase().replaceAll(' ', '_')
        : 'guest_${DateTime.now().millisecondsSinceEpoch % 10000}';

    _currentUser = UserProfile(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      username: uname,
      displayName: name,
      email: '$uname@haven.local',
      avatarUrl: null,
      signPublicKey: _deviceKeys?.signPubKeyHex ?? ('0' * 64),
      encPublicKey: _deviceKeys?.encPubKeyHex ?? ('0' * 64),
    );
    _sessionToken = 'offline_token_${DateTime.now().millisecondsSinceEpoch}';
    _isOnline = false;
    _isStealthUnlocked = true;
    notifyListeners();
  }

  CoupleInfo? _coupleInfo;
  CoupleInfo? get coupleInfo => _coupleInfo;
  bool get isPaired => _coupleInfo != null && _coupleInfo!.status == 'ACCEPTED';

  StealthSettings _stealthSettings = StealthSettings();
  StealthSettings get stealthSettings => _stealthSettings;

  CouplePermissions _myPermissions = CouplePermissions();
  CouplePermissions get myPermissions => _myPermissions;

  CouplePermissions _partnerPermissions = CouplePermissions();
  CouplePermissions get partnerPermissions => _partnerPermissions;

  ChatCustomization _chatCustomization = ChatCustomization();
  ChatCustomization get chatCustomization => _chatCustomization;

  SubscriptionInfo _subscription = SubscriptionInfo();
  SubscriptionInfo get subscription => _subscription;

  List<BlockedUser> _blockedUsers = [];
  List<BlockedUser> get blockedUsers => List.unmodifiable(_blockedUsers);

  GhostPersona _ghostPersona = GhostPersona();
  GhostPersona get ghostPersona => _ghostPersona;

  bool _isGhostModeActive = false;
  bool get isGhostModeActive => _isGhostModeActive;

  void toggleGhostMode(bool active) {
    _isGhostModeActive = active;
    notifyListeners();
  }

  final StreamController<Map<String, dynamic>> _signalEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get signalEvents => _signalEvents.stream;

  EngineAdapter _platformAdapter = const PlatformEngineAdapter();
  EngineAdapter get platformAdapter => _platformAdapter;

  @visibleForTesting
  set platformAdapter(EngineAdapter adapter) => _platformAdapter = adapter;

  bool _isStealthUnlocked = true;
  bool get isStealthUnlocked => _isStealthUnlocked;

  final List<Contact> _contacts = [];
  List<Contact> get contacts => List.unmodifiable(_contacts);

  final List<MessageItem> _messages = [];
  List<MessageItem> get messages => List.unmodifiable(_messages);

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  bool _isBusy = false;
  bool get isBusy => _isBusy;
  String? lastError;

  HavenE2EEKeys? _deviceKeys;
  HavenE2EEKeys? get deviceKeys => _deviceKeys;

  Future<void> init() async {
    try {
      _deviceKeys = await havenCrypto.generateIdentity();
    } catch (e) {
      debugPrint('Identity key generation warning: $e');
    }
  }

  void unlockStealth() {
    _isStealthUnlocked = true;
    notifyListeners();
  }

  void lockStealth() {
    _isStealthUnlocked = false;
    notifyListeners();
  }

  bool verifyPin(String enteredPin) {
    if (enteredPin == _stealthSettings.decoyPin) {
      unlockStealth();
      return true;
    }
    return false;
  }

  void setMockAuthenticatedForTesting({
    UserProfile? user,
    CoupleInfo? couple,
    String? token,
  }) {
    _currentUser = user ??
        UserProfile(
          id: 'test_user',
          username: 'romeo',
          displayName: 'Romeo',
          email: 'romeo@haven.app',
          avatarUrl: null,
          signPublicKey: '0' * 64,
          encPublicKey: '0' * 64,
        );
    _sessionToken = token ?? 'mock_token';
    _coupleInfo = couple;
    _isStealthUnlocked = true;
    notifyListeners();
  }

  void resetForTesting() {
    _currentUser = null;
    _sessionToken = null;
    _coupleInfo = null;
    _isStealthUnlocked = false;
    _messages.clear();
    _contacts.clear();
    _isOnline = true;
    _outboxQueue.clear();
    _stealthSettings = StealthSettings();
    _myPermissions = CouplePermissions();
    _partnerPermissions = CouplePermissions();
    _chatCustomization = ChatCustomization();
    _subscription = SubscriptionInfo();
    _blockedUsers.clear();
    _ghostPersona = GhostPersona();
    _isGhostModeActive = false;
    notifyListeners();
  }

  void setMockSubscriptionForTesting(SubscriptionInfo sub) {
    _subscription = sub;
    notifyListeners();
  }

  void setMockBlockedUsersForTesting(List<BlockedUser> list) {
    _blockedUsers = List.from(list);
    notifyListeners();
  }

  void setMockGhostPersonaForTesting(GhostPersona persona) {
    _ghostPersona = persona;
    notifyListeners();
  }

  void setMockMessagesForTesting(List<MessageItem> list) {
    _messages.clear();
    _messages.addAll(list);
    notifyListeners();
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
  };

  /// Universal 180 Identity Token Exchange.
  /// Authenticates using the authorization code from 180 Identity SSO.
  Future<UserProfile> loginWith180Identity({
    required String code,
    String? redirectUri,
    String? username,
    String? displayName,
  }) async {
    _isBusy = true;
    lastError = null;
    notifyListeners();

    try {
      if (_deviceKeys == null) await init();

      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/auth/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'redirectUri': redirectUri,
          'username': username,
          'displayName': displayName,
          'signPublicKey': _deviceKeys!.signPubKeyHex,
          'encPublicKey': _deviceKeys!.encPubKeyHex,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? '180 Identity exchange failed');
      }

      _sessionToken = data['token'] as String;
      _currentUser = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await _afterAuthSync();
      return _currentUser!;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Fetches the 180 Identity Universal Authorize URL.
  Future<String> get180IdentityAuthorizeUrl({String? redirectUri}) async {
    try {
      final query = redirectUri != null ? '?redirectUri=${Uri.encodeComponent(redirectUri)}' : '';
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/auth/authorize-url$query'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['authorizeUrl'] as String;
      }
    } catch (_) {}
    return 'https://auth.180workspace.com/authorize?client_id=180_client_6182d7379831a5524c834e2fe8c58e68&response_type=code&scope=openid%20identity:read%20identity:email%20identity:phone';
  }

  Future<void> _afterAuthSync() async {
    _connectWebSocket();
    await fetchCoupleStatus();
    await fetchStealthSettings();
    await fetchPermissions();
    await fetchChatCustomization();
    await fetchSubscriptionStatus();
    await fetchBlockedUsers();
    await fetchGhostPersona();
    if (_fcmToken != null) {
      await registerFcmToken(_fcmToken!);
    }
    _isStealthUnlocked = true;
  }

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Register FCM push token with backend for background alerts.
  Future<bool> registerFcmToken(String token, {String platform = 'android'}) async {
    _fcmToken = token;
    if (_sessionToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/notifications/token'),
        headers: _authHeaders,
        body: jsonEncode({
          'fcmToken': token,
          'platform': platform,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('FCM token registration error: $e');
      return false;
    }
  }

  /// Unregister FCM push token upon logout.
  Future<bool> unregisterFcmToken() async {
    if (_sessionToken == null || _fcmToken == null) return false;
    try {
      final res = await http.delete(
        Uri.parse('$backendUrl/api/v1/notifications/token'),
        headers: _authHeaders,
        body: jsonEncode({'fcmToken': _fcmToken}),
      );
      _fcmToken = null;
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('FCM unregister error: $e');
      return false;
    }
  }

  /// Dispatch a test notification to verify FCM push delivery.
  Future<bool> sendTestNotification({String? title, String? body}) async {
    if (_sessionToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/notifications/test'),
        headers: _authHeaders,
        body: jsonEncode({
          if (title != null) 'title': title,
          if (body != null) 'body': body,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('FCM test error: $e');
      return false;
    }
  }

  /// Search users by username (for finding partner).
  Future<List<UserProfile>> searchUsers(String query) async {
    if (_sessionToken == null || query.trim().isEmpty) return [];
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/auth/search?q=${Uri.encodeComponent(query.trim())}'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['users'] as List;
        return list.map((u) => UserProfile.fromJson(u as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('User search error: $e');
      return [];
    }
  }

  /// Request couple pairing with a username.
  Future<void> requestCouple(String partnerUsername) async {
    _isBusy = true;
    lastError = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/request'),
        headers: _authHeaders,
        body: jsonEncode({'partnerUsername': partnerUsername}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to send couple request');
      }
      await fetchCoupleStatus();
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Respond to incoming couple request.
  Future<void> respondCouple(String coupleId, bool accept) async {
    _isBusy = true;
    lastError = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/respond'),
        headers: _authHeaders,
        body: jsonEncode({'coupleId': coupleId, 'accept': accept}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to respond to request');
      }
      await fetchCoupleStatus();
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Fetch current couple status and milestones.
  Future<void> fetchCoupleStatus() async {
    if (_sessionToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/couples/status'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['couple'] != null) {
          _coupleInfo = CoupleInfo.fromJson(data['couple'] as Map<String, dynamic>);
          _updatePartnerContact();
        } else {
          _coupleInfo = null;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Couple status error: $e');
    }
  }

  void _updatePartnerContact() {
    if (_coupleInfo == null) return;
    final partner = _coupleInfo!.partner;
    final contact = Contact(
      name: _coupleInfo!.partnerName,
      idHex: partner.id,
      signPubHex: partner.signPublicKey,
      encPubHex: partner.encPublicKey,
      cardString: '',
      username: partner.username,
      moodStatus: partner.moodStatus,
    );
    _contacts.removeWhere((c) => c.idHex == partner.id);
    _contacts.insert(0, contact);
  }

  /// Update anniversary date or partner nickname.
  Future<void> updateCoupleDetails({
    DateTime? anniversaryDate,
    String? nicknameForPartner,
  }) async {
    if (_sessionToken == null) return;
    try {
      final bodyMap = <String, dynamic>{};
      if (anniversaryDate != null) bodyMap['anniversaryDate'] = anniversaryDate.toIso8601String();
      if (nicknameForPartner != null) bodyMap['nicknameForPartner'] = nicknameForPartner;

      await http.put(
        Uri.parse('$backendUrl/api/v1/couples/details'),
        headers: _authHeaders,
        body: jsonEncode(bodyMap),
      );
      await fetchCoupleStatus();
    } catch (e) {
      debugPrint('Error updating details: $e');
    }
  }

  /// Fetch Stealth & Notification settings.
  Future<void> fetchStealthSettings() async {
    if (_sessionToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/couples/stealth'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['stealthSettings'] != null) {
          _stealthSettings = StealthSettings.fromJson(data['stealthSettings'] as Map<String, dynamic>);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Stealth settings error: $e');
    }
  }

  /// Update Stealth & Notification settings.
  Future<void> updateStealthSettings(StealthSettings newSettings) async {
    if (_sessionToken == null) {
      _stealthSettings = newSettings;
      notifyListeners();
      return;
    }
    try {
      final res = await http.put(
        Uri.parse('$backendUrl/api/v1/couples/stealth'),
        headers: _authHeaders,
        body: jsonEncode(newSettings.toJson()),
      );
      if (res.statusCode == 200) {
        _stealthSettings = newSettings;
        try {
          const MethodChannel('net.offmesh/engine.v1').invokeMethod(
            'setAppDisguise',
            {'disguise': newSettings.appDisguise},
          );
        } catch (_) {}
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Update stealth settings error: $e');
    }
  }

  /// Fetch mutual chat permissions.
  Future<void> fetchPermissions() async {
    if (_sessionToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/couples/permissions'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['myPermissions'] != null) {
          _myPermissions = CouplePermissions.fromJson(data['myPermissions'] as Map<String, dynamic>);
          await _platformAdapter.setScreenSecurity(_myPermissions.blockScreenshots);
        }
        if (data['partnerPermissions'] != null) {
          _partnerPermissions = CouplePermissions.fromJson(data['partnerPermissions'] as Map<String, dynamic>);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Permissions fetch error: $e');
    }
  }

  /// Update chat permissions and toggle screen security.
  Future<void> updatePermissions(CouplePermissions updated) async {
    if (_sessionToken == null) return;
    try {
      final res = await http.put(
        Uri.parse('$backendUrl/api/v1/couples/permissions'),
        headers: _authHeaders,
        body: jsonEncode(updated.toJson()),
      );
      if (res.statusCode == 200) {
        _myPermissions = updated;
        await _platformAdapter.setScreenSecurity(updated.blockScreenshots);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Permissions update error: $e');
      rethrow;
    }
  }

  /// Trigger a remote hardware signal (BUZZ, RING, FLASHLIGHT) to partner.
  Future<bool> sendRemoteSignal(String signalType) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    if (!isPaired) throw Exception('Pair with partner to send remote signals');

    // Verify recipient consent
    if (signalType == 'BUZZ' && !_partnerPermissions.allowVibrate) {
      throw Exception('Your partner has disabled remote vibration in chat settings');
    }
    if (signalType == 'RING' && !_partnerPermissions.allowRing) {
      throw Exception('Your partner has disabled remote bell ring in chat settings');
    }
    if (signalType == 'FLASHLIGHT' && !_partnerPermissions.allowFlashlight) {
      throw Exception('Your partner has disabled remote flashlight in chat settings');
    }

    if (_sessionToken == 'mock_token') {
      return true;
    }

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/signal'),
        headers: _authHeaders,
        body: jsonEncode({'signalType': signalType}),
      );
      if (res.statusCode != 200) {
        final data = jsonDecode(res.body);
        throw Exception(data['error'] ?? 'Signal failed');
      }
      return true;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Upload ephemeral media to Cloudflare R2 (7-day TTL with optional N-view limit).
  Future<EphemeralMedia> uploadEphemeralMedia({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    bool blockSaving = false,
    int? durationSeconds,
    int maxViews = 1,
    bool watermarkEnabled = true,
  }) async {
    if (_sessionToken == null) throw Exception('Authentication required');

    // Video duration limit: Max 5 minutes (300 seconds), auto-clipped
    int? effectiveDuration = durationSeconds;
    if (mimeType.startsWith('video/')) {
      if (effectiveDuration != null && effectiveDuration > 300) {
        effectiveDuration = 300; // Auto-clipped to 5 minutes maximum
      }
    }

    String mediaKey = 'couples/${_coupleInfo?.coupleId ?? 'local'}/${DateTime.now().millisecondsSinceEpoch}_$filename';
    String publicUrl = '$backendUrl/api/v1/couples/media/file/$mediaKey';
    String uploadUrl = '';

    try {
      final urlRes = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/media/upload-url'),
        headers: _authHeaders,
        body: jsonEncode({
          'filename': filename,
          'mimeType': mimeType,
          'blockSaving': blockSaving,
        }),
      );

      if (urlRes.statusCode == 200 && urlRes.body.isNotEmpty) {
        final urlData = jsonDecode(urlRes.body) as Map<String, dynamic>;
        mediaKey = urlData['mediaKey'] as String? ?? mediaKey;
        publicUrl = urlData['publicUrl'] as String? ?? publicUrl;
        uploadUrl = urlData['uploadUrl'] as String? ?? '';
      }
    } catch (_) {}

    // Actually upload raw binary bytes to Cloudflare R2 / backend storage via HTTP PUT
    if (uploadUrl.isNotEmpty) {
      try {
        final fullUploadUri = uploadUrl.startsWith('http')
            ? Uri.parse(uploadUrl)
            : Uri.parse('$backendUrl$uploadUrl');

        final uploadRes = await http.put(
          fullUploadUri,
          headers: {
            'Content-Type': mimeType,
            ..._authHeaders,
          },
          body: bytes,
        );

        if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
          debugPrint('Notice: Media upload PUT status: ${uploadRes.statusCode}');
        }
      } catch (uploadErr) {
        debugPrint('Media upload streaming warning: $uploadErr');
      }
    }

    EphemeralMedia? media;
    try {
      // Confirm media metadata
      final confirmRes = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/media/confirm'),
        headers: _authHeaders,
        body: jsonEncode({
          'mediaKey': mediaKey,
          'mediaUrl': publicUrl,
          'mimeType': mimeType,
          'sizeBytes': bytes.length,
          'blockSaving': blockSaving,
          'durationSeconds': effectiveDuration,
          'maxViews': maxViews,
          'watermarkEnabled': watermarkEnabled,
        }),
      );

      if (confirmRes.statusCode == 200 && confirmRes.body.isNotEmpty) {
        final confirmData = jsonDecode(confirmRes.body) as Map<String, dynamic>;
        if (confirmData['media'] != null) {
          media = EphemeralMedia.fromJson(confirmData['media'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    final finalMedia = media ?? EphemeralMedia(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _currentUser?.id ?? 'me',
      mediaUrl: publicUrl,
      mimeType: mimeType,
      blockSaving: blockSaving,
      durationSeconds: effectiveDuration,
      maxViews: maxViews,
      viewCount: 0,
      isConsumed: false,
      watermarkEnabled: watermarkEnabled,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    if (_coupleInfo != null) {
      final partnerContact = _contacts.firstWhere(
        (c) => c.idHex == _coupleInfo!.partner.id,
        orElse: () => Contact(
          name: _coupleInfo!.partnerName,
          idHex: _coupleInfo!.partner.id,
          signPubHex: _coupleInfo!.partner.signPublicKey,
          encPubHex: _coupleInfo!.partner.encPublicKey,
          cardString: '',
        ),
      );

      await sendMessage(
        partnerContact,
        mimeType.startsWith('audio/')
            ? '🎤 Voice message'
            : (mimeType.startsWith('video/') ? '🎥 Shared video' : '📷 Shared media'),
        mediaUrl: finalMedia.mediaUrl,
        mediaMimeType: mimeType,
        blockSaving: blockSaving,
        audioDuration: effectiveDuration,
        maxViews: maxViews,
        watermarkEnabled: watermarkEnabled,
      );
    }

    return finalMedia;
  }

  /// Fetch chat screen customization (wallpaper & theme).
  Future<void> fetchChatCustomization() async {
    if (_sessionToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/couples/customization'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['customization'] != null) {
          _chatCustomization = ChatCustomization.fromJson(data['customization'] as Map<String, dynamic>);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Customization fetch error: $e');
    }
  }

  /// Update chat wallpaper and theme color.
  Future<void> updateChatCustomization({
    String? wallpaperUrl,
    String? themeColor,
  }) async {
    if (_sessionToken == null) return;
    try {
      final bodyMap = <String, dynamic>{};
      if (wallpaperUrl != null) bodyMap['wallpaperUrl'] = wallpaperUrl;
      if (themeColor != null) bodyMap['themeColor'] = themeColor;

      final res = await http.put(
        Uri.parse('$backendUrl/api/v1/couples/customization'),
        headers: _authHeaders,
        body: jsonEncode(bodyMap),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['customization'] != null) {
          _chatCustomization = ChatCustomization.fromJson(data['customization'] as Map<String, dynamic>);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Customization update error: $e');
    }
  }

  /// Fetch subscription and 3-day free trial status.
  Future<SubscriptionInfo> fetchSubscriptionStatus() async {
    if (_sessionToken == null) return _subscription;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/billing/status'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['subscription'] != null) {
          _subscription = SubscriptionInfo.fromJson(data['subscription'] as Map<String, dynamic>);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Subscription status fetch error: $e');
    }
    return _subscription;
  }

  /// Request a 180pay / Stripe Checkout Session URL
  Future<Map<String, dynamic>> createCheckoutSession({String provider = '180pay'}) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    final res = await http.post(
      Uri.parse('$backendUrl/api/v1/billing/checkout-session'),
      headers: _authHeaders,
      body: jsonEncode({'provider': provider}),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Checkout session creation failed');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Activate $5/month Haven Sanctuary subscription via 180pay.
  Future<SubscriptionInfo> subscribeMonthly({String paymentProvider = '180PAY'}) async {
    _isBusy = true;
    lastError = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/billing/subscribe'),
        headers: _authHeaders,
        body: jsonEncode({
          'paymentProvider': paymentProvider,
          'plan': 'MONTHLY_5',
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Subscription failed');
      }
      if (data['subscription'] != null) {
        _subscription = SubscriptionInfo.fromJson(data['subscription'] as Map<String, dynamic>);
        notifyListeners();
      }
      return _subscription;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Edit sent message.
  void editMessage(String msgId, String newText) {
    final idx = _messages.indexWhere((m) => m.id == msgId && m.isOutgoing);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(text: newText, isEdited: true);
      notifyListeners();
    }
  }

  /// Unsend / delete message.
  void deleteMessage(String msgId) {
    final idx = _messages.indexWhere((m) => m.id == msgId);
    if (idx != -1) {
      _messages[idx] = _messages[idx].copyWith(
        text: 'This message was deleted',
        isDeleted: true,
      );
      notifyListeners();
    }
  }

  /// Sends an End-to-End Encrypted message to [recipient] with rich attachments, N-view limits, and replies.
  Future<void> sendMessage(
    Contact recipient,
    String text, {
    String? replyToId,
    String? replyToText,
    String? mediaUrl,
    String? mediaMimeType,
    bool blockSaving = false,
    int? audioDuration,
    int maxViews = 1,
    bool watermarkEnabled = true,
  }) async {
    if (text.trim().isEmpty && mediaUrl == null) return;
    if (_deviceKeys == null) await init();

    // 1. Client-side E2EE encryption
    final payloadContent = jsonEncode({
      'text': text,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'mediaUrl': mediaUrl,
      'mediaMimeType': mediaMimeType,
      'blockSaving': blockSaving,
      'audioDuration': audioDuration,
      'maxViews': maxViews,
      'watermarkEnabled': watermarkEnabled,
    });

    final envelope = await havenCrypto.encryptMessage(
      plaintext: payloadContent,
      recipientEncPubHex: recipient.encPubHex,
      myKeys: _deviceKeys!,
    );

    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = MessageItem(
      id: msgId,
      toIdHex: recipient.idHex,
      fromIdHex: _currentUser?.id ?? _deviceKeys!.idHex,
      text: text,
      isOutgoing: true,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      status: MessageStatus.queued,
      replyToId: replyToId,
      replyToText: replyToText,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      blockSaving: blockSaving,
      audioDuration: audioDuration,
      maxViews: maxViews,
      viewCount: 0,
      isConsumed: false,
      watermarkEnabled: watermarkEnabled,
    );
    _messages.insert(0, localMsg);

    final pendingItem = PendingOutboxMessage(
      msgId: msgId,
      recipient: recipient,
      text: text,
      replyToId: replyToId,
      replyToText: replyToText,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      blockSaving: blockSaving,
      audioDuration: audioDuration,
      maxViews: maxViews,
      watermarkEnabled: watermarkEnabled,
      wireBundleBase64: envelope.wireBundleBase64,
    );
    _outboxQueue.add(pendingItem);
    notifyListeners();

    // 2. Deliver if online; otherwise remains queued in outbox
    if (_isOnline) {
      bool sent = false;
      if (_wsChannel != null) {
        try {
          _wsChannel!.sink.add(jsonEncode({
            'type': 'ENCRYPTED_MESSAGE',
            'msgId': msgId,
            'recipientId': recipient.idHex,
            'payload': envelope.wireBundleBase64,
          }));
          sent = true;
        } catch (_) {}
      }

      if (!sent) {
        try {
          final res = await http.post(
            Uri.parse('$backendUrl/api/v1/bundles/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'payloadBase64': envelope.wireBundleBase64}),
          );
          if (res.statusCode == 200) {
            sent = true;
          }
        } catch (e) {
          debugPrint('Bundle upload fallback notice: $e');
        }
      }

      if (sent) {
        _outboxQueue.removeWhere((p) => p.msgId == msgId);
        final idx = _messages.indexWhere((m) => m.id == msgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            status: MessageStatus.delivered,
            deliveredAtMs: DateTime.now().millisecondsSinceEpoch,
          );
          notifyListeners();
        }
      }
    }
  }

  /// Automatically flushes offline outbox queue and delivers pending messages.
  Future<int> flushOutbox() async {
    if (_outboxQueue.isEmpty) return 0;
    int flushedCount = 0;
    final toFlush = List<PendingOutboxMessage>.from(_outboxQueue);

    for (final pending in toFlush) {
      bool sent = false;
      if (_wsChannel != null) {
        try {
          _wsChannel!.sink.add(jsonEncode({
            'type': 'ENCRYPTED_MESSAGE',
            'msgId': pending.msgId,
            'recipientId': pending.recipient.idHex,
            'payload': pending.wireBundleBase64,
          }));
          sent = true;
        } catch (_) {}
      }

      if (!sent) {
        try {
          final res = await http.post(
            Uri.parse('$backendUrl/api/v1/bundles/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'payloadBase64': pending.wireBundleBase64}),
          );
          if (res.statusCode == 200) {
            sent = true;
          }
        } catch (_) {}
      }

      if (sent) {
        _outboxQueue.removeWhere((p) => p.msgId == pending.msgId);
        final idx = _messages.indexWhere((m) => m.id == pending.msgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            status: MessageStatus.delivered,
            deliveredAtMs: DateTime.now().millisecondsSinceEpoch,
          );
        }
        flushedCount++;
      }
    }

    if (flushedCount > 0) {
      notifyListeners();
    }
    return flushedCount;
  }

  void _connectWebSocket() {
    if (_sessionToken == null) return;
    try {
      _wsSub?.cancel();
      _wsChannel?.sink.close();

      final uri = Uri.parse('$wsUrl/ws?token=$_sessionToken');
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSub = _wsChannel!.stream.listen(
        (data) => _handleWsMessage(data),
        onError: (err) => debugPrint('WebSocket error: $err'),
        onDone: () => debugPrint('WebSocket closed'),
      );
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
    }
  }

  @visibleForTesting
  Future<void> handleTestWsMessage(dynamic raw) => _handleWsMessage(raw);

  Future<void> _handleWsMessage(dynamic raw) async {
    try {
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'ENCRYPTED_MESSAGE') {
        final payload = msg['payload'] as String;
        final senderSignPub = msg['senderSignPubHex'] as String? ?? (_coupleInfo?.partner.signPublicKey ?? '');

        if (_deviceKeys != null && senderSignPub.isNotEmpty) {
          final decryptedRaw = await havenCrypto.decryptMessage(
            wireBundleBase64: payload,
            senderSignPubHex: senderSignPub,
            myKeys: _deviceKeys!,
          );

          String text = decryptedRaw;
          String? replyToId;
          String? replyToText;
          String? mediaUrl;
          String? mediaMimeType;
          bool blockSaving = false;
          int? audioDuration;
          int maxViews = 1;
          bool watermarkEnabled = true;

          try {
            if (decryptedRaw.startsWith('{') && decryptedRaw.endsWith('}')) {
              final parsed = jsonDecode(decryptedRaw) as Map<String, dynamic>;
              text = parsed['text'] as String? ?? '';
              replyToId = parsed['replyToId'] as String?;
              replyToText = parsed['replyToText'] as String?;
              mediaUrl = parsed['mediaUrl'] as String?;
              mediaMimeType = parsed['mediaMimeType'] as String?;
              blockSaving = parsed['blockSaving'] as bool? ?? false;
              audioDuration = parsed['audioDuration'] as int?;
              maxViews = parsed['maxViews'] as int? ?? 1;
              watermarkEnabled = parsed['watermarkEnabled'] as bool? ?? true;
            }
          } catch (_) {}

          final incoming = MessageItem(
            id: msg['msgId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            toIdHex: _currentUser?.id ?? '',
            fromIdHex: msg['senderId']?.toString() ?? (_coupleInfo?.partner.id ?? ''),
            text: text,
            isOutgoing: false,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            status: MessageStatus.delivered,
            replyToId: replyToId,
            replyToText: replyToText,
            mediaUrl: mediaUrl,
            mediaMimeType: mediaMimeType,
            blockSaving: blockSaving,
            audioDuration: audioDuration,
            maxViews: maxViews,
            watermarkEnabled: watermarkEnabled,
          );
          _messages.insert(0, incoming);
          notifyListeners();
        }
      } else if (type == 'HAVEN_SIGNAL') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final signalType = data['signalType'] as String? ?? '';
        final fromName = data['fromName'] as String? ?? 'Your Partner';

        if (signalType == 'BUZZ') {
          await _platformAdapter.remoteVibrate();
        } else if (signalType == 'RING') {
          await _platformAdapter.remoteVibrate();
          await _platformAdapter.remoteRingBell();
        } else if (signalType == 'FLASHLIGHT') {
          await _platformAdapter.remoteFlashlight();
        }

        _signalEvents.add({
          'signalType': signalType,
          'fromName': fromName,
          'timestamp': DateTime.now(),
        });
        notifyListeners();
      } else if (type == 'HAVEN_PERMISSIONS_UPDATED') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        if (data['permissions'] != null) {
          _partnerPermissions = CouplePermissions.fromJson(data['permissions'] as Map<String, dynamic>);
          notifyListeners();
        }
      } else if (type == 'HAVEN_MEDIA') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final media = EphemeralMedia.fromJson(data);
        final incoming = MessageItem(
          id: media.id,
          toIdHex: _currentUser?.id ?? '',
          fromIdHex: media.senderId,
          text: media.mimeType.startsWith('audio/') ? '🎤 Voice message' : '📷 Shared media',
          isOutgoing: false,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          status: MessageStatus.delivered,
          mediaUrl: media.mediaUrl,
          mediaMimeType: media.mimeType,
          blockSaving: media.blockSaving,
          audioDuration: media.durationSeconds,
          maxViews: media.maxViews,
          viewCount: media.viewCount,
          isConsumed: media.isConsumed,
          watermarkEnabled: media.watermarkEnabled,
        );
        _messages.insert(0, incoming);
        notifyListeners();
      } else if (type == 'HAVEN_MEDIA_VIEW_UPDATE') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final mediaId = data['mediaId'] as String? ?? '';
        final viewCount = data['viewCount'] as int? ?? 1;
        final isConsumed = data['isConsumed'] as bool? ?? false;
        final idx = _messages.indexWhere((m) => m.id == mediaId || m.mediaUrl?.contains(mediaId) == true);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            viewCount: viewCount,
            isConsumed: isConsumed,
          );
          notifyListeners();
        }
      } else if (type == 'USER_BLOCKED') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final blockerId = data['blockerId'] as String? ?? '';
        if (_coupleInfo?.partner.id == blockerId) {
          _coupleInfo = null;
          notifyListeners();
        }
      } else if (type == 'CONVERSATION_NUKED') {
        _messages.clear();
        notifyListeners();
      } else if (type == 'SUBSCRIPTION_UPDATED') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        if (data['subscription'] != null) {
          _subscription = SubscriptionInfo.fromJson(data['subscription'] as Map<String, dynamic>);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('WS message handle error: $e');
    }
  }

  /// Fetch all users blocked by the authenticated user.
  Future<List<BlockedUser>> fetchBlockedUsers() async {
    if (_sessionToken == null) return _blockedUsers;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/safety/blocked'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['blockedUsers'] != null) {
          final list = (data['blockedUsers'] as List<dynamic>)
              .map((item) => BlockedUser.fromJson(item as Map<String, dynamic>))
              .toList();
          _blockedUsers = list;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Blocked users fetch error: $e');
    }
    return _blockedUsers;
  }

  /// Block an abusive user and instantly sever any couple connection.
  Future<BlockedUser> blockUser(String blockedId, {String? reason}) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    try {
      final bodyMap = <String, dynamic>{'blockedId': blockedId};
      if (reason != null) bodyMap['reason'] = reason;
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/safety/block'),
        headers: _authHeaders,
        body: jsonEncode(bodyMap),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Block failed');
      }
      final record = BlockedUser.fromJson(data['blocked'] as Map<String, dynamic>);
      _blockedUsers.removeWhere((b) => b.blockedId == blockedId);
      _blockedUsers.add(record);

      // Sever active couple session if blocking current partner
      if (_coupleInfo?.partner.id == blockedId) {
        _coupleInfo = null;
      }
      notifyListeners();
      return record;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String blockedId) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    try {
      final res = await http.delete(
        Uri.parse('$backendUrl/api/v1/safety/block/$blockedId'),
        headers: _authHeaders,
      );
      if (res.statusCode != 200) {
        final data = jsonDecode(res.body);
        throw Exception(data['error'] ?? 'Unblock failed');
      }
      _blockedUsers.removeWhere((b) => b.blockedId == blockedId);
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Whether a user ID is currently blocked.
  bool isUserBlocked(String userId) {
    return _blockedUsers.any((b) => b.blockedId == userId);
  }

  /// Emergency mutual wipe: destroys all conversation messages and server media.
  Future<bool> nukeConversation(String partnerId) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/safety/nuke'),
        headers: _authHeaders,
        body: jsonEncode({'partnerId': partnerId}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Nuke failed');
      }
      _messages.clear();
      notifyListeners();
      return true;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Fetch or initialize Incognito Ghost Persona for anonymous chatting.
  Future<GhostPersona> fetchGhostPersona() async {
    if (_sessionToken == null) return _ghostPersona;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/v1/safety/ghost-persona'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ghostPersona'] != null) {
          _ghostPersona = GhostPersona.fromJson(data['ghostPersona'] as Map<String, dynamic>);
          _isGhostModeActive = _ghostPersona.isActive;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Ghost persona fetch error: $e');
    }
    return _ghostPersona;
  }

  /// Update Incognito Ghost Persona name/avatar.
  Future<GhostPersona> updateGhostPersona({
    String? aliasName,
    String? avatarPreset,
    bool? isActive,
  }) async {
    if (_sessionToken == null) throw Exception('Authentication required');
    try {
      final bodyMap = <String, dynamic>{};
      if (aliasName != null) bodyMap['aliasName'] = aliasName;
      if (avatarPreset != null) bodyMap['avatarPreset'] = avatarPreset;
      if (isActive != null) bodyMap['isActive'] = isActive;

      final res = await http.put(
        Uri.parse('$backendUrl/api/v1/safety/ghost-persona'),
        headers: _authHeaders,
        body: jsonEncode(bodyMap),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to update ghost persona');
      }
      _ghostPersona = GhostPersona.fromJson(data['ghostPersona'] as Map<String, dynamic>);
      if (isActive != null) {
        _isGhostModeActive = isActive;
      }
      notifyListeners();
      return _ghostPersona;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  /// Consume a view count for N-view ephemeral media.
  Future<Map<String, dynamic>> consumeMediaView(String mediaId) async {
    // 1. Immediately update local state
    final idx = _messages.indexWhere((m) => m.id == mediaId || m.mediaUrl?.contains(mediaId) == true);
    if (idx != -1) {
      final msg = _messages[idx];
      final newCount = msg.viewCount + 1;
      final consumed = (msg.maxViews > 0 && newCount >= msg.maxViews);
      _messages[idx] = msg.copyWith(
        viewCount: newCount,
        isConsumed: consumed,
      );
      notifyListeners();
    }

    if (_sessionToken == null) {
      return {'viewCount': 1, 'isConsumed': true, 'remainingViews': 0};
    }

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/v1/couples/media/view/$mediaId'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final count = data['viewCount'] as int? ?? 1;
        final consumed = data['isConsumed'] as bool? ?? false;
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            viewCount: count,
            isConsumed: consumed,
          );
          notifyListeners();
        }
        return data;
      }
    } catch (e) {
      debugPrint('Media view consume API error: $e');
    }
    return {'viewCount': 1, 'isConsumed': true, 'remainingViews': 0};
  }

  void logout() {
    _currentUser = null;
    _sessionToken = null;
    _coupleInfo = null;
    _isStealthUnlocked = false;
    _messages.clear();
    _contacts.clear();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _signalEvents.close();
    super.dispose();
  }
}

