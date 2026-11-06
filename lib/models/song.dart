import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

class Song {
  const Song({
    required this.id,
    this.mediaId,
    required this.title,
    required this.artist,
    required this.album,
    required this.uri,
    required this.duration,
    this.artworkUri,
    this.isLocal = false,
  });

  final String id;
  final int? mediaId;
  final String title;
  final String artist;
  final String album;
  final Uri uri;
  final Duration duration;
  final Uri? artworkUri;
  final bool isLocal;

  factory Song.fromLocalModel(SongModel model) {
    final uri = defaultTargetPlatform == TargetPlatform.android
        ? Uri.parse('content://media/external/audio/media/${model.id}')
        : Uri.file(model.data);

    return Song(
      id: 'local:${model.id}',
      mediaId: model.id,
      title: model.title.isEmpty ? model.displayNameWOExt : model.title,
      artist: (model.artist == null || model.artist == '<unknown>')
          ? 'Unknown artist'
          : model.artist!,
      album: (model.album == null || model.album == '<unknown>')
          ? 'Unknown album'
          : model.album!,
      uri: uri,
      duration: Duration(milliseconds: model.duration ?? 0),
      isLocal: true,
    );
  }

  factory Song.fromYoutube({
    required String videoId,
    required String title,
    required String artist,
    required Duration duration,
    required Uri artworkUri,
  }) {
    return Song(
      id: 'yt:$videoId',
      title: title,
      artist: artist,
      album: 'YouTube',
      uri: Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      duration: duration,
      artworkUri: artworkUri,
    );
  }

  String get videoId => id.startsWith('yt:') ? id.substring(3) : id;

  Song withStreamUri(Uri streamUri) {
    return Song(
      id: id,
      mediaId: mediaId,
      title: title,
      artist: artist,
      album: album,
      uri: streamUri,
      duration: duration,
      artworkUri: artworkUri,
      isLocal: isLocal,
    );
  }

  String get searchText => '$title $artist $album'.toLowerCase();
}
