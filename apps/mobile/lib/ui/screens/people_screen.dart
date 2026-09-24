import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = NearLinkEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final myCard = engine.myCard;
        final contacts = engine.contacts.where((c) {
          if (_searchQuery.isEmpty) return true;
          return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.shortId.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return Scaffold(
          backgroundColor: OffMeshTheme.background,
          appBar: AppBar(
            title: const Text('People'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: OffMeshTheme.border, height: 1),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_2, color: OffMeshTheme.textPrimary),
                tooltip: 'My QR Card',
                onPressed: () => _showMyCardDialog(context, myCard),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: OffMeshTheme.textPrimary),
                tooltip: 'Add Contact',
                onPressed: () => _showAddContactDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search field (subtle surface #F7F7F8)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 14, color: OffMeshTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: OffMeshTheme.textTertiary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: OffMeshTheme.textTertiary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    fillColor: OffMeshTheme.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                      borderSide: const BorderSide(color: OffMeshTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OffMeshTheme.radiusInput),
                      borderSide: const BorderSide(color: OffMeshTheme.border),
                    ),
                  ),
                ),
              ),

              // My Card Quick Header Row
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: OffMeshTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
                  border: Border.all(color: OffMeshTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: OffMeshTheme.actionPrimary,
                      child: const Icon(Icons.fingerprint, color: OffMeshTheme.actionOnPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            myCard.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: OffMeshTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Node: ${myCard.shortId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: OffMeshTheme.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showMyCardDialog(context, myCard),
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Show QR', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Contacts List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'VERIFIED CONTACTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: OffMeshTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: OffMeshTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${contacts.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: OffMeshTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contacts list
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 40, color: OffMeshTheme.textTertiary),
                            const SizedBox(height: 12),
                            const Text(
                              'No contacts found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: OffMeshTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scan a friend\'s QR card to begin messaging offline.',
                              style: TextStyle(fontSize: 13, color: OffMeshTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddContactDialog(context),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Contact'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: OffMeshTheme.border,
                          height: 1,
                          indent: 68,
                        ),
                        itemBuilder: (context, i) {
                          final c = contacts[i];
                          final safetyCodeFormatted = engine.getSafetyCodeFor(c);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: OffMeshTheme.actionPrimary,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: OffMeshTheme.actionOnPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: OffMeshTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 14, color: OffMeshTheme.statusSuccess),
                              ],
                            ),
                            subtitle: Text(
                              'Safety: $safetyCodeFormatted',
                              style: const TextStyle(
                                fontSize: 11,
                                color: OffMeshTheme.textTertiary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.chevron_right, color: OffMeshTheme.textTertiary),
                              onPressed: () => _showContactProfile(context, c),
                            ),
                            onTap: () => _showContactProfile(context, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMyCardDialog(BuildContext context, Contact card) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OffMeshTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
            side: const BorderSide(color: OffMeshTheme.border),
          ),
          title: Center(
            child: Text(
              card.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan in person to add contact and exchange public encryption keys.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: OffMeshTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OffMeshTheme.border),
                ),
                child: QrImageView(
                  data: card.cardString,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OffMeshTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.cardString,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: OffMeshTheme.textSecondary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: OffMeshTheme.textPrimary),
                      tooltip: 'Copy Card String',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: card.cardString));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact card string copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
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

  void _showAddContactDialog(BuildContext context) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OffMeshTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OffMeshTheme.radiusCard),
            side: const BorderSide(color: OffMeshTheme.border),
          ),
          title: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the "NL1:..." contact card string obtained from an optical QR scan or direct exchange:',
                style: TextStyle(fontSize: 13, color: OffMeshTheme.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'NL1:AA5Bb2J... (Paste card string)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: OffMeshTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  final added = NearLinkEngine.instance.addContactFromCardString(text);
                  Navigator.pop(ctx);
                  if (added != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added verified contact: ${added.name}')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid NL1 contact card format')),
                    );
                  }
                }
              },
              child: const Text('Add Contact'),
            ),
          ],
        );
      },
    );
  }

  void _showContactProfile(BuildContext context, Contact c) {
    final formattedSafety = NearLinkEngine.instance.getSafetyCodeFor(c);

    showModalBottomSheet(
      context: context,
      backgroundColor: OffMeshTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: OffMeshTheme.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: OffMeshTheme.actionPrimary,
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 20, color: OffMeshTheme.actionOnPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OffMeshTheme.textPrimary)),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 16, color: OffMeshTheme.statusSuccess),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Node ID: ${c.idHex}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: OffMeshTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '20-Digit Out-of-Band Safety Number',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: OffMeshTheme.textTertiary),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: OffMeshTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OffMeshTheme.border),
                  ),
                  child: Text(
                    formattedSafety,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: OffMeshTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Compare this number with your contact in person to ensure no third-party interception (MITM).',
                  style: TextStyle(fontSize: 11, color: OffMeshTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Send Message'),
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
