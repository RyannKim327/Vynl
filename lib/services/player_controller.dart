import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';

class PlayerController extends ChangeNotifier {
  PlayerController() {
    _init();
  }

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

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Song> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  bool get shuffle => _shuffle;
  LoopMode get loopMode => _loopMode;
  String? get error => _error;

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
      }),
    );
    _subscriptions.add(
      player.currentIndexStream.listen((index) {
        if (index != null && index != _currentIndex) {
          _currentIndex = index;
          notifyListeners();
        }
      }),
    );
  }

  bool _isSameQueue(List<Song> songs) {
    if (_queue.length != songs.length) return false;
    for (var i = 0; i < songs.length; i++) {
      if (_queue[i].id != songs[i].id || _queue[i].uri != songs[i].uri) {
        return false;
      }
    }
    return true;
  }

  Future<void> playAt(List<Song> songs, int index) async {
    if (songs.isEmpty) return;
    _error = null;
    try {
      if (!_isSameQueue(songs)) {
        _queue
          ..clear()
          ..addAll(songs);
        _currentIndex = index;
        await player.setAudioSources(
          songs
              .map(
                (song) => AudioSource.uri(
                  song.uri,
                  tag: MediaItem(
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    duration: song.duration,
                    artUri: song.artworkUri,
                  ),
                ),
              )
              .toList(),
          initialIndex: index,
          initialPosition: Duration.zero,
        );
        notifyListeners();
      } else {
        await player.seek(Duration.zero, index: index);
      }
      await player.play();
    } catch (e) {
      _error = 'Could not play this file.';
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    final completed = player.processingState == ProcessingState.completed;
    if (player.playing && !completed) {
      await player.pause();
    } else {
      if (completed) {
        await player.seek(Duration.zero, index: _currentIndex);
      }
      await player.play();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    try {
      await player.seekToNext();
      await player.play();
    } catch (_) {}
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    try {
      if (position.value > const Duration(seconds: 3)) {
        await player.seek(Duration.zero);
      } else {
        await player.seekToPrevious();
      }
      await player.play();
    } catch (_) {}
  }

  Future<void> seek(Duration value) async {
    await player.seek(value);
  }

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    await player.setShuffleModeEnabled(_shuffle);
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
    await player.setLoopMode(_loopMode);
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
    super.dispose();
  }
}
