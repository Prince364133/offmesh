import 'package:flutter/material.dart';
import 'core/engine.dart';
import 'ui/theme.dart';
import 'ui/screens/radar_screen.dart';
import 'ui/screens/chats_screen.dart';
import 'ui/screens/contact_qr_screen.dart';
import 'ui/screens/gateway_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NearLinkEngine.instance.init();
  runApp(const NearLinkApp());
}

class NearLinkApp extends StatelessWidget {
  const NearLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearLink',
      debugShowCheckedModeBanner: false,
      theme: NearLinkTheme.darkTheme,
      home: const MainNavigationScreen(),
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
    RadarScreen(),
    ChatsScreen(),
    ContactQrScreen(),
    GatewayScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_2),
            label: 'My Card',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_sync_outlined),
            label: 'Gateway',
          ),
        ],
      ),
    );
  }
}
