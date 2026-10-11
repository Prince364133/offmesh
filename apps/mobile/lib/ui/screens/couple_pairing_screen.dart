import 'package:flutter/material.dart';
import '../../core/haven_engine.dart';
import '../../core/models.dart';
import '../theme.dart';

class CouplePairingScreen extends StatefulWidget {
  const CouplePairingScreen({super.key});

  @override
  State<CouplePairingScreen> createState() => _CouplePairingScreenState();
}

class _CouplePairingScreenState extends State<CouplePairingScreen> {
  final _searchCtrl = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _searching = false;
  String? _message;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _message = null;
    });

    try {
      final results = await HavenEngine.instance.searchUsers(q);
      setState(() {
        _searchResults = results;
        if (results.isEmpty) {
          _message = 'No users found with that username.';
        }
      });
    } catch (e) {
      setState(() => _message = 'Search failed: $e');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _sendPairRequest(UserProfile user) async {
    final engine = HavenEngine.instance;
    try {
      await engine.requestCouple(user.username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent couple invite to @${user.username} ❤️'),
          backgroundColor: OffMeshTheme.passionRose,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = HavenEngine.instance;

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final couple = engine.coupleInfo;
        final isPaired = engine.isPaired;

        return Scaffold(
          backgroundColor: OffMeshTheme.romanticBackground,
          appBar: AppBar(
            title: const Text('Partner & Relationship'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Status',
                onPressed: () => engine.fetchCoupleStatus(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // If already paired: Show Romantic Milestone Card
              if (isPaired && couple != null) ...[
                _buildPairedDashboard(context, couple),
                const SizedBox(height: 24),
              ] else if (couple != null && couple.status == 'PENDING') ...[
                _buildPendingCard(context, couple),
                const SizedBox(height: 24),
              ] else ...[
                // Search & Connect Section
                _buildSearchSection(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPairedDashboard(BuildContext context, CoupleInfo couple) {
    final engine = HavenEngine.instance;
    final partner = couple.partner;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: OffMeshTheme.romanticSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OffMeshTheme.passionRose.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: OffMeshTheme.passionRose.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _avatar(engine.currentUser?.displayName ?? 'You'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.favorite, color: OffMeshTheme.passionRose, size: 32),
              ),
              _avatar(couple.partnerName),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            couple.partnerName,
            style: const TextStyle(
              color: OffMeshTheme.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '@${partner.username}',
            style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Days Together Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: OffMeshTheme.romanticSurfaceSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OffMeshTheme.borderRomantic),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded, color: OffMeshTheme.champagneGold, size: 22),
                const SizedBox(width: 10),
                Text(
                  couple.daysTogether != null
                      ? 'Together for ${couple.daysTogether} Days 💕'
                      : 'Exclusive Couple Channel ✨',
                  style: const TextStyle(
                    color: OffMeshTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Partner Mood Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: OffMeshTheme.statusOnline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${partner.moodStatus}',
                style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, CoupleInfo couple) {
    final engine = HavenEngine.instance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OffMeshTheme.romanticSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OffMeshTheme.champagneGold.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: OffMeshTheme.champagneGold, size: 36),
          const SizedBox(height: 12),
          Text(
            couple.isInitiator ? 'Couple Request Sent' : 'Incoming Couple Invite!',
            style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            couple.isInitiator
                ? 'Waiting for @${couple.partner.username} to accept your connection...'
                : '@${couple.partner.username} invited you to become an exclusive couple ❤️',
            textAlign: TextAlign.center,
            style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (!couple.isInitiator) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => engine.respondCouple(couple.coupleId, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OffMeshTheme.passionRose,
                    ),
                    child: const Text('Accept Connection ❤️'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => engine.respondCouple(couple.coupleId, false),
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find Your Partner by Username',
          style: TextStyle(
            color: OffMeshTheme.textWhite,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Search for your love with their private @username. No phone numbers required.',
          style: TextStyle(color: OffMeshTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Search Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: OffMeshTheme.textWhite),
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Enter username (e.g. juliet)',
                  prefixIcon: const Icon(Icons.search, color: OffMeshTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: OffMeshTheme.passionRose),
                    onPressed: _search,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_searching)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!, style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 14)),
          ),

        // Results List
        ..._searchResults.map((user) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: OffMeshTheme.passionRose,
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(user.displayName, style: const TextStyle(color: OffMeshTheme.textWhite, fontWeight: FontWeight.w600)),
            subtitle: Text('@${user.username}', style: const TextStyle(color: OffMeshTheme.textMuted, fontSize: 13)),
            trailing: ElevatedButton.icon(
              onPressed: () => _sendPairRequest(user),
              icon: const Icon(Icons.favorite, size: 16),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OffMeshTheme.passionRose,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _avatar(String name) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: OffMeshTheme.romanticSurfaceRaised,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: OffMeshTheme.textWhite, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
