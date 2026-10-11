enum MessageStatus { queued, forwarded, delivered, expired }

class Contact {
  final String name;
  final String idHex;
  final String signPubHex;
  final String encPubHex;
  final String cardString;
  final String? username;
  final String? moodStatus;

  Contact({
    required this.name,
    required this.idHex,
    required this.signPubHex,
    required this.encPubHex,
    required this.cardString,
    this.username,
    this.moodStatus,
  });

  factory Contact.fromMap(Map<Object?, Object?> map) => Contact(
    name: map['name'] as String,
    idHex: map['idHex'] as String,
    signPubHex: map['signPubHex'] as String,
    encPubHex: map['encPubHex'] as String,
    cardString: (map['cardString'] as String?) ?? '',
    username: map['username'] as String?,
    moodStatus: map['moodStatus'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'idHex': idHex,
    'signPubHex': signPubHex,
    'encPubHex': encPubHex,
    'cardString': cardString,
    'username': username,
    'moodStatus': moodStatus,
  };

  String get shortId => idHex.length > 8 ? idHex.substring(0, 8) : idHex;
}

class UserProfile {
  final String id;
  final String username;
  final String? email;
  final String displayName;
  final String? avatarUrl;
  final String signPublicKey;
  final String encPublicKey;
  final String moodStatus;

