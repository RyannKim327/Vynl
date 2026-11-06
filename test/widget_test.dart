import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vynl/models/song.dart';
import 'package:vynl/widgets/song_tile.dart';

void main() {
  final testSong = Song.fromYoutube(
    videoId: 'test_123',
    title: 'Test Song Title',
    artist: 'Test Artist',
    duration: const Duration(minutes: 3, seconds: 45),
    artworkUri: null,
  );

  testWidgets(
    'SongTile renders download button when not downloading or downloaded',
    (tester) async {
      var downloaded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongTile(
              song: testSong,
              showPlayState: false,
              onTap: () {},
              onDownload: () => downloaded = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Song Title'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.download_rounded));
      expect(downloaded, isTrue);
    },
  );

  testWidgets('SongTile renders progress bar and status when downloading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongTile(
            song: testSong,
            showPlayState: false,
            isDownloading: true,
            downloadProgress: 0.45,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.text('Downloading (45%) • Test Artist'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsWidgets);
  });

  testWidgets('SongTile renders checkmark when downloaded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongTile(
            song: testSong,
            showPlayState: false,
            isDownloaded: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.text('Downloaded • Test Artist'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
  });

  testWidgets('SongTile renders cached indicator when isCached is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongTile(
            song: testSong,
            isCached: true,
            showPlayState: true,
            onTap: () {},
            onDownload: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test Song Title'), findsOneWidget);
    expect(find.text('Cached • Test Artist'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
  });

  testWidgets(
    'SongTile renders playing equalizer icon when playing and current',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongTile(
              song: testSong,
              isCurrent: true,
              isPlaying: true,
              showPlayState: true,
              onTap: () {},
              onDownload: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Song Title'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    },
  );
}
