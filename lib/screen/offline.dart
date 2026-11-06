import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../services/music_library_service.dart';
import '../services/player_controller.dart';
import '../services/playlist_controller.dart';
import '../widgets/message_state.dart';
import '../widgets/playlist_name_dialog.dart';
import '../widgets/song_artwork.dart';
import '../widgets/song_tile.dart';
import 'playlist_page.dart';

enum _LibraryView { songs, playlists }

class OfflinePage extends StatefulWidget {
  const OfflinePage({
    super.key,
    required this.controller,
    required this.onOpenPlayer,
  });

  final PlayerController controller;
  final VoidCallback onOpenPlayer;

  @override
  State<OfflinePage> createState() => OfflinePageState();
}

class OfflinePageState extends State<OfflinePage> {
  final MusicLibraryService _library = MusicLibraryService();
  final PlaylistController _playlists = PlaylistController();
  final TextEditingController _searchController = TextEditingController();

  List<Song> _songs = const [];
  bool _loading = true;
  String? _error;
  String _search = '';
  _LibraryView _view = _LibraryView.songs;

  @override
  void initState() {
    super.initState();
    loadLibrary();
    _playlists.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _playlists.dispose();
    super.dispose();
  }

  Future<void> loadLibrary() async {
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

  Future<void> _createPlaylist() async {
    final name = await showPlaylistNameDialog(context);
    if (name == null) return;
    await _playlists.create(name);
    if (!mounted) return;
    setState(() => _view = _LibraryView.playlists);
  }

  Future<void> _renamePlaylist(Playlist playlist) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: playlist.name,
    );
    if (name == null) return;
    await _playlists.rename(playlist.id, name);
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text(
            '“${playlist.name}” will be removed. Your music files are not deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _playlists.delete(playlist.id);
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistPage(
          controller: widget.controller,
          playlists: _playlists,
          playlistId: playlist.id,
          onOpenPlayer: widget.onOpenPlayer,
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylist(Song song) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: _playlists,
          builder: (context, _) {
            final playlists = _playlists.playlists;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const ListTile(
                      title: Text(
                        'Add to playlist',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (playlists.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text('No playlists yet'),
                        subtitle: Text('Create one below to get started.'),
                      ),
                    for (final playlist in playlists)
                      ListTile(
                        leading: const Icon(Icons.queue_music_rounded),
                        title: Text(playlist.name),
                        subtitle: Text(
                          '${playlist.songs.length} song${playlist.songs.length == 1 ? '' : 's'}',
                        ),
                        onTap: () => Navigator.of(context).pop(playlist.id),
                      ),
                    ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('New playlist'),
                      onTap: () => Navigator.of(context).pop('__new__'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null || !mounted) return;

    if (selected == '__new__') {
      final name = await showPlaylistNameDialog(context);
      if (name == null || !mounted) return;
      final playlist = await _playlists.create(name);
      await _playlists.addSong(playlist.id, song);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added to ${playlist.name}')));
      return;
    }

    final added = await _playlists.addSong(selected, song);
    if (!mounted) return;
    final playlist = _playlists.byId(selected);
    final name = playlist?.name ?? 'playlist';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(added ? 'Added to $name' : 'Already in $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          if (_view == _LibraryView.songs)
            IconButton(
              tooltip: 'Refresh library',
              onPressed: _loading ? null : loadLibrary,
              icon: const Icon(Icons.refresh_rounded),
            )
          else
            IconButton(
              tooltip: 'New playlist',
              onPressed: _createPlaylist,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      floatingActionButton: _view == _LibraryView.playlists
          ? FloatingActionButton.extended(
              onPressed: _createPlaylist,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('New playlist'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<_LibraryView>(
              segments: const [
                ButtonSegment(
                  value: _LibraryView.songs,
                  icon: Icon(Icons.music_note_rounded),
                  label: Text('Songs'),
                ),
                ButtonSegment(
                  value: _LibraryView.playlists,
                  icon: Icon(Icons.queue_music_rounded),
                  label: Text('Playlists'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: _view == _LibraryView.songs
                ? _buildSongsView()
                : _buildPlaylistsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsView() {
    return Column(
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
        Expanded(child: _buildSongsBody()),
      ],
    );
  }

  Widget _buildSongsBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return MessageState(
        icon: Icons.folder_off_rounded,
        title: 'No access to your music',
        message: _error!,
        actionLabel: 'Try again',
        onAction: loadLibrary,
      );
    }

    final songs = _filteredSongs;
    if (_songs.isEmpty) {
      return MessageState(
        icon: Icons.library_music_rounded,
        title: 'No songs found',
        message: 'Copy some music onto this device and tap refresh to load it.',
        actionLabel: 'Refresh',
        onAction: loadLibrary,
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
              onAddToPlaylist: () => _showAddToPlaylist(song),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistsView() {
    return ListenableBuilder(
      listenable: _playlists,
      builder: (context, _) {
        if (!_playlists.loaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final playlists = _playlists.playlists;
        if (playlists.isEmpty) {
          return MessageState(
            icon: Icons.queue_music_rounded,
            title: 'No playlists yet',
            message: 'Create a playlist and add songs from your library.',
            actionLabel: 'New playlist',
            actionIcon: Icons.playlist_add_rounded,
            onAction: _createPlaylist,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final cover = playlist.songs.isNotEmpty
                ? playlist.songs.first
                : null;
            final scheme = Theme.of(context).colorScheme;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: cover != null
                  ? SongArtwork(song: cover, size: 52)
                  : Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
              title: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${playlist.songs.length} song${playlist.songs.length == 1 ? '' : 's'}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Playlist options',
                onSelected: (value) {
                  if (value == 'rename') _renamePlaylist(playlist);
                  if (value == 'delete') _deletePlaylist(playlist);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename playlist'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete playlist'),
                  ),
                ],
              ),
              onTap: () => _openPlaylist(playlist),
            );
          },
        );
      },
    );
  }
}
