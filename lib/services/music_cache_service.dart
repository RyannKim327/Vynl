import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import 'youtube_service.dart';

/// A service to cache streamed online songs on the local disk.
/// Enables offline playback, instant replaying with 0ms buffering,
/// and smooth multi-music queueing without repeated network hits.
class MusicCacheService {
  factory MusicCacheService() => _instance;
  MusicCacheService._internal();

  static final MusicCacheService _instance = MusicCacheService._internal();

  final http.Client _client = http.Client();
  final Map<String, Future<File?>> _inFlight = {};

  /// Observable set of videoIds that are confirmed cached in this session.
  final ValueNotifier<Set<String>> cachedSongIds = ValueNotifier(<String>{});

  Directory? _cachedDir;

  Future<Directory> getCacheDirectory() async {
    if (_cachedDir != null && await _cachedDir!.exists()) {
      return _cachedDir!;
    }
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/vynl_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cachedDir = cacheDir;
    return cacheDir;
  }

  /// Returns the cached file for [videoId] if it exists and has content.
  Future<File?> getCachedFile(String videoId) async {
    if (videoId.isEmpty) return null;
    try {
      final dir = await getCacheDirectory();
      final file = File('${dir.path}/$videoId.mp3');
      if (await file.exists()) {
        final length = await file.length();
        if (length > 1024) {
          _markCached(videoId);
          return file;
        } else {
          // Incomplete or empty file
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('MusicCacheService: getCachedFile error: $e');
    }
    return null;
  }

  /// Checks whether [videoId] is cached locally.
  Future<bool> isCached(String videoId) async {
    final file = await getCachedFile(videoId);
    return file != null;
  }

  /// Caches a single song to disk.
  /// If [streamUri] is omitted, it will be resolved via [YoutubeService].
  /// Deduplicates parallel caching attempts for the same [videoId].
  Future<File?> cacheSong(
    Song song, {
    Uri? streamUri,
    void Function(double progress)? onProgress,
  }) async {
    if (song.isLocal) return null;
    final videoId = song.videoId;
    if (videoId.isEmpty) return null;

    final existing = await getCachedFile(videoId);
    if (existing != null) {
      return existing;
    }

    // Deduplicate in-flight caching tasks
    if (_inFlight.containsKey(videoId)) {
      return await _inFlight[videoId]!;
    }

    final completer = Completer<File?>();
    _inFlight[videoId] = completer.future;

    try {
      final dir = await getCacheDirectory();
      final targetFile = File('${dir.path}/$videoId.mp3');
      final tempFile = File('${dir.path}/.$videoId.tmp');

      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      Uri? uri = streamUri;
      if (uri == null ||
          uri.toString().startsWith('https://www.youtube.com/watch')) {
        final yt = YoutubeService();
        try {
          final resolved = await yt.resolveStream(song);
          uri = resolved.uri;
        } finally {
          yt.dispose();
        }
      }

      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = YoutubeService.userAgent;
      request.headers['Range'] = 'bytes=0-';

      final streamedResponse = await _client.send(request);
      if (streamedResponse.statusCode != 200 &&
          streamedResponse.statusCode != 206) {
        throw Exception(
          'Caching failed with HTTP ${streamedResponse.statusCode}',
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
      } finally {
        await sink.flush();
        await sink.close();
      }

      final tempLength = await tempFile.length();
      if (tempLength < 1024) {
        throw Exception('Cached file too small ($tempLength bytes)');
      }

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      await tempFile.rename(targetFile.path);

      _markCached(videoId);
      unawaited(_pruneCacheIfNeeded());

      completer.complete(targetFile);
      return targetFile;
    } catch (e) {
      debugPrint('MusicCacheService: Failed to cache song "${song.title}": $e');
      completer.complete(null);
      return null;
    } finally {
      _inFlight.remove(videoId);
    }
  }

  /// Pre-caches upcoming songs in a queue.
  /// Used for multi-music playlists and search results so subsequent
  /// tracks start instantly with zero network buffering.
  Future<void> precacheQueue(
    List<Song> queue,
    int currentIndex, {
    int count = 2,
  }) async {
    if (queue.isEmpty) return;

    for (
      var i = currentIndex + 1;
      i < queue.length && i <= currentIndex + count;
      i++
    ) {
      final nextSong = queue[i];
      if (nextSong.isLocal) continue;
      final videoId = nextSong.videoId;
      if (videoId.isEmpty) continue;

      final alreadyCached = await isCached(videoId);
      if (alreadyCached) continue;

      // Start pre-caching this song in the background
      unawaited(cacheSong(nextSong));
    }
  }

  /// Removes oldest cache files if cache exceeds limits.
  Future<void> _pruneCacheIfNeeded({
    int maxFiles = 60,
    int maxBytes = 400 * 1024 * 1024, // 400MB
  }) async {
    try {
      final dir = await getCacheDirectory();
      final entities = dir.listSync().whereType<File>().toList();
      final mp3Files = entities
          .where((f) => f.path.endsWith('.mp3') && !f.path.contains('/.'))
          .toList();

      if (mp3Files.length <= maxFiles) {
        var total = 0;
        for (final f in mp3Files) {
          total += f.lengthSync();
        }
        if (total <= maxBytes) return;
      }

      // Sort oldest first
      mp3Files.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );

      final targetCount = (maxFiles * 0.75).round();
      final toRemove = mp3Files.length - targetCount;
      for (var i = 0; i < toRemove && i < mp3Files.length; i++) {
        try {
          await mp3Files[i].delete();
          final id = mp3Files[i].uri.pathSegments.last.replaceAll('.mp3', '');
          _unmarkCached(id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('MusicCacheService: prune error: $e');
    }
  }

  /// Clears all files in the cache.
  Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      cachedSongIds.value = {};
    } catch (e) {
      debugPrint('MusicCacheService: clearCache error: $e');
    }
  }

  /// Total size of all cached songs in bytes.
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getCacheDirectory();
      var total = 0;
      for (final entity in dir.listSync().whereType<File>()) {
        if (entity.path.endsWith('.mp3')) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Number of cached songs.
  Future<int> getCachedSongCount() async {
    try {
      final dir = await getCacheDirectory();
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'))
          .length;
    } catch (_) {
      return 0;
    }
  }

  void _markCached(String videoId) {
    if (!cachedSongIds.value.contains(videoId)) {
      cachedSongIds.value = {...cachedSongIds.value, videoId};
    }
  }

  void _unmarkCached(String videoId) {
    if (cachedSongIds.value.contains(videoId)) {
      final updated = Set<String>.from(cachedSongIds.value)..remove(videoId);
      cachedSongIds.value = updated;
    }
  }

  void dispose() {
    _client.close();
  }
}
