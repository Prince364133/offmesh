enum MessageStatus {
  queued,
  forwarded,
  delivered,
  expired,
}

class Contact {
  final String name;
  final String idHex;
  final String signPubHex;
  final String encPubHex;
  final String cardString;

  Contact({
    required this.name,
    required this.idHex,
    required this.signPubHex,
    required this.encPubHex,
    required this.cardString,
  });

  String get shortId => idHex.length > 8 ? idHex.substring(0, 8) : idHex;
}

class MessageItem {
  final String id;
  final String toIdHex;
  final String fromIdHex;
  final String text;
  final bool isOutgoing;
  final int timestampMs;
  int? deliveredAtMs;
  MessageStatus status;
  int relayHandoffs;

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
  });

  String get statusBadge {
    switch (status) {
      case MessageStatus.queued:
        return 'QUEUED';
      case MessageStatus.forwarded:
        return 'FORWARDED (Hops: $relayHandoffs)';
      case MessageStatus.delivered:
        return 'DELIVERED (Receipt verified)';
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
    if (rssi > -60) return 'Strong (< 2m)';
    if (rssi > -75) return 'Medium (2-5m)';
    if (rssi > -90) return 'Weak (5-15m)';
    return 'Faint (> 15m)';
  }
}
