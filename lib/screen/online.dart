import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/player_controller.dart';
import '../services/youtube_service.dart';
import '../widgets/message_state.dart';
import '../widgets/song_tile.dart';

class OnlinePage extends StatefulWidget {
  const OnlinePage({
    super.key,
    required this.controller,
    required this.onOpenPlayer,
  });

  final PlayerController controller;
  final VoidCallback onOpenPlayer;

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final YoutubeService _youtube = YoutubeService();
  final TextEditingController _searchController = TextEditingController();

  List<Song> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  String? _resolvingId;

  @override
  void dispose() {
    _searchController.dispose();
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _loading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });

    try {
      final results = await _youtube.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach YouTube. Check your internet connection and try again.';
      });
    }
  }

  Future<void> _play(Song song) async {
    if (_resolvingId != null) return;
    setState(() => _resolvingId = song.id);

    try {
      final resolved = await _youtube.resolveStream(song);
      await widget.controller.playAt([resolved], 0);
      widget.onOpenPlayer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to play this YouTube track right now.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.public_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Online'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search YouTube',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
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
        icon: Icons.wifi_off_rounded,
        title: 'YouTube is unreachable',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _search,
      );
    }

    if (!_searched) {
      return const MessageState(
        icon: Icons.public_rounded,
        title: 'Search YouTube',
        message: 'Look up any song and stream it online. Offline files are always available in the Offline tab.',
      );
    }

    if (_results.isEmpty) {
      return const MessageState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Try a different search term.',
      );
    }

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentSong = widget.controller.currentSong;
        final playing = widget.controller.isPlaying.value;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final song = _results[index];
            final isCurrent = currentSong?.id == song.id;
            final resolving = _resolvingId == song.id;

            return SongTile(
              song: song,
              isCurrent: isCurrent,
              isPlaying: isCurrent && playing,
              onTap: () => _play(song),
              trailing: resolving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
