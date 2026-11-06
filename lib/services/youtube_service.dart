import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

class YoutubeService {
  static const _searchEndpoint = 'https://www.youtube.com/youtubei/v1/search';
  static const _apiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const _clientVersion = '2.20240726.00.00';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  static const _streamApiEndpoint =
      'https://yt-dlp-stream.onrender.com/api/v1/q?=';

  final YoutubeExplode _youtube = YoutubeExplode();
  final http.Client _client = http.Client();

  Future<List<Song>> search(String query, {int limit = 30}) async {
    final response = await _client.post(
      Uri.parse('$_searchEndpoint?key=$_apiKey&prettyPrint=false'),
      headers: {'Content-Type': 'application/json', 'User-Agent': _userAgent},
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': _clientVersion,
            'hl': 'en',
            'gl': 'US',
          },
        },
        'query': query,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('YouTube search failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final renderers = <Map<String, dynamic>>[];
    _collectVideoRenderers(data, renderers);

    final songs = <Song>[];
    final seen = <String>{};

    for (final video in renderers) {
      final videoId = video['videoId'];
      if (videoId is! String || !seen.add(videoId)) continue;

      final title = _text(video['title']);
      if (title == null) continue;

      songs.add(
        Song.fromYoutube(
          videoId: videoId,
          title: title,
          artist: _text(video['ownerText']) ?? 'YouTube Music',
          duration: _parseDuration(_text(video['lengthText'])),
          artworkUri: Uri.parse(
            'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
          ),
        ),
      );

      if (songs.length >= limit) break;
    }

    return songs;
  }

  Future<Uri?> _resolveFromRenderApi(Song song) async {
    try {
      final ytUrl = 'https://www.youtube.com/watch?v=${song.videoId}';
      final endpoint = '$_streamApiEndpoint${Uri.encodeComponent(ytUrl)}';
      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final media = data['media'];
          if (media is Map) {
            final mp3Url = _extractUrl(media['mp3']);
            if (mp3Url != null) return Uri.tryParse(mp3Url);

            final mp4Url = _extractUrl(media['mp4']);
            if (mp4Url != null) return Uri.tryParse(mp4Url);

            final qualities = media['qualities'];
            if (qualities is List) {
              for (final q in qualities) {
                if (q is Map &&
                    q['url'] is String &&
                    (q['url'] as String).isNotEmpty) {
                  return Uri.tryParse(q['url'] as String);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _extractUrl(dynamic obj) {
    if (obj is String && obj.isNotEmpty) return obj;
    if (obj is Map) {
      final url = obj['url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  Future<File?> getDownloadedFile(Song song) async {
    try {
      final saveDir = await getDownloadDirectory();
      final sanitizedTitle = _sanitizeFileName(song.title);
      final sanitizedArtist = _sanitizeFileName(song.artist);
      final filename =
          '${sanitizedArtist.isEmpty ? "Unknown" : sanitizedArtist} - $sanitizedTitle.mp3';
      final file = File('${saveDir.path}/$filename');
      if (await file.exists()) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> isSongDownloaded(Song song) async {
    final file = await getDownloadedFile(song);
    return file != null;
  }

  Future<Song> resolveStream(Song song) async {
    // 1. If song was already downloaded locally, stream the local MP3 file directly
    final localFile = await getDownloadedFile(song);
    if (localFile != null) {
      return song.withStreamUri(Uri.file(localFile.path));
    }

    // 2. Resolve via yt-dlp-stream Render API
    final apiUri = await _resolveFromRenderApi(song);
    if (apiUri != null) {
      return song.withStreamUri(apiUri);
    }

    // 3. Fallback to youtube_explode stream
    final manifest = await _youtube.videos.streams.getManifest(song.videoId);
    if (manifest.audioOnly.isEmpty) {
      throw Exception('No audio stream is available for this video.');
    }
    final audio = manifest.audioOnly.withHighestBitrate();
    return song.withStreamUri(audio.url);
  }

  Future<File> downloadSong(
    Song song, {
    void Function(double progress)? onProgress,
  }) async {
    final existing = await getDownloadedFile(song);
    if (existing != null) return existing;

    // 1. Resolve download URL using Render API, fallback to YouTube Explode
    Uri? downloadUri = await _resolveFromRenderApi(song);
    if (downloadUri == null) {
      final manifest = await _youtube.videos.streams.getManifest(song.videoId);
      if (manifest.audioOnly.isEmpty) {
        throw Exception('No audio stream available to download.');
      }
      final audio = manifest.audioOnly.withHighestBitrate();
      downloadUri = audio.url;
    }

    final saveDir = await getDownloadDirectory();
    final sanitizedTitle = _sanitizeFileName(song.title);
    final sanitizedArtist = _sanitizeFileName(song.artist);
    final filename =
        '${sanitizedArtist.isEmpty ? "Unknown" : sanitizedArtist} - $sanitizedTitle.mp3';
    final targetFile = File('${saveDir.path}/$filename');
    final tempFile = File('${saveDir.path}/.$filename.tmp');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final request = http.Request('GET', downloadUri);
    request.headers['User-Agent'] = _userAgent;
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200 &&
        streamedResponse.statusCode != 206) {
      throw Exception(
        'Download failed with status ${streamedResponse.statusCode}.',
      );
    }

    final totalBytes = streamedResponse.contentLength ?? 0;
    var receivedBytes = 0;
    final sink = tempFile.openWrite();

    try {
      await streamedResponse.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
        }
      }).asFuture();
      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    try {
      await OnAudioQuery().scanMedia(targetFile.path);
    } catch (_) {}

    return targetFile;
  }

  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<Directory> getDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      for (final p in [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
      ]) {
        final d = Directory(p);
        if (await d.exists()) return d;
      }
      try {
        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.music,
        );
        if (dirs != null && dirs.isNotEmpty) return dirs.first;
      } catch (_) {}
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      } catch (_) {}
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {}

    return await getApplicationDocumentsDirectory();
  }

  void dispose() {
    _client.close();
    _youtube.close();
  }

  void _collectVideoRenderers(Object? node, List<Map<String, dynamic>> output) {
    if (node is Map) {
      final renderer = node['videoRenderer'];
      if (renderer is Map<String, dynamic>) {
        output.add(renderer);
      }
      for (final value in node.values) {
        _collectVideoRenderers(value, output);
      }
    } else if (node is List) {
      for (final value in node) {
        _collectVideoRenderers(value, output);
      }
    }
  }

  String? _text(Object? node) {
    if (node is String) return node;
    if (node is! Map) return null;

    final simpleText = node['simpleText'];
    if (simpleText is String && simpleText.trim().isNotEmpty) {
      return simpleText.trim();
    }

    final runs = node['runs'];
    if (runs is List) {
      final buffer = StringBuffer();
      for (final run in runs) {
        if (run is Map && run['text'] is String) {
          buffer.write(run['text']);
        }
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }

  Duration _parseDuration(String? value) {
    if (value == null) return Duration.zero;
    final parts = value.split(':');
    var seconds = 0;
    for (final part in parts) {
      final number = int.tryParse(part.trim());
      if (number == null) return Duration.zero;
      seconds = seconds * 60 + number;
    }
    return Duration(seconds: seconds);
  }
}
