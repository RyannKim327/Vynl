import 'package:flutter/material.dart';

import '../models/song.dart';
import '../utils/format.dart';
import 'song_artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.isCurrent = false,
    this.isPlaying = false,
    this.showPlayState = true,
    required this.onTap,
    this.trailing,
    this.onAddToPlaylist,
    this.onRemoveFromPlaylist,
    this.onDownload,
    this.isDownloading = false,
    this.downloadProgress,
    this.isDownloaded = false,
    this.isCached = false,
  });

  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final bool showPlayState;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onRemoveFromPlaylist;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final double? downloadProgress;
  final bool isDownloaded;
  final bool isCached;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = (showPlayState && isCurrent)
        ? scheme.primary
        : scheme.onSurface;

    Widget subtitleWidget;
    if (isDownloading) {
      final p = (downloadProgress ?? 0.0).clamp(0.0, 1.0);
      final pct = p > 0 ? '${(p * 100).toInt()}%' : 'Connecting...';
      subtitleWidget = Text(
        'Downloading ($pct) • ${song.artist}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      );
    } else if (isDownloaded) {
      subtitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Downloaded • ${song.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else if (isCached) {
      subtitleWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: scheme.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'Cached • ${song.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else {
      subtitleWidget = Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SongArtwork(song: song, size: 52),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitleWidget,
      trailing: _buildTrailing(context, scheme),
    );

    if (isDownloading) {
      final progress = (downloadProgress ?? 0.0).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value <= 0.0 ? 0.03 : value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              tile,
            ],
          ),
        ),
      );
    }

    return tile;
  }

  Widget _buildTrailing(BuildContext context, ColorScheme scheme) {
    if (trailing != null) return trailing!;

    if (isDownloading) {
      final p = (downloadProgress ?? 0.0).clamp(0.0, 1.0);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: p > 0 ? p : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              p > 0 ? '${(p * 100).toInt()}%' : '...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.duration > Duration.zero)
            Text(
              formatDuration(song.duration),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          const SizedBox(width: 8),
          Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22),
        ],
      );
    }

    if (onDownload != null) {
      final statusWidget = (showPlayState && isCurrent && isPlaying)
          ? Icon(Icons.graphic_eq_rounded, color: scheme.primary)
          : (song.duration > Duration.zero
                ? Text(
                    formatDuration(song.duration),
                    style: TextStyle(
                      color: (showPlayState && isCurrent)
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  )
                : null);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCached && !isDownloaded)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: 'Cached for offline play',
                child: Icon(
                  Icons.bolt_rounded,
                  color: scheme.primary.withValues(alpha: 0.8),
                  size: 18,
                ),
              ),
            ),
          ?statusWidget,
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Download song',
            icon: const Icon(Icons.download_rounded, size: 22),
            color: scheme.primary,
            onPressed: onDownload ?? onTap,
          ),
        ],
      );
    }

    final status = (showPlayState && isCurrent && isPlaying)
        ? Icon(Icons.graphic_eq_rounded, color: scheme.primary)
        : Text(
            formatDuration(song.duration),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          );

    final hasMenu = onAddToPlaylist != null || onRemoveFromPlaylist != null;
    if (!hasMenu) return status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        status,
        PopupMenuButton<String>(
          tooltip: 'Song options',
          padding: EdgeInsets.zero,
          onSelected: (value) {
            if (value == 'add') onAddToPlaylist?.call();
            if (value == 'remove') onRemoveFromPlaylist?.call();
          },
          itemBuilder: (context) => [
            if (onAddToPlaylist != null)
              const PopupMenuItem(value: 'add', child: Text('Add to playlist')),
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
