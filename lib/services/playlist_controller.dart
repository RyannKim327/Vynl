import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistController extends ChangeNotifier {
  static const _fileName = 'playlists.json';

  List<Playlist> _playlists = const [];
  bool _loaded = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is List) {
          final playlists = <Playlist>[];
          for (final item in data) {
            if (item is! Map) continue;
            try {
              playlists.add(Playlist.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
          _playlists = playlists;
        }
      }
    } catch (_) {
      _playlists = const [];
    }

    _loaded = true;
    notifyListeners();
  }

  Playlist? byId(String id) {
    for (final playlist in _playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  Future<Playlist> create(String name) async {
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      songs: const [],
    );
    _playlists = [..._playlists, playlist];
    notifyListeners();
    await _save();
    return playlist;
  }

  Future<void> rename(String id, String name) async {
    final index = _playlists.indexWhere((playlist) => playlist.id == id);
    if (index == -1) return;
    final updated = [..._playlists];
    updated[index] = updated[index].copyWith(name: name);
    _playlists = updated;
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _playlists = _playlists
        .where((playlist) => playlist.id != id)
        .toList(growable: false);
    notifyListeners();
    await _save();
  }

  Future<bool> addSong(String playlistId, Song song) async {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (playlist.songs.any((existing) => existing.id == song.id)) {
      return false;
    }

    final updated = [..._playlists];
    updated[index] = playlist.copyWith(songs: [...playlist.songs, song]);
    _playlists = updated;
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> removeSong(String playlistId, String songId) async {
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index == -1) return;

    final playlist = _playlists[index];
    final songs = playlist.songs
        .where((song) => song.id != songId)
        .toList(growable: false);
    if (songs.length == playlist.songs.length) return;

    final updated = [..._playlists];
    updated[index] = playlist.copyWith(songs: songs);
    _playlists = updated;
    notifyListeners();
    await _save();
  }

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(_playlists.map((playlist) => playlist.toJson()).toList()),
      );
    } catch (_) {}
  }
}
