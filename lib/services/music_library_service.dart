import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';

class MusicLibraryService {
  MusicLibraryService({OnAudioQuery? query}) : _query = query ?? OnAudioQuery();

  final OnAudioQuery _query;

  OnAudioQuery get query => _query;

  Future<bool> requestPermission() async {
    final granted = await _query.permissionsStatus();
    if (granted) return true;
    return _query.permissionsRequest();
  }

  Future<List<Song>> loadSongs() async {
    final models = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return models
        .where((song) => song.data.isNotEmpty)
        .map(Song.fromLocalModel)
        .toList(growable: false);
  }
}
