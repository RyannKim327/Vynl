import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/music_cache_service.dart';
import '../services/player_controller.dart';
import '../services/youtube_service.dart';
import '../utils/format.dart';
import '../widgets/song_artwork.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.28),
              scheme.surface,
              scheme.surface,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final song = controller.currentSong;
              if (song == null) {
                return const Center(child: Text('Nothing is playing'));
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'NOW PLAYING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!song.isLocal)
                          IconButton(
                            tooltip: 'Download MP3',
                            icon: const Icon(Icons.download_rounded),
                            onPressed: () async {
                              final yt = YoutubeService();
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Downloading "${song.title}" as MP3...',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                await yt.downloadSong(song);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Downloaded "${song.title}" as MP3',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to download "${song.title}": $e',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                yt.dispose();
                              }
                            },
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                    const Spacer(),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxWidth.clamp(180.0, 340.0);
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: SongArtwork(
                            song: song,
                            size: size,
                            borderRadius: 28,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Text(
                      song.title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    if (!song.isLocal &&
                        MusicCacheService().cachedSongIds.value.contains(
                          song.videoId,
                        )) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Cached for fast offline playback',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (controller.isPausedByTenSongLimit) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pause_circle_filled_rounded,
                              color: scheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Paused after 10 songs • Tap Play to resume',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ProgressBar(
                      controller: controller,
                      fallback: song.duration,
                    ),
                    const SizedBox(height: 8),
                    _Controls(controller: controller),
                    const Spacer(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.controller, required this.fallback});

  final PlayerController controller;
  final Duration fallback;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.controller.position,
      builder: (context, position, _) {
        final duration = widget.controller.duration.value ?? widget.fallback;
        final max = duration.inMilliseconds.toDouble();
        final current =
            _dragValue ??
            position.inMilliseconds.clamp(0, max <= 0 ? 0 : max).toDouble();
        final shown = Duration(milliseconds: current.round());

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: current,
                max: max <= 0 ? 1 : max,
                activeColor: scheme.primary,
                inactiveColor: scheme.onSurface.withValues(alpha: 0.2),
                onChanged: max <= 0
                    ? null
                    : (value) => setState(() => _dragValue = value),
                onChangeEnd: (value) {
                  widget.controller.seek(Duration(milliseconds: value.round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(shown),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatDuration(duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = scheme.primary;
    final idleColor = scheme.onSurfaceVariant;

    final repeatIcon = switch (controller.loopMode) {
      LoopMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Shuffle',
              onPressed: controller.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                color: controller.shuffle ? activeColor : idleColor,
              ),
            ),
            IconButton(
              tooltip: 'Previous',
              iconSize: 40,
              onPressed: controller.previous,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: controller.isBuffering,
              builder: (context, buffering, _) {
                if (buffering) {
                  return const SizedBox(
                    width: 72,
                    height: 72,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: controller.isPlaying,
                  builder: (context, playing, _) {
                    return IconButton.filled(
                      onPressed: controller.togglePlay,
                      iconSize: 40,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(72, 72),
                      ),
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              tooltip: 'Next',
              iconSize: 40,
              onPressed: controller.next,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: 'Repeat',
              onPressed: controller.cycleLoopMode,
              icon: Icon(
                repeatIcon,
                color: controller.loopMode == LoopMode.off
                    ? idleColor
                    : activeColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
