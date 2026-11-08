import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vynl/statics.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';
import 'music_cache_service.dart';

class YoutubeService {
  static const _searchEndpoint = 'https://music.youtube.com/youtubei/v1/search';
  // Thank you for the owner of this API key
  static const _apiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const _clientVersion = '1.20240726.00.00';
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';
  static const _userAgent = userAgent;

  static const _renderApiEndpoint = '$baseApi/yt';

  // YouTube Music Songs filter parameter
  // Thank you for the owner of this API key
  static const _songsFilterParam = 'EgWKAQIIAWoSEAQQAxAFEAkQChAVEBAQDhAR';

  final YoutubeExplode _youtube = YoutubeExplode();
  final http.Client _client = http.Client();

  /// Strictly searches YouTube Music for songs, filtering out non-music and karaoke.
  Future<List<Song>> search(String query, {int limit = 30}) async {
    List<Song> songs = await _performMusicSearch(
      query,
      useFilter: true,
      limit: limit,
    );
    if (songs.isEmpty) {
      // Fallback search without songs filter parameter if no results returned
      songs = await _performMusicSearch(query, useFilter: false, limit: limit);
    }
    return songs;
  }

  Future<List<Song>> _performMusicSearch(
    String query, {
    required bool useFilter,
    required int limit,
  }) async {
    final bodyMap = <String, dynamic>{
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': _clientVersion,
          'hl': 'en',
          'gl': 'US',
        },
      },
      'query': query,
    };
    if (useFilter) {
      bodyMap['params'] = _songsFilterParam;
    }

    final response = await _client.post(
      Uri.parse('$_searchEndpoint?key=$_apiKey&prettyPrint=false'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': _userAgent,
        'Referer': 'https://music.youtube.com/',
      },
      body: jsonEncode(bodyMap),
    );

    if (response.statusCode != 200) {
      throw Exception('YouTube Music search failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final renderers = <Map<String, dynamic>>[];
    _collectMusicRenderers(data, renderers);

    final songs = <Song>[];
    final seen = <String>{};
    final qLower = query.toLowerCase();

    for (final r in renderers) {
      final videoId = _extractVideoId(r);
      if (videoId == null || !seen.add(videoId)) continue;

      final title = _extractTitle(r);
      if (title == null || title.isEmpty) continue;

      final artist = _extractArtist(r);

      // Strictly filter out karaoke and non-music unless explicitly requested
      if (_isKaraokeOrNonMusic(title, artist, qLower)) {
        continue;
      }

      final duration = _parseDuration(_extractDuration(r));
      final artworkUri = _extractArtworkUri(r, videoId);

      songs.add(
        Song.fromYoutube(
          videoId: videoId,
          title: title,
          artist: artist,
          duration: duration,
          artworkUri: artworkUri,
        ),
      );

      if (songs.length >= limit) break;
    }

    return songs;
  }

  bool _isKaraokeOrNonMusic(String title, String artist, String qLower) {
    final tLower = title.toLowerCase();
    final aLower = artist.toLowerCase();

    // Check karaoke
    if (!qLower.contains('karaoke')) {
      if (tLower.contains('karaoke') || aLower.contains('karaoke')) {
        return true;
      }
    }

    // Check instrumental / backing track
    if (!qLower.contains('instrumental') && !qLower.contains('backing track')) {
      if (tLower.contains('backing track') ||
          tLower.contains('instrumental') ||
          aLower.contains('backing track')) {
        return true;
      }
    }

    // Check parody / review / reaction videos
    if (!qLower.contains('parody') && tLower.contains('parody')) {
      return true;
    }

    return false;
  }

  void _collectMusicRenderers(Object? node, List<Map<String, dynamic>> output) {
    if (node is Map) {
      final renderer = node['musicResponsiveListItemRenderer'];
      if (renderer is Map<String, dynamic>) {
        output.add(renderer);
      }
      for (final value in node.values) {
        _collectMusicRenderers(value, output);
      }
    } else if (node is List) {
      for (final value in node) {
        _collectMusicRenderers(value, output);
      }
    }
  }

  String? _extractVideoId(Map<String, dynamic> r) {
    // 1. Check playlistItemData
    final data = r['playlistItemData'];
    if (data is Map && data['videoId'] is String) {
      return data['videoId'] as String;
    }

    // 2. Check overlay musicPlayButtonRenderer
    try {
      final overlayVid =
          r['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
      if (overlayVid is String && overlayVid.isNotEmpty) {
        return overlayVid;
      }
    } catch (_) {}

    // 3. Check flexColumns[0] navigationEndpoint
    try {
      final flexCols = r['flexColumns'];
      if (flexCols is List && flexCols.isNotEmpty) {
        final col0 = flexCols[0]['musicResponsiveListItemFlexColumnRenderer'];
        final runs = col0?['text']?['runs'];
        if (runs is List && runs.isNotEmpty) {
          final vid =
              runs[0]?['navigationEndpoint']?['watchEndpoint']?['videoId'];
          if (vid is String && vid.isNotEmpty) {
            return vid;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  String? _extractTitle(Map<String, dynamic> r) {
    try {
      final flexCols = r['flexColumns'];
      if (flexCols is List && flexCols.isNotEmpty) {
        final col0 = flexCols[0]['musicResponsiveListItemFlexColumnRenderer'];
        final runs = col0?['text']?['runs'];
        if (runs is List) {
          final buffer = StringBuffer();
          for (final run in runs) {
            if (run is Map && run['text'] is String) {
              buffer.write(run['text']);
            }
          }
          final res = buffer.toString().trim();
          if (res.isNotEmpty) return res;
        }
      }
    } catch (_) {}
    return null;
  }

  String _extractArtist(Map<String, dynamic> r) {
    try {
      final flexCols = r['flexColumns'];
      if (flexCols is List && flexCols.length > 1) {
        final col1 = flexCols[1]['musicResponsiveListItemFlexColumnRenderer'];
        final runs = col1?['text']?['runs'];
        if (runs is List) {
          final buffer = StringBuffer();
          for (final run in runs) {
            if (run is Map && run['text'] is String) {
              final text = run['text'] as String;
              if (text.trim() == '•') break;
              buffer.write(text);
            }
          }
          final res = buffer.toString().trim();
          if (res.isNotEmpty) return res;
        }
      }
    } catch (_) {}
    return 'YouTube Music';
  }

  String? _extractDuration(Map<String, dynamic> r) {
    try {
      final flexCols = r['flexColumns'];
      if (flexCols is List && flexCols.length > 1) {
        final col1 = flexCols[1]['musicResponsiveListItemFlexColumnRenderer'];
        final runs = col1?['text']?['runs'];
        if (runs is List) {
          for (final run in runs.reversed) {
            if (run is Map && run['text'] is String) {
              final text = (run['text'] as String).trim();
              if (RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(text)) {
                return text;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Uri _extractArtworkUri(Map<String, dynamic> r, String videoId) {
    try {
      final thumbs =
          r['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map &&
            last['url'] is String &&
            (last['url'] as String).isNotEmpty) {
          return Uri.parse(last['url'] as String);
        }
      }
    } catch (_) {}
    return Uri.parse('https://img.youtube.com/vi/$videoId/mqdefault.jpg');
  }

  Future<Uri?> _resolveFromRenderApi(Song song) async {
    try {
      final ytUrl = Uri.encodeComponent(
        'https://youtube.com/watch?v=${song.videoId}',
      );
      final endpoint = '$_renderApiEndpoint?videoID=$ytUrl';
      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final urlStr =
              _extractUrl(data['url']) ??
              _extractUrl(data['media']?['mp3']) ??
              _extractUrl(data['media']?['mp4']);
          if (urlStr != null && urlStr.isNotEmpty) {
            return Uri.tryParse(urlStr);
          }
        }
      }
    } catch (e) {
      debugPrint('YouTubeService: _resolveFromRenderApi error: $e');
    }
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

    // 2. Check if song is cached in MusicCacheService
    final cachedFile = await MusicCacheService().getCachedFile(song.videoId);
    if (cachedFile != null) {
      return song.withStreamUri(Uri.file(cachedFile.path));
    }

    // 3. Resolve via yt-dlp-stream Render API
    final apiUri = await _resolveFromRenderApi(song);
    if (apiUri != null) {
      return song.withStreamUri(apiUri);
    }

    // 4. Fallback to youtube_explode stream
    final manifest = await _youtube.videos.streams.getManifest(song.videoId);
    if (manifest.audioOnly.isEmpty) {
      throw Exception('No audio stream is available for this video.');
    }
    final audio = manifest.audioOnly.withHighestBitrate();
    return song.withStreamUri(audio.url);
  }

  /// Resolves the stream URI directly (either file or online stream URL).
  Future<Uri> resolveStreamUri(Song song) async {
    final resolved = await resolveStream(song);
    return resolved.uri;
  }

  Future<File> downloadSong(
    Song song, {
    void Function(double progress)? onProgress,
  }) async {
    final existing = await getDownloadedFile(song);
    if (existing != null) return existing;

    final saveDir = await getDownloadDirectory();
    final sanitizedTitle = _sanitizeFileName(song.title);
    final sanitizedArtist = _sanitizeFileName(song.artist);
    final filename =
        '${sanitizedArtist.isEmpty ? "Unknown" : sanitizedArtist} - $sanitizedTitle.mp3';
    final targetFile = File('${saveDir.path}/$filename');

    // Optimization: If already cached in MusicCacheService, copy instantly from cache!
    final cached = await MusicCacheService().getCachedFile(song.videoId);
    if (cached != null && await cached.exists()) {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await cached.copy(targetFile.path);
      onProgress?.call(1.0);
      try {
        await OnAudioQuery().scanMedia(targetFile.path);
      } catch (_) {}
      return targetFile;
    }

    // Resolve download URL directly from _resolveFromRenderApi
    final downloadUri = await _resolveFromRenderApi(song);
    if (downloadUri == null) {
      throw Exception(
        'Failed to resolve download URL for "${song.title}". Please try again.',
      );
    }

    final tempFile = File('${saveDir.path}/.$filename.tmp');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final request = http.Request('GET', downloadUri);
    request.headers['User-Agent'] = _userAgent;
    request.headers['Range'] = 'bytes=0-';
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
    // This is just to set a separated folder for download
    final folder = "Vynl";
    if (!kIsWeb && Platform.isAndroid) {
      for (final p in [
        '/storage/emulated/0/Music/$folder',
        '/storage/emulated/0/Download/$folder',
      ]) {
        final d = Directory(p);
        if (await d.exists()) return d;
      }
      try {
        final dirs = await getExternalStorageDirectories(
          type: StorageDirectory.music,
        );
        if (dirs != null && dirs.isNotEmpty) {
          return Directory('${dirs.first.toString()}/$folder');
        }
      } catch (_) {}
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return Directory('${extDir.toString()}/$folder');
      } catch (_) {}
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.toString()}/$folder');
      }
    } catch (_) {}

    final dir = await getApplicationDocumentsDirectory();

    return Directory('${dir.toString()}/$folder');
  }

  void dispose() {
    _client.close();
    _youtube.close();
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
