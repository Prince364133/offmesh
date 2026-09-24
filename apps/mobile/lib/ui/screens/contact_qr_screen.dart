import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/engine.dart';
import '../../core/crypto.dart';
import '../theme.dart';

class ContactQrScreen extends StatefulWidget {
  const ContactQrScreen({super.key});

  @override
  State<ContactQrScreen> createState() => _ContactQrScreenState();
}

class _ContactQrScreenState extends State<ContactQrScreen> {
  final _pasteCtrl = TextEditingController();

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final me = engine.me;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Contact Card'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share Card',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: me.cardString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact card copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // QR Display Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: me.cardString,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          me.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${me.idHex.substring(0, 16)}...',
                          style: const TextStyle(fontSize: 12, color: NearLinkTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Card (NL1:...)'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: me.cardString));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card string copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add Friend by Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Friend Contact',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Scan their QR code or paste their NL1:... contact card',
                          style: TextStyle(fontSize: 12, color: NearLinkTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pasteCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Paste NL1:... card',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NearLinkTheme.accentCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              final text = _pasteCtrl.text.trim();
                              if (text.isEmpty) return;
                              try {
                                engine.addContact(text);
                                _pasteCtrl.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contact added successfully!')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Invalid card: $e')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contacts list with Safety Codes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified Contacts (${engine.contacts.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...engine.contacts.map((c) {
                          final safety = NearLinkCrypto.safetyCode(
                            NearLinkCrypto.unhex(me.idHex),
                            NearLinkCrypto.unhex(c.idHex),
                          );

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: NearLinkTheme.accentPurple.withOpacity(0.3),
                              child: Text(c.name.substring(0, 1).toUpperCase()),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Safety Code: $safety\nID: ${c.shortId}',
                                style: const TextStyle(fontSize: 11, color: NearLinkTheme.textSecondary)),
                          );
                        }),
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
}
