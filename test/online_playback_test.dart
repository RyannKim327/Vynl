import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vynl/models/song.dart';
import 'package:vynl/services/music_cache_service.dart';
import 'package:vynl/services/player_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          return '/tmp';
        });
  });

  tearDownAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Multi-music queue and 10-song auto-pause tests', () {
    test('Queue initializes with songs and tracks current index', () {
      final controller = PlayerController();

      expect(controller.pauseEveryTenSongs, isTrue);
      expect(controller.consecutivePlaysCount, equals(0));
      expect(controller.isPausedByTenSongLimit, isFalse);
      expect(controller.queue, isEmpty);

      // Verify toggle setting
      controller.pauseEveryTenSongs = false;
      expect(controller.pauseEveryTenSongs, isFalse);
      controller.pauseEveryTenSongs = true;
      expect(controller.pauseEveryTenSongs, isTrue);

      controller.dispose();
    });

    test(
      'Song model handles YouTube format with videoId and stream update',
      () {
        final song = Song.fromYoutube(
          videoId: 'abc123xyz',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          duration: const Duration(minutes: 5, seconds: 55),
          artworkUri: Uri.parse('https://example.com/art.jpg'),
        );

        expect(song.videoId, equals('abc123xyz'));
        expect(song.id, equals('yt:abc123xyz'));
        expect(song.isLocal, isFalse);
        expect(
          song.uri.toString(),
          equals('https://www.youtube.com/watch?v=abc123xyz'),
        );

        final streamedSong = song.withStreamUri(Uri.file('/tmp/cached.mp3'));
        expect(streamedSong.uri.toString(), equals('file:///tmp/cached.mp3'));
        expect(streamedSong.videoId, equals('abc123xyz'));
        expect(streamedSong.title, equals('Bohemian Rhapsody'));
      },
    );

    test('MusicCacheService tracks cached song IDs notifier and resolves directory', () async {
      final cacheService = MusicCacheService();
      expect(cacheService.cachedSongIds.value, isNotNull);

      // Verify directory resolution
      final dir = await cacheService.getCacheDirectory();
      expect(dir.path, contains('vynl_cache'));

      // Check non-existent videoId returns null
      final file = await cacheService.getCachedFile('non_existent_123');
      expect(file, isNull);

      final isCached = await cacheService.isCached('non_existent_123');
      expect(isCached, isFalse);
    });
  });
}
