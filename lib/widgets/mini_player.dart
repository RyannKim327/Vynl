import 'package:flutter/material.dart';

import '../services/player_controller.dart';
import 'song_artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller, required this.onTap});

  final PlayerController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Material(
          color: scheme.surfaceContainerHigh,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: controller.position,
                  builder: (context, position, _) {
                    final duration = controller.duration.value ?? song.duration;
                    final max = duration.inMilliseconds.toDouble();
                    final value = position.inMilliseconds
                        .clamp(0, max <= 0 ? 0 : max)
                        .toDouble();
                    return LinearProgressIndicator(
                      value: max <= 0 ? 0 : value / max,
                      minHeight: 2,
                      backgroundColor: scheme.surfaceContainerHighest,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      SongArtwork(song: song, size: 44, borderRadius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: controller.isPlaying,
                        builder: (context, playing, _) {
                          return IconButton(
                            onPressed: controller.togglePlay,
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: controller.next,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
