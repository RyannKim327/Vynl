import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';
import 'music_cache_service.dart';
import 'youtube_service.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    MusicCacheService? cacheService,
    YoutubeService? youtubeService,
  }) : _cacheService = cacheService ?? MusicCacheService(),
       _youtubeService = youtubeService ?? YoutubeService() {
    _init();
  }

  final MusicCacheService _cacheService;
  final YoutubeService _youtubeService;
  final AudioPlayer player = AudioPlayer();

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> duration = ValueNotifier(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  final List<Song> _queue = <Song>[];
  int _currentIndex = -1;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  String? _error;

  // 10-Song Auto-Pause feature
  bool _pauseEveryTenSongs = true;
  int _consecutivePlaysCount = 0;
  bool _isPausedByTenSongLimit = false;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  String? get error => _error;

  bool get pauseEveryTenSongs => _pauseEveryTenSongs;
  set pauseEveryTenSongs(bool value) {
    _pauseEveryTenSongs = value;
    notifyListeners();
  }

  int get consecutivePlaysCount => _consecutivePlaysCount;
  bool get isPausedByTenSongLimit => _isPausedByTenSongLimit;

  Song? get currentSong {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _subscriptions.add(
      player.positionStream.listen((value) => position.value = value),
    );
    _subscriptions.add(
      player.durationStream.listen((value) => duration.value = value),
    );
    _subscriptions.add(
      player.playerStateStream.listen((state) {
        isPlaying.value =
            state.playing && state.processingState != ProcessingState.completed;
        isBuffering.value =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;

        if (state.processingState == ProcessingState.completed) {
          _handleTrackCompleted();
        }
      }),
    );
  }

  bool _isSameQueue(List<Song> songs) {
    if (_queue.length != songs.length) return false;
    for (var i = 0; i < songs.length; i++) {
      if (_queue[i].id != songs[i].id) {
        return false;
      }
    }
    return true;
  }

  /// Starts playback from [index] in [songs].
  /// Supports both local and online songs, with multi-music caching.
  Future<void> playAt(List<Song> songs, int index) async {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    _error = null;
    _isPausedByTenSongLimit = false;
    _consecutivePlaysCount =
        0; // Reset consecutive counter for new playlist session

    final queueChanged = !_isSameQueue(songs);
    if (queueChanged) {
      _queue
        ..clear()
        ..addAll(songs);
    }
    _currentIndex = index;
    notifyListeners();

    await _loadAndPlayCurrent(autoPlay: true);
  }

  /// Resolves the playable URI for the track at [_currentIndex] and plays it.
  Future<void> _loadAndPlayCurrent({required bool autoPlay}) async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];
    _error = null;
    isBuffering.value = true;
    notifyListeners();

    try {
      Uri playableUri;

      if (song.isLocal) {
        playableUri = song.uri;
      } else {
        // 1. Check permanent download in device library
        final downloadedFile = await _youtubeService.getDownloadedFile(song);
        if (downloadedFile != null) {
          playableUri = Uri.file(downloadedFile.path);
        } else {
          // 2. Check local audio cache for multi-music caching
          final cachedFile = await _cacheService.getCachedFile(song.videoId);
          if (cachedFile != null) {
            playableUri = Uri.file(cachedFile.path);
          } else {
            // 3. Resolve stream URL from YouTube
            final resolvedSong = await _youtubeService.resolveStream(song);
            playableUri = resolvedSong.uri;

            // In background: cache this song to disk for instant replay and offline resilience
            unawaited(_cacheService.cacheSong(song, streamUri: playableUri));
          }
        }
      }

      await player.setAudioSource(
        AudioSource.uri(
          playableUri,
          headers: song.isLocal
              ? null
              : const {'User-Agent': YoutubeService.userAgent},
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.duration,
            artUri: song.artworkUri,
          ),
        ),
      );

      if (autoPlay) {
        await player.play();
      }

      // Pre-cache upcoming songs in the queue so multi-music playback is seamless
      unawaited(_cacheService.precacheQueue(_queue, _currentIndex, count: 2));

      notifyListeners();
    } catch (e) {
      debugPrint('PlayerController: play error: $e');
      _error = 'Could not play this song.';
      isBuffering.value = false;
      notifyListeners();
    }
  }

  /// Automatically called when the current track finishes.
  Future<void> _handleTrackCompleted() async {
    if (_queue.isEmpty) return;

    if (_loopMode == LoopMode.one) {
      await player.seek(Duration.zero);
      await player.play();
      return;
    }

    _consecutivePlaysCount++;

    // "example in a search, it will play all the music, but pause every 10 songs"
    if (_pauseEveryTenSongs && _consecutivePlaysCount >= 10) {
      _isPausedByTenSongLimit = true;
      _consecutivePlaysCount = 0; // ready for the next 10-song batch
      await player.pause();

      final nextIdx = _calculateNextIndex();
      if (nextIdx != null) {
        _currentIndex = nextIdx;
        // Pre-load the next song without autoplay so it's ready the moment the user resumes
        await _loadAndPlayCurrent(autoPlay: false);
      }
      notifyListeners();
      return;
    }

    // Advance to next song in the queue
    await next();
  }

  /// Resumes playback when paused by the 10-song limit.
  Future<void> resumeFromTenSongLimit() async {
    _isPausedByTenSongLimit = false;
    _consecutivePlaysCount = 0;
    if (player.audioSource == null &&
        _currentIndex >= 0 &&
        _currentIndex < _queue.length) {
      await _loadAndPlayCurrent(autoPlay: true);
    } else {
      await player.play();
    }
    notifyListeners();
  }

  Future<void> togglePlay() async {
    if (_isPausedByTenSongLimit) {
      await resumeFromTenSongLimit();
      return;
    }

    final completed = player.processingState == ProcessingState.completed;
    if (player.playing && !completed) {
      await player.pause();
    } else {
      if (completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    final nextIdx = _calculateNextIndex();
    if (nextIdx != null) {
      _currentIndex = nextIdx;
      await _loadAndPlayCurrent(autoPlay: true);
    } else {
      await player.pause();
      await player.seek(Duration.zero);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    try {
      if (position.value > const Duration(seconds: 3)) {
        await player.seek(Duration.zero);
        await player.play();
        return;
      }
      final prevIdx = _calculatePreviousIndex();
      if (prevIdx != null) {
        _currentIndex = prevIdx;
        await _loadAndPlayCurrent(autoPlay: true);
      }
    } catch (_) {}
  }

  int? _calculateNextIndex() {
    if (_queue.isEmpty) return null;
    if (_shuffle && _queue.length > 1) {
      final random = math.Random();
      var nextIdx = random.nextInt(_queue.length);
      while (nextIdx == _currentIndex && _queue.length > 1) {
        nextIdx = random.nextInt(_queue.length);
      }
      return nextIdx;
    }
    if (_currentIndex + 1 < _queue.length) {
      return _currentIndex + 1;
    }
    if (_loopMode == LoopMode.all) {
      return 0;
    }
    return null;
  }

  int? _calculatePreviousIndex() {
    if (_queue.isEmpty) return null;
    if (_currentIndex - 1 >= 0) {
      return _currentIndex - 1;
    }
    if (_loopMode == LoopMode.all) {
      return _queue.length - 1;
    }
    return 0;
  }

  Future<void> seek(Duration value) async {
    await player.seek(value);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  Future<void> cycleLoopMode() async {
    switch (_loopMode) {
      case LoopMode.off:
        _loopMode = LoopMode.all;
      case LoopMode.all:
        _loopMode = LoopMode.one;
      case LoopMode.one:
        _loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    position.dispose();
    duration.dispose();
    isPlaying.dispose();
    isBuffering.dispose();
    player.dispose();
    _youtubeService.dispose();
    _cacheService.dispose();
    super.dispose();
  }
}
