import 'package:flutter/material.dart';

import '../models/song.dart';
import '../utils/format.dart';
import 'song_artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.trailing,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onDownload,
    this.isDownloading = false,
    this.downloadProgress,
    this.isDownloaded = false,
  });

  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final double? downloadProgress;
  final bool isDownloaded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = isCurrent ? scheme.primary : scheme.onSurface;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SongArtwork(song: song, size: 52),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: _buildTrailing(context, scheme),
    );
  }

  Widget _buildTrailing(BuildContext context, ColorScheme scheme) {
    if (trailing != null) return trailing!;

    final status = isCurrent && isPlaying
        ? Icon(Icons.graphic_eq_rounded, color: scheme.primary)
        : Text(
            formatDuration(song.duration),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
            ),
          );

    final showDownload = onDownload != null || isDownloading || isDownloaded;
    final hasMenu = onAddToPlaylist != null || onRemoveFromPlaylist != null;

    if (!showDownload && !hasMenu) return status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status,
        if (showDownload) ...[
          const SizedBox(width: 4),
          if (isDownloading)
            SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: (downloadProgress != null && downloadProgress! > 0)
                      ? downloadProgress
                      : null,
                ),
              ),
            )
          else if (isDownloaded)
            IconButton(
              tooltip: 'Downloaded',
              icon: Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                size: 20,
              ),
              onPressed: onDownload,
            )
          else
            IconButton(
              tooltip: 'Download MP3',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: onDownload,
            ),
        ],
        if (hasMenu)
          PopupMenuButton<String>(
            tooltip: 'Song options',
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'add') onAddToPlaylist?.call();
              if (value == 'remove') onRemoveFromPlaylist?.call();
              if (value == 'download') onDownload?.call();
            },
            itemBuilder: (context) => [
              if (onAddToPlaylist != null)
                const PopupMenuItem(
                  value: 'add',
                  child: Text('Add to playlist'),
                ),
              if (onRemoveFromPlaylist != null)
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from playlist'),
                ),
            ],
          ),
      ],
    );
  }
}