  UserProfile({
    required this.id,
    required this.username,
    this.email,
    required this.displayName,
    this.avatarUrl,
    required this.signPublicKey,
    required this.encPublicKey,
    this.moodStatus = 'Available',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String?,
    displayName: json['displayName'] as String? ?? json['username'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    signPublicKey: json['signPublicKey'] as String,
    encPublicKey: json['encPublicKey'] as String,
    moodStatus: json['moodStatus'] as String? ?? 'Available',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'signPublicKey': signPublicKey,
    'encPublicKey': encPublicKey,
    'moodStatus': moodStatus,
  };
}

class CoupleInfo {
  final String coupleId;
  final String status; // PENDING, ACCEPTED, REJECTED
  final bool isInitiator;
  final UserProfile partner;
  final String? myNicknameForPartner;
  final String? partnerNicknameForMe;
  final DateTime? anniversaryDate;
  final int? daysTogether;

  CoupleInfo({
    required this.coupleId,
    required this.status,
    required this.isInitiator,
    required this.partner,
    this.myNicknameForPartner,
    this.partnerNicknameForMe,
    this.anniversaryDate,
    this.daysTogether,
  });

  factory CoupleInfo.fromJson(Map<String, dynamic> json) => CoupleInfo(
    coupleId: json['coupleId'] as String,
    status: json['status'] as String,
    isInitiator: json['isInitiator'] as bool? ?? false,
    partner: UserProfile.fromJson(json['partner'] as Map<String, dynamic>),
    myNicknameForPartner: json['myNicknameForPartner'] as String?,
    partnerNicknameForMe: json['partnerNicknameForMe'] as String?,
    anniversaryDate: json['anniversaryDate'] != null
        ? DateTime.tryParse(json['anniversaryDate'] as String)
        : null,
    daysTogether: json['daysTogether'] as int?,
  );

  String get partnerName =>
      myNicknameForPartner?.isNotEmpty == true
          ? myNicknameForPartner!
          : partner.displayName;
}

class StealthSettings {
  final String appDisguise; // CALCULATOR, NOTES, WEATHER, OFFMESH
  final String decoyPin;
  final String notifDisguiseMode; // CAMOUFLAGE, DISCREET, NINJA, ROMANTIC
  final String fakeSenderTitle;
  final String fakeBodyPreview;

  StealthSettings({
    this.appDisguise = 'OFFMESH',
    this.decoyPin = '1234',
    this.notifDisguiseMode = 'ROMANTIC',
    this.fakeSenderTitle = 'OffMesh Haven',
    this.fakeBodyPreview = 'New message received',
  });

  factory StealthSettings.fromJson(Map<String, dynamic> json) => StealthSettings(
    appDisguise: json['appDisguise'] as String? ?? 'OFFMESH',
    decoyPin: json['decoyPin'] as String? ?? '1234',
    notifDisguiseMode: json['notifDisguiseMode'] as String? ?? 'ROMANTIC',
    fakeSenderTitle: json['fakeSenderTitle'] as String? ?? 'OffMesh Haven',
    fakeBodyPreview: json['fakeBodyPreview'] as String? ?? 'New message received',
  );

  Map<String, dynamic> toJson() => {
    'appDisguise': appDisguise,
    'decoyPin': decoyPin,
    'notifDisguiseMode': notifDisguiseMode,
    'fakeSenderTitle': fakeSenderTitle,
    'fakeBodyPreview': fakeBodyPreview,
  };

  StealthSettings copyWith({
    String? appDisguise,
    String? decoyPin,
    String? notifDisguiseMode,
    String? fakeSenderTitle,
    String? fakeBodyPreview,
  }) {
    return StealthSettings(
      appDisguise: appDisguise ?? this.appDisguise,
      decoyPin: decoyPin ?? this.decoyPin,
      notifDisguiseMode: notifDisguiseMode ?? this.notifDisguiseMode,
      fakeSenderTitle: fakeSenderTitle ?? this.fakeSenderTitle,
      fakeBodyPreview: fakeBodyPreview ?? this.fakeBodyPreview,
    );
  }
}

class MessageItem {
  final String id;
  final String toIdHex;
  final String fromIdHex;
  final String text;
  final bool isOutgoing;
  final int timestampMs;
  final int? deliveredAtMs;
  final MessageStatus status;
  final int relayHandoffs;
  final String? replyToId;
  final String? replyToText;
  final bool isEdited;
  final bool isDeleted;
  final String? mediaUrl;
  final String? mediaMimeType;
  final bool blockSaving;
  final int? audioDuration;
  final int maxViews; // 1, 2, 3, 4, 5, or 0 (unlimited within 7-day TTL)
  final int viewCount;
  final bool isConsumed;
  final bool watermarkEnabled;

  MessageItem({
    required this.id,
    required this.toIdHex,
    required this.fromIdHex,
    required this.text,
    required this.isOutgoing,
    required this.timestampMs,
    this.deliveredAtMs,
    this.status = MessageStatus.queued,
    this.relayHandoffs = 0,
    this.replyToId,
    this.replyToText,
    this.isEdited = false,
    this.isDeleted = false,
    this.mediaUrl,
    this.mediaMimeType,
    this.blockSaving = false,
    this.audioDuration,
    this.maxViews = 1,
    this.viewCount = 0,
    this.isConsumed = false,
    this.watermarkEnabled = true,
  });

  factory MessageItem.fromMap(Map<Object?, Object?> map) => MessageItem(
    id: map['id'] as String,
    toIdHex: map['toIdHex'] as String,
    fromIdHex: map['fromIdHex'] as String,
    text: map['text'] as String,
    isOutgoing: map['isOutgoing'] as bool,
    timestampMs: map['timestampMs'] as int,
    deliveredAtMs: (map['deliveredAtMs'] as int?) == 0
        ? null
        : map['deliveredAtMs'] as int?,
    status: MessageStatus.values.byName(map['status'] as String),
    relayHandoffs: map['relayHandoffs'] as int? ?? 0,
    replyToId: map['replyToId'] as String?,
    replyToText: map['replyToText'] as String?,
    isEdited: map['isEdited'] as bool? ?? false,
    isDeleted: map['isDeleted'] as bool? ?? false,
    mediaUrl: map['mediaUrl'] as String?,
    mediaMimeType: map['mediaMimeType'] as String?,
    blockSaving: map['blockSaving'] as bool? ?? false,
    audioDuration: map['audioDuration'] as int?,
    maxViews: map['maxViews'] as int? ?? 1,
    viewCount: map['viewCount'] as int? ?? 0,
    isConsumed: map['isConsumed'] as bool? ?? false,
    watermarkEnabled: map['watermarkEnabled'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'toIdHex': toIdHex,
    'fromIdHex': fromIdHex,
    'text': text,
    'isOutgoing': isOutgoing,
    'timestampMs': timestampMs,
    'deliveredAtMs': deliveredAtMs,
    'status': status.name,
    'relayHandoffs': relayHandoffs,
    'replyToId': replyToId,
    'replyToText': replyToText,
    'isEdited': isEdited,
    'isDeleted': isDeleted,
    'mediaUrl': mediaUrl,
    'mediaMimeType': mediaMimeType,
    'blockSaving': blockSaving,
    'audioDuration': audioDuration,
    'maxViews': maxViews,
    'viewCount': viewCount,
    'isConsumed': isConsumed,
    'watermarkEnabled': watermarkEnabled,
  };

  MessageItem copyWith({
    String? text,
    MessageStatus? status,
    int? deliveredAtMs,
    bool? isEdited,
    bool? isDeleted,
    int? viewCount,
    bool? isConsumed,
  }) {
    return MessageItem(
      id: id,
      toIdHex: toIdHex,
      fromIdHex: fromIdHex,
      text: text ?? this.text,
      isOutgoing: isOutgoing,
      timestampMs: timestampMs,
      deliveredAtMs: deliveredAtMs ?? this.deliveredAtMs,
      status: status ?? this.status,
      relayHandoffs: relayHandoffs,
      replyToId: replyToId,
      replyToText: replyToText,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      blockSaving: blockSaving,
      audioDuration: audioDuration,
      maxViews: maxViews,
      viewCount: viewCount ?? this.viewCount,
      isConsumed: isConsumed ?? this.isConsumed,
      watermarkEnabled: watermarkEnabled,
    );
  }

  int get remainingViews {
    if (maxViews <= 0) return 999;
    final left = maxViews - viewCount;
    return left > 0 ? left : 0;
  }

  String get statusBadge {
    switch (status) {
      case MessageStatus.queued:
        return 'QUEUED';
      case MessageStatus.forwarded:
        return 'FORWARDED';
      case MessageStatus.delivered:
        return 'DELIVERED (E2EE)';
      case MessageStatus.expired:
        return 'EXPIRED';
    }
  }
}

class DiscoveredPeer {
  final String name;
  final String address;
  final int rssi;
  final DateTime lastSeen;
  final bool isNearLinkPeer;

  DiscoveredPeer({
    required this.name,
    required this.address,
    required this.rssi,
    required this.lastSeen,
    this.isNearLinkPeer = false,
  });

  String get signalStrength {
    if (rssi > -60) return 'Strong signal';
    if (rssi > -75) return 'Medium signal';
    if (rssi > -90) return 'Weak signal';
    return 'Faint signal';
  }
}

class CouplePermissions {
  final bool allowVibrate;
  final bool allowRing;
  final bool allowFlashlight;
  final bool blockScreenshots;
  final bool blockSaving;
  final bool blockCopying;

  CouplePermissions({
    this.allowVibrate = true,
    this.allowRing = true,
    this.allowFlashlight = true,
    this.blockScreenshots = false,
    this.blockSaving = false,
    this.blockCopying = false,
  });

  factory CouplePermissions.fromJson(Map<String, dynamic> json) => CouplePermissions(
    allowVibrate: json['allowVibrate'] as bool? ?? true,
    allowRing: json['allowRing'] as bool? ?? true,
    allowFlashlight: json['allowFlashlight'] as bool? ?? true,
    blockScreenshots: json['blockScreenshots'] as bool? ?? false,
    blockSaving: json['blockSaving'] as bool? ?? false,
    blockCopying: json['blockCopying'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'allowVibrate': allowVibrate,
    'allowRing': allowRing,
    'allowFlashlight': allowFlashlight,
    'blockScreenshots': blockScreenshots,
    'blockSaving': blockSaving,
    'blockCopying': blockCopying,
  };

  CouplePermissions copyWith({
    bool? allowVibrate,
    bool? allowRing,
    bool? allowFlashlight,
    bool? blockScreenshots,
    bool? blockSaving,
    bool? blockCopying,
  }) => CouplePermissions(
    allowVibrate: allowVibrate ?? this.allowVibrate,
    allowRing: allowRing ?? this.allowRing,
    allowFlashlight: allowFlashlight ?? this.allowFlashlight,
    blockScreenshots: blockScreenshots ?? this.blockScreenshots,
    blockSaving: blockSaving ?? this.blockSaving,
    blockCopying: blockCopying ?? this.blockCopying,
  );
}

class EphemeralMedia {
  final String id;
  final String senderId;
  final String mediaUrl;
  final String mimeType;
  final bool blockSaving;
  final int? durationSeconds;
  final int maxViews; // 1, 2, 3, 4, 5, or 0 (unlimited within 7 days)
  final int viewCount;
  final bool isConsumed;
  final bool watermarkEnabled;
  final DateTime expiresAt;

  EphemeralMedia({
    required this.id,
    required this.senderId,
    required this.mediaUrl,
    required this.mimeType,
    this.blockSaving = false,
    this.durationSeconds,
    this.maxViews = 1,
    this.viewCount = 0,
    this.isConsumed = false,
    this.watermarkEnabled = true,
    required this.expiresAt,
  });

  factory EphemeralMedia.fromJson(Map<String, dynamic> json) => EphemeralMedia(
    id: json['id'] as String? ?? json['mediaId'] as String? ?? '',
    senderId: json['senderId'] as String? ?? '',
    mediaUrl: json['mediaUrl'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? '',
    blockSaving: json['blockSaving'] as bool? ?? false,
    durationSeconds: json['durationSeconds'] as int?,
    maxViews: json['maxViews'] as int? ?? 1,
    viewCount: json['viewCount'] as int? ?? 0,
    isConsumed: json['isConsumed'] as bool? ?? false,
    watermarkEnabled: json['watermarkEnabled'] as bool? ?? true,
    expiresAt: json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'] as String) ?? DateTime.now().add(const Duration(days: 7))
        : DateTime.now().add(const Duration(days: 7)),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'mediaUrl': mediaUrl,
    'mimeType': mimeType,
    'blockSaving': blockSaving,
    'durationSeconds': durationSeconds,
    'maxViews': maxViews,
    'viewCount': viewCount,
    'isConsumed': isConsumed,
    'watermarkEnabled': watermarkEnabled,
    'expiresAt': expiresAt.toIso8601String(),
  };

  int get remainingViews {
    if (maxViews <= 0) return 999;
    final left = maxViews - viewCount;
    return left > 0 ? left : 0;
  }

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }
}

class GhostPersona {
  final String id;
  final String aliasName;
  final String avatarPreset;
  final bool isActive;

  GhostPersona({
    this.id = '',
    this.aliasName = 'Aurora_Sanctuary',
    this.avatarPreset = 'AVATAR_STARLIGHT',
    this.isActive = true,
  });

  factory GhostPersona.fromJson(Map<String, dynamic> json) => GhostPersona(
    id: json['id'] as String? ?? '',
    aliasName: json['aliasName'] as String? ?? 'Aurora_Sanctuary',
    avatarPreset: json['avatarPreset'] as String? ?? 'AVATAR_STARLIGHT',
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'aliasName': aliasName,
    'avatarPreset': avatarPreset,
    'isActive': isActive,
  };
}

class BlockedUser {
  final String id;
  final String blockerId;
  final String blockedId;
  final String? reason;
  final DateTime createdAt;

  BlockedUser({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    this.reason,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    id: json['id'] as String,
    blockerId: json['blockerId'] as String,
    blockedId: json['blockedId'] as String,
    reason: json['reason'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'blockerId': blockerId,
    'blockedId': blockedId,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };
}

class ChatCustomization {
  final String? wallpaperUrl;
  final String themeColor;

  ChatCustomization({
    this.wallpaperUrl,
    this.themeColor = '#E11D48',
  });

  factory ChatCustomization.fromJson(Map<String, dynamic> json) => ChatCustomization(
    wallpaperUrl: json['wallpaperUrl'] as String?,
    themeColor: json['themeColor'] as String? ?? '#E11D48',
  );

  Map<String, dynamic> toJson() => {
    'wallpaperUrl': wallpaperUrl,
    'themeColor': themeColor,
  };
}

class SubscriptionInfo {
  final String status; // TRIAL, ACTIVE, EXPIRED, CANCELLED
  final String plan;
  final double priceUsd;
  final bool isTrialActive;
  final bool isSubscribed;
  final bool hasChatAccess;
  final int trialDaysRemaining;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt;

  SubscriptionInfo({
    this.status = 'TRIAL',
    this.plan = 'MONTHLY_5',
    this.priceUsd = 5.0,
    this.isTrialActive = true,
    this.isSubscribed = false,
    this.hasChatAccess = true,
    this.trialDaysRemaining = 3,
    this.trialEndsAt,
    this.subscriptionEndsAt,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
    status: json['status'] as String? ?? 'TRIAL',
    plan: json['plan'] as String? ?? 'MONTHLY_5',
    priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 5.0,
    isTrialActive: json['isTrialActive'] as bool? ?? false,
    isSubscribed: json['isSubscribed'] as bool? ?? false,
    hasChatAccess: json['hasChatAccess'] as bool? ?? false,
    trialDaysRemaining: json['trialDaysRemaining'] as int? ?? 0,
    trialEndsAt: json['trialEndsAt'] != null ? DateTime.tryParse(json['trialEndsAt'] as String) : null,
    subscriptionEndsAt: json['subscriptionEndsAt'] != null ? DateTime.tryParse(json['subscriptionEndsAt'] as String) : null,
  );

  SubscriptionInfo copyWith({
    String? status,
    String? plan,
    double? priceUsd,
    bool? isTrialActive,
    bool? isSubscribed,
    bool? hasChatAccess,
    int? trialDaysRemaining,
    DateTime? trialEndsAt,
    DateTime? subscriptionEndsAt,
  }) => SubscriptionInfo(
    status: status ?? this.status,
    plan: plan ?? this.plan,
    priceUsd: priceUsd ?? this.priceUsd,
    isTrialActive: isTrialActive ?? this.isTrialActive,
    isSubscribed: isSubscribed ?? this.isSubscribed,
    hasChatAccess: hasChatAccess ?? this.hasChatAccess,
    trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
    trialEndsAt: trialEndsAt ?? this.trialEndsAt,
    subscriptionEndsAt: subscriptionEndsAt ?? this.subscriptionEndsAt,
  );
}

