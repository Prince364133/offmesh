import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/haven_engine.dart';
import '../theme.dart';
import 'chats_screen.dart';
import 'couple_pairing_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final haven = HavenEngine.instance;

    return ListenableBuilder(
      listenable: haven,
      builder: (context, _) {
        final couple = haven.coupleInfo;
        final isPaired = haven.isPaired;
        final messages = haven.messages;
        final lastMsg = messages.isNotEmpty ? messages.first : null;

        return Scaffold(
          backgroundColor: OffMeshTheme.romanticBackground,
          appBar: AppBar(
            backgroundColor: OffMeshTheme.romanticBackground,
            title: const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: OffMeshTheme.passionRose, size: 22),
                SizedBox(width: 8),
                Text(
                  'Chats',
                  style: TextStyle(
                    color: OffMeshTheme.textWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.lock_outline, color: OffMeshTheme.passionRose),
                tooltip: 'Lock Sanctuary',
                onPressed: () {
                  haven.lockStealth();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App locked into Decoy Calculator mode 🔒')),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.borderRomantic, height: 1),
            ),
          ),
          body: isPaired && couple != null
              ? ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildChatTile(context, haven, couple, lastMsg),
                  ],
                )
              : _buildUnpairedBanner(context),
        );
      },
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    HavenEngine haven,
    dynamic couple,
    dynamic lastMsg,
  ) {
    String previewText = 'No messages yet. Send a secret love note 💕';
    String timeStr = '';

    if (lastMsg != null) {
      if (lastMsg.isDeleted) {
        previewText = '🚫 This message was deleted';
      } else if (lastMsg.mediaUrl != null) {
        if (lastMsg.mediaMimeType?.startsWith('audio/') == true) {
          previewText = '🎤 Voice message (${lastMsg.audioDuration ?? 5}s)';
        } else {
          previewText = '📷 Ephemeral photo (7-day)';
        }
      } else {
        previewText = lastMsg.text;
      }
      timeStr = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(lastMsg.timestampMs));
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OffMeshTheme.borderRomantic, width: 0.5)),
        ),
        child: Row(
          children: [
            // Partner Avatar with Heart Badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: OffMeshTheme.passionRose,
                  child: Text(
                    couple.partnerName.isNotEmpty ? couple.partnerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: OffMeshTheme.romanticBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Name, preview, and days together
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            couple.partnerName,
                            style: const TextStyle(
                              color: OffMeshTheme.textWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: OffMeshTheme.passionRose.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              couple.daysTogether != null ? '❤️ Day ${couple.daysTogether}' : '❤️ Couple',
                              style: const TextStyle(
                                color: OffMeshTheme.passionRose,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (lastMsg?.isOutgoing == true) ...[
                        const Icon(Icons.done_all, size: 14, color: OffMeshTheme.passionRose),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: lastMsg != null ? OffMeshTheme.textWhite.withOpacity(0.85) : OffMeshTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, size: 12, color: OffMeshTheme.passionRose),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpairedBanner(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OffMeshTheme.passionRose.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 56),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Private Couple Sanctuary',
            style: TextStyle(
              color: OffMeshTheme.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for your partner by their unique @username.\nAll messages, photos, and calls are zero-knowledge E2EE.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: OffMeshTheme.passionRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Find Partner & Pair', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CouplePairingScreen()),
              );
            },
          ),
        ],
        ),
      ),
    );
  }
}
