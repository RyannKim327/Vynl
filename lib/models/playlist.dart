import 'song.dart';

class Playlist {
  const Playlist({required this.id, required this.name, required this.songs});

  final String id;
  final String name;
  final List<Song> songs;

  Playlist copyWith({String? name, List<Song>? songs}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((song) => song.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException('Invalid playlist');
    }

    final songs = <Song>[];
    final rawSongs = json['songs'];
    if (rawSongs is List) {
      for (final rawSong in rawSongs) {
        if (rawSong is! Map) continue;
        try {
          songs.add(Song.fromJson(Map<String, dynamic>.from(rawSong)));
        } catch (_) {}
      }
    }

    return Playlist(id: id, name: name, songs: songs);
  }
}
