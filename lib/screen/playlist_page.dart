import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../services/player_controller.dart';
import '../services/playlist_controller.dart';
import '../widgets/message_state.dart';
import '../widgets/playlist_name_dialog.dart';
import '../widgets/song_tile.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    required this.controller,
    required this.playlists,
    required this.playlistId,
    required this.onOpenPlayer,
  });

  final PlayerController controller;
  final PlaylistController playlists;
  final String playlistId;
  final VoidCallback onOpenPlayer;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  Future<void> _playAll(Playlist playlist) async {
    if (playlist.songs.isEmpty) return;
    await widget.controller.playAt(playlist.songs, 0);
    widget.onOpenPlayer();
  }

  Future<void> _rename(Playlist playlist) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: playlist.name,
    );
    if (name == null) return;
    await widget.playlists.rename(playlist.id, name);
  }

  Future<void> _delete(Playlist playlist) async {
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
    await widget.playlists.delete(playlist.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playlists,
      builder: (context, _) {
        final playlist = widget.playlists.byId(widget.playlistId);
        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Playlist not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: [
              IconButton(
                tooltip: 'Play all',
                onPressed: playlist.songs.isEmpty
                    ? null
                    : () => _playAll(playlist),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') _rename(playlist);
                  if (value == 'delete') _delete(playlist);
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
            ],
          ),
          body: _buildBody(playlist),
        );
      },
    );
  }

  Widget _buildBody(Playlist playlist) {
    if (playlist.songs.isEmpty) {
      return const MessageState(
        icon: Icons.queue_music_rounded,
        title: 'This playlist is empty',
        message: 'Add songs from the Songs tab using the menu on each track.',
      );
    }

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentSong = widget.controller.currentSong;
        final playing = widget.controller.isPlaying.value;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: playlist.songs.length,
          itemBuilder: (context, index) {
            final song = playlist.songs[index];
            final isCurrent = currentSong?.id == song.id;

            return SongTile(
              song: song,
              isCurrent: isCurrent,
              isPlaying: isCurrent && playing,
              onTap: () async {
                await widget.controller.playAt(playlist.songs, index);
                widget.onOpenPlayer();
              },
              onRemoveFromPlaylist: () {
                widget.playlists.removeSong(playlist.id, song.id);
              },
            );
          },
        );
      },
    );
  }
}
