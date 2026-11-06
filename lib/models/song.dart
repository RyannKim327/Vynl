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
    required Uri? artworkUri,
    String album = 'YouTube Music',
  }) {
    return Song(
      id: 'yt:$videoId',
      title: title,
      artist: artist,
      album: album,
      uri: Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      duration: duration,
      artworkUri: artworkUri,
    );
  }

  String get videoId => id.startsWith('yt:') ? id.substring(3) : id;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'title': title,
      'artist': artist,
      'album': album,
      'uri': uri.toString(),
      'duration': duration.inMilliseconds,
      'artworkUri': artworkUri?.toString(),
      'isLocal': isLocal,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final artist = json['artist'];
    final album = json['album'];
    final uri = json['uri'];
    if (id is! String ||
        title is! String ||
        artist is! String ||
        album is! String ||
        uri is! String) {
      throw const FormatException('Invalid song');
    }

    final mediaId = json['mediaId'];
    final duration = json['duration'];
    final artworkUri = json['artworkUri'];

    return Song(
      id: id,
      mediaId: mediaId is num ? mediaId.toInt() : null,
      title: title,
      artist: artist,
      album: album,
      uri: Uri.parse(uri),
      duration: Duration(milliseconds: duration is num ? duration.toInt() : 0),
      artworkUri: artworkUri is String ? Uri.tryParse(artworkUri) : null,
      isLocal: json['isLocal'] == true,
    );
  }

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
