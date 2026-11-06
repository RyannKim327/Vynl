import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';

class SongArtwork extends StatefulWidget {
  const SongArtwork({
    super.key,
    required this.song,
    this.size = 56,
    this.borderRadius = 12,
  });

  final Song song;
  final double size;
  final double borderRadius;

  @override
  State<SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends State<SongArtwork> {
  static final OnAudioQuery _query = OnAudioQuery();
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _loadLocalArtwork();
  }

  @override
  void didUpdateWidget(covariant SongArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.mediaId != widget.song.mediaId) {
      _loadLocalArtwork();
    }
  }

  void _loadLocalArtwork() {
    final mediaId = widget.song.mediaId;
    _future = mediaId == null
        ? null
        : _query.queryArtwork(
            mediaId,
            ArtworkType.AUDIO,
            format: ArtworkFormat.JPEG,
            size: (widget.size * 3).round(),
            quality: 80,
          );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final artworkUri = widget.song.artworkUri;
    if (artworkUri != null) {
      return Image.network(
        artworkUri.toString(),
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback(context);
        },
      );
    }

    final future = _future;
    if (future == null) return _fallback(context);

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null && data.isNotEmpty) {
          return Image.memory(
            data,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            gaplessPlayback: true,
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: widget.size * 0.5,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
