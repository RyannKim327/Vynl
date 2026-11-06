import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_library_service.dart';
import '../services/player_controller.dart';
import '../widgets/message_state.dart';
import '../widgets/song_tile.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({
    super.key,
    required this.controller,
    required this.onOpenPlayer,
  });

  final PlayerController controller;
  final VoidCallback onOpenPlayer;

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  final MusicLibraryService _library = MusicLibraryService();
  final TextEditingController _searchController = TextEditingController();

  List<Song> _songs = const [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final granted = await _library.requestPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Music permission is required to read the songs stored on this device.';
        });
        return;
      }

      final songs = await _library.loadSongs();
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to read the music library on this device.';
      });
    }
  }

  List<Song> get _filteredSongs {
    if (_search.trim().isEmpty) return _songs;
    final query = _search.trim().toLowerCase();
    return _songs.where((song) => song.searchText.contains(query)).toList();
  }

  Future<void> _playSong(List<Song> songs, int index) async {
    await widget.controller.playAt(songs, index);
    widget.onOpenPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh library',
            onPressed: _loading ? null : _loadLibrary,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return MessageState(
        icon: Icons.folder_off_rounded,
        title: 'No access to your music',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _loadLibrary,
      );
    }

    final songs = _filteredSongs;
    if (_songs.isEmpty) {
      return MessageState(
        icon: Icons.library_music_rounded,
        title: 'No songs found',
        message: 'Copy some music onto this device and tap refresh to load it.',
        actionLabel: 'Refresh',
        onAction: _loadLibrary,
      );
    }

    if (songs.isEmpty) {
      return const MessageState(
        icon: Icons.search_off_rounded,
        title: 'Nothing matches',
        message: 'Try a different song, artist, or album name.',
      );
    }

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentSong = widget.controller.currentSong;
        final playing = widget.controller.isPlaying.value;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isCurrent = currentSong?.id == song.id;
            return SongTile(
              song: song,
              isCurrent: isCurrent,
              isPlaying: isCurrent && playing,
              onTap: () => _playSong(songs, index),
            );
          },
        );
      },
    );
  }
}
