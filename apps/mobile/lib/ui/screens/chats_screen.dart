import 'package:flutter/material.dart';
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
  Contact? _selectedRecipient;

  @override
  void dispose() {
    _textCtrl.dispose();
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mesh Messages'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Mesh delivery stats',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Store-Carry-Forward Mesh'),
                      content: const Text(
                        'Messages are E2E encrypted with ChaCha20-Poly1305. '
                        'When offline, messages jump hop-by-hop across passing smartphones. '
                        'When any carrier device connects to internet or meets the recipient, '
                        'a signed cryptographic receipt is returned to confirm honest delivery.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Contact picker row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: NearLinkTheme.surface,
                child: Row(
                  children: [
                    const Text('Send to: ', style: TextStyle(color: NearLinkTheme.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: contacts.isEmpty
                          ? const Text(
                              'No contacts yet. Add via QR!',
                              style: TextStyle(color: Colors.amberAccent, fontSize: 13),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<Contact>(
                                value: _selectedRecipient,
                                isDense: true,
                                dropdownColor: NearLinkTheme.surfaceElevated,
                                items: contacts.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '${c.name} (${c.shortId})',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
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

              // Messages feed
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: NearLinkTheme.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No messages yet.\nSelect a contact and send an encrypted offline message.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: NearLinkTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, i) {
                          final m = messages[i];
                          final timeStr = DateFormat('HH:mm:ss').format(
                            DateTime.fromMillisecondsSinceEpoch(m.timestampMs),
                          );

                          Color statusColor;
                          IconData statusIcon;
                          switch (m.status) {
                            case MessageStatus.queued:
                              statusColor = NearLinkTheme.statusYellow;
                              statusIcon = Icons.hourglass_top;
                              break;
                            case MessageStatus.forwarded:
                              statusColor = NearLinkTheme.accentCyan;
                              statusIcon = Icons.forward_to_inbox;
                              break;
                            case MessageStatus.delivered:
                              statusColor = NearLinkTheme.statusGreen;
                              statusIcon = Icons.check_circle;
                              break;
                            case MessageStatus.expired:
                              statusColor = Colors.redAccent;
                              statusIcon = Icons.cancel;
                              break;
                          }

                          return Align(
                            alignment: m.isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.82,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: m.isOutgoing ? NearLinkTheme.surfaceElevated : NearLinkTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: m.isOutgoing ? NearLinkTheme.accentCyan.withOpacity(0.3) : NearLinkTheme.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.text,
                                    style: const TextStyle(fontSize: 15, color: NearLinkTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: const TextStyle(fontSize: 11, color: NearLinkTheme.textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(statusIcon, size: 13, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        m.statusBadge,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Composer bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: NearLinkTheme.surface,
                  border: Border(top: BorderSide(color: NearLinkTheme.border)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Type an encrypted offline message...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: NearLinkTheme.accentCyan),
                        icon: const Icon(Icons.send, color: Colors.black),
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
