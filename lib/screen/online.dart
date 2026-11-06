import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/music_cache_service.dart';
import '../services/player_controller.dart';
import '../services/youtube_service.dart';
import '../widgets/message_state.dart';
import '../widgets/song_tile.dart';

class OnlinePage extends StatefulWidget {
  const OnlinePage({
    super.key,
    this.controller,
    this.onOpenPlayer,
    this.onDownloaded,
  });

  final PlayerController? controller;
  final VoidCallback? onOpenPlayer;
  final VoidCallback? onDownloaded;

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final YoutubeService _youtube = YoutubeService();
  final MusicCacheService _cacheService = MusicCacheService();
  final TextEditingController _searchController = TextEditingController();

  List<Song> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  final Set<String> _downloadingIds = {};
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadedIds = {};

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerUpdate);
    _cacheService.cachedSongIds.addListener(_onCacheUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onCacheUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant OnlinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _cacheService.cachedSongIds.removeListener(_onCacheUpdate);
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
      _checkDownloadedAndCached(results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach YouTube Music. Check your internet connection and try again.';
      });
    }
  }

  Future<void> _checkDownloadedAndCached(List<Song> songs) async {
    for (final song in songs) {
      final isDownloaded = await _youtube.isSongDownloaded(song);
      if (isDownloaded && mounted) {
        setState(() {
          _downloadedIds.add(song.id);
        });
      }
      // Also prime cache status
      await _cacheService.getCachedFile(song.videoId);
    }
  }

  void _handleTap(Song song, int index) async {
    final controller = widget.controller;
    if (controller == null) return;

    final isCurrent = controller.currentSong?.id == song.id;
    if (isCurrent) {
      widget.onOpenPlayer?.call();
      return;
    }

    // Play online with multi-music caching and 10-song auto-pause
    await controller.playAt(_results, index);
    widget.onOpenPlayer?.call();
  }

  Future<void> _playAll({bool shuffle = false}) async {
    final controller = widget.controller;
    if (controller == null || _results.isEmpty) return;

    if (shuffle && !controller.shuffle) {
      await controller.toggleShuffle();
    } else if (!shuffle && controller.shuffle) {
      await controller.toggleShuffle();
    }

    await controller.playAt(_results, 0);
    widget.onOpenPlayer?.call();
  }

  Future<void> _download(Song song) async {
    if (_downloadingIds.contains(song.id)) return;

    setState(() {
      _downloadingIds.add(song.id);
      _downloadProgress[song.id] = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${song.title}" as MP3...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await _youtube.downloadSong(
        song,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress[song.id] = p;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _downloadingIds.remove(song.id);
        _downloadProgress.remove(song.id);
        _downloadedIds.add(song.id);
      });

      widget.onDownloaded?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded "${song.title}" to device. Available in Offline library.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingIds.remove(song.id);
        _downloadProgress.remove(song.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download "${song.title}": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Music'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.play_circle_fill_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Online Play'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search YouTube Music',
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
        title: 'YouTube Music is unreachable',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _search,
      );
    }

    if (!_searched) {
      return const MessageState(
        icon: Icons.music_note_rounded,
        title: 'Search YouTube Music',
        message: 'Search any music online. Multi-music queue will stream, cache to disk, and pause every 10 songs.',
      );
    }

    if (_results.isEmpty) {
      return const MessageState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Try a different search term.',
      );
    }

    final isPausedByLimit = widget.controller?.isPausedByTenSongLimit ?? false;
    final cachedSet = _cacheService.cachedSongIds.value;

    return Column(
      children: [
        // 10-Song Auto-Pause Alert Banner
        if (isPausedByLimit) _buildPausedByLimitBanner(),

        // Multi-Music Queue Controls Header
        _buildQueueHeader(),

        // Search Results List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final song = _results[index];
              final isDownloading = _downloadingIds.contains(song.id);
              final isDownloaded = _downloadedIds.contains(song.id);
              final isCached = cachedSet.contains(song.videoId);
              final progress = _downloadProgress[song.id];

              final isCurrent = widget.controller?.currentSong?.id == song.id;
              final isPlaying =
                  isCurrent && (widget.controller?.isPlaying.value ?? false);

              return SongTile(
                song: song,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                showPlayState: true,
                isCached: isCached,
                onTap: () => _handleTap(song, index),
                onDownload: () => _download(song),
                isDownloading: isDownloading,
                downloadProgress: progress,
                isDownloaded: isDownloaded,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPausedByLimitBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_filled_rounded,
            color: scheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Paused after 10 songs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Continuous session paused. Tap Resume to play the next 10 songs.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => widget.controller?.resumeFromTenSongLimit(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_results.length} songs found',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 13,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pauses every 10 songs',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _playAll(shuffle: false),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Play All'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Shuffle All',
            onPressed: () => _playAll(shuffle: true),
            icon: const Icon(Icons.shuffle_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
