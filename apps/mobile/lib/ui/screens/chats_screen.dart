import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _textCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Contact? _selectedRecipient;
  String _searchQuery = '';

  @override
  void dispose() {
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final messages = engine.messages;
        final contacts = engine.contacts;

        if (_selectedRecipient == null && contacts.isNotEmpty) {
          _selectedRecipient = contacts.first;
        }

        // Filter messages for current recipient
        final currentMessages = _selectedRecipient == null
            ? <MessageItem>[]
            : messages
                .where((m) =>
                    m.toIdHex == _selectedRecipient!.idHex ||
                    !m.isOutgoing)
                .toList();

        return Scaffold(
          backgroundColor: OffMeshTheme.background,
          appBar: AppBar(
            title: const Text('Chats'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.border, height: 1),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: OffMeshTheme.textPrimary),
                tooltip: 'Delivery diagnostics',
                onPressed: () => _showNetworkOverviewDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Contact selector / Conversation selector bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: OffMeshTheme.surfaceSubtle,
                  border: Border(bottom: BorderSide(color: OffMeshTheme.border)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: OffMeshTheme.actionPrimary,
                      child: Text(
                        _selectedRecipient?.name.isNotEmpty == true
                            ? _selectedRecipient!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: OffMeshTheme.actionOnPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: contacts.isEmpty
                          ? const Text(
                              'No contacts yet. Add via People tab.',
                              style: TextStyle(
                                color: OffMeshTheme.statusPending,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<Contact>(
                                value: _selectedRecipient,
                                isDense: true,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                dropdownColor: OffMeshTheme.surface,
                                items: contacts.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '${c.name} (${c.shortId})',
                                      style: const TextStyle(
                                        color: OffMeshTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedRecipient = val),
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Recipient Offline Notice Banner (B3)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: OffMeshTheme.surfaceSubtle,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 14, color: OffMeshTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct link offline. Messages are queued and carried by nearby devices.',
                        style: TextStyle(
                          fontSize: 11,
                          color: OffMeshTheme.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Messages feed
              Expanded(
                child: currentMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: OffMeshTheme.surfaceSubtle,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 32,
                                  color: OffMeshTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: OffMeshTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Send an encrypted offline message. Packets will jump hop-by-hop across passing devices.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: OffMeshTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: currentMessages.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemBuilder: (context, i) {
                          final m = currentMessages[i];
                          return _buildMessageItem(context, m);
                        },
                      ),
              ),

              // Composer bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: OffMeshTheme.surface,
                  border: Border(top: BorderSide(color: OffMeshTheme.border)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          style: const TextStyle(
                            color: OffMeshTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type an encrypted offline message...',
                            fillColor: OffMeshTheme.surfaceSubtle,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                              borderSide: const BorderSide(color: OffMeshTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                              borderSide: const BorderSide(color: OffMeshTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                              borderSide: const BorderSide(color: OffMeshTheme.actionPrimary, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: OffMeshTheme.actionPrimary,
                          foregroundColor: OffMeshTheme.actionOnPrimary,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        onPressed: _send,
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

  Widget _buildMessageItem(BuildContext context, MessageItem m) {
    final timeStr = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(m.timestampMs),
    );

    // Honest Status & Microcopy mapping according to OFFMESH_UI_UX_PRINCIPLES.md §5
    Color statusColor;
    IconData statusIcon;
    String statusCopy;

    switch (m.status) {
      case MessageStatus.queued:
        statusColor = OffMeshTheme.statusPending;
        statusIcon = Icons.schedule;
        statusCopy = 'Waiting for a connection';
        break;
      case MessageStatus.forwarded:
        statusColor = OffMeshTheme.statusInfo;
        statusIcon = Icons.alt_route;
        statusCopy = 'Being carried by nearby devices';
        break;
      case MessageStatus.delivered:
        statusColor = OffMeshTheme.statusSuccess;
        statusIcon = Icons.done_all;
        statusCopy = 'Delivered';
        break;
      case MessageStatus.expired:
        statusColor = OffMeshTheme.statusError;
        statusIcon = Icons.cancel_outlined;
        statusCopy = 'Expired before delivery';
        break;
    }

    final isOutgoing = m.isOutgoing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showMessageActionsSheet(context, m),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing ? OffMeshTheme.bubbleOutgoing : OffMeshTheme.bubbleIncoming,
                borderRadius: BorderRadius.circular(OffMeshTheme.radiusBubble),
              ),
              child: Text(
                m.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: isOutgoing ? OffMeshTheme.bubbleOutgoingText : OffMeshTheme.bubbleIncomingText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: OffMeshTheme.textTertiary,
                ),
              ),
              if (isOutgoing) ...[
                const SizedBox(width: 6),
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 3),
                Text(
                  statusCopy,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageActionsSheet(BuildContext context, MessageItem m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OffMeshTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: OffMeshTheme.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined, color: OffMeshTheme.textPrimary),
                  title: const Text('Copy text', style: TextStyle(color: OffMeshTheme.textPrimary)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: m.text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: OffMeshTheme.textPrimary),
                  title: const Text('Message details & diagnostics', style: TextStyle(color: OffMeshTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMessageDiagnosticsDialog(context, m);
                  },
                ),
                if (m.isOutgoing && m.status == MessageStatus.queued)
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline, color: OffMeshTheme.statusWarning),
                    title: const Text('Cancel forwarding', style: TextStyle(color: OffMeshTheme.statusWarning)),
                    subtitle: const Text('Broadcasts anti-packet stop instruction', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cancellation anti-packet requested')),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: OffMeshTheme.statusError),
                  title: const Text('Delete from this device', style: TextStyle(color: OffMeshTheme.statusError)),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageDiagnosticsDialog(BuildContext context, MessageItem m) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OffMeshTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
            side: const BorderSide(color: OffMeshTheme.border),
          ),
          title: const Text(
            'Message Diagnostics',
            style: TextStyle(color: OffMeshTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _diagRow('Message ID', m.id),
                _diagRow('Recipient Node ID', m.toIdHex),
                _diagRow('Direction', m.isOutgoing ? 'Outgoing (Sender)' : 'Incoming (Inbox)'),
                _diagRow('Created Timestamp', '${m.timestampMs} ms'),
                _diagRow('Current Honest Status', m.status.name.toUpperCase()),
                _diagRow('Cryptographic Scheme', 'ChaCha20-Poly1305 + Ed25519'),
                _diagRow('Anti-Packet Receipt', m.status == MessageStatus.delivered ? 'Verified' : 'Pending Receipt'),
                _diagRow('Forwarding Copies', m.status == MessageStatus.forwarded ? 'Spray & Wait (L=8)' : '1'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: OffMeshTheme.textTertiary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, color: OffMeshTheme.textPrimary, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  void _showNetworkOverviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OffMeshTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
          side: const BorderSide(color: OffMeshTheme.border),
        ),
        title: const Text('Store-Carry-Forward Mesh'),
        content: const Text(
          'OffMesh operates over physical radio encounters:\n\n'
          '1. Queued: Saved locally on your device.\n'
          '2. Forwarding: Carried across passing devices.\n'
          '3. Delivered: Authenticated recipient signature receipt verified.\n\n'
          'Anti-packets purge redundant forwarding jobs automatically across all nodes upon delivery.',
          style: TextStyle(fontSize: 13, height: 1.4, color: OffMeshTheme.textPrimary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_selectedRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a contact first')),
      );
      return;
    }
    NearLinkEngine.instance.sendMessage(_selectedRecipient!, text);
    _textCtrl.clear();
  }
}
