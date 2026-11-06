import 'dart:convert';

import 'package:http/http.dart' as http;
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
          artist: _text(video['ownerText']) ?? 'YouTube',
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

  Future<Song> resolveStream(Song song) async {
    final manifest = await _youtube.videos.streams.getManifest(song.videoId);
    if (manifest.audioOnly.isEmpty) {
      throw Exception('No audio stream is available for this video.');
    }
    final audio = manifest.audioOnly.withHighestBitrate();
    return song.withStreamUri(audio.url);
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
