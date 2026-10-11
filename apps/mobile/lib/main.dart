import 'package:flutter/material.dart';

import 'core/engine.dart';
import 'core/haven_engine.dart';
import 'ui/theme.dart';
import 'ui/screens/chats_list_screen.dart';
import 'ui/screens/couple_pairing_screen.dart';
import 'ui/screens/nearby_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HavenEngine.instance.init();
  runApp(OffMeshApp(engine: OffMeshEngine.instance));
}

class OffMeshApp extends StatefulWidget {
  final OffMeshEngine? engine;
  const OffMeshApp({super.key, this.engine});

  @override
  State<OffMeshApp> createState() => _OffMeshAppState();
}

class _OffMeshAppState extends State<OffMeshApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OffMesh Haven',
      debugShowCheckedModeBanner: false,
      theme: OffMeshTheme.romanticTheme,
      home: EngineScope(
        engine: widget.engine ?? OffMeshEngine.instance,
        child: const _AppRootRouter(),
      ),
    );
  }
}

class _AppRootRouter extends StatefulWidget {
  const _AppRootRouter();

  @override
  State<_AppRootRouter> createState() => _AppRootRouterState();
}

class _AppRootRouterState extends State<_AppRootRouter> {
  @override
  Widget build(BuildContext context) {
    final haven = HavenEngine.instance;

    return ListenableBuilder(
      listenable: haven,
      builder: (context, _) {
        // 1. If user is not authenticated, show AuthScreen:
        if (!haven.isAuthenticated) {
          return AuthScreen(
            onAuthenticated: () => setState(() {}),
          );
        }

        // 2. Authenticated: Main 4-Tab Couple & Mesh Navigation
        return const MainNavigationScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    ChatsListScreen(),
    CouplePairingScreen(),
    NearbyScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: OffMeshTheme.borderRomantic, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: OffMeshTheme.romanticSurface,
          selectedItemColor: OffMeshTheme.passionRose,
          unselectedItemColor: OffMeshTheme.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Sanctuary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_searching),
              activeIcon: Icon(Icons.bluetooth_connected),
              label: 'Nearby Mesh',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.security),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
