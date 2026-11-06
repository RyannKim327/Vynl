import 'package:flutter/material.dart';

import '../services/player_controller.dart';
import '../widgets/mini_player.dart';
import 'offline.dart';
import 'online.dart';
import 'player.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PlayerController _controller = PlayerController();
  final GlobalKey<OfflinePageState> _offlineKey = GlobalKey<OfflinePageState>();
  int _tabIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(controller: _controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          OfflinePage(
            key: _offlineKey,
            controller: _controller,
            onOpenPlayer: _openPlayer,
          ),
          OnlinePage(
            controller: _controller,
            onOpenPlayer: _openPlayer,
            onDownloaded: () => _offlineKey.currentState?.loadLibrary(),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(controller: _controller, onTap: _openPlayer),
          NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) {
              if (index == 0 && _tabIndex != 0) {
                _offlineKey.currentState?.loadLibrary();
              }
              setState(() => _tabIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Offline',
              ),
              NavigationDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public_rounded),
                label: 'Online',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
