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
  });

  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final Widget? trailing;

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
      trailing:
          trailing ??
          (isCurrent && isPlaying
              ? Icon(Icons.graphic_eq_rounded, color: scheme.primary)
              : Text(
                  formatDuration(song.duration),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                )),
    );
  }
}
