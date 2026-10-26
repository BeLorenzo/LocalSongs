import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lettore_musicale/models/playlist_model.dart';
import 'package:lettore_musicale/models/song_model.dart';
import 'package:lettore_musicale/services/settings_service.dart';
import 'package:lettore_musicale/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SongModel Tests', () {
    test('Dovrebbe parsare correttamente i nomi file "Artista - Titolo"', () {
      final file = File('/storage/emulated/0/Music/Queen - Bohemian Rhapsody.mp3');
      final song = SongModel.fromFile(file);

      expect(song.artist, 'Queen');
      expect(song.title, 'Bohemian Rhapsody');
      expect(song.path, file.path);
    });

    test('Dovrebbe gestire nomi file senza artista esplicito', () {
      final file = File('/storage/emulated/0/Music/Track_Number_One.mp3');
      final song = SongModel.fromFile(file);

      expect(song.artist, 'Artista sconosciuto');
      expect(song.title, 'Track Number One');
    });

    test('Clean Titles: pulizia tag spazzatura da YouTube/downloader', () {
      expect(
        SongModel.cleanSongTitle('yt1s.com - Imagine Dragons - Believer [Official Video]'),
        'Imagine Dragons - Believer',
      );
      expect(
        SongModel.cleanSongTitle('The Weeknd - Blinding Lights (Lyrics)'),
        'The Weeknd - Blinding Lights',
      );
      expect(
        SongModel.cleanSongTitle('[SPOTIFY-DOWNLOADER.COM] Coldplay - Viva La Vida [HQ]'),
        'Coldplay - Viva La Vida',
      );
      expect(
        SongModel.cleanSongTitle('Queen - Another One Bites The Dust (Remastered 2011)'),
        'Queen - Another One Bites The Dust',
      );
    });

    test('fileSizeFormatted formatta correttamente i byte in KB e MB', () {
      const songSmall = SongModel(
        id: '1',
        title: 'T1',
        artist: 'A1',
        album: 'Al1',
        path: '/p1.mp3',
        fileSize: 512 * 1024, // 512 KB
      );
      expect(songSmall.fileSizeFormatted, '512.0 KB');

      const songBig = SongModel(
        id: '2',
        title: 'T2',
        artist: 'A2',
        album: 'Al2',
        path: '/p2.mp3',
        fileSize: 5 * 1024 * 1024, // 5 MB
      );
      expect(songBig.fileSizeFormatted, '5.00 MB');
    });

    test('Serializzazione e deserializzazione JSON', () {
      const song = SongModel(
        id: 'test_path',
        title: 'Canzone Test',
        artist: 'Artista Test',
        album: 'Album Test',
        path: '/path/test.mp3',
        fileSize: 4096,
        fileExtension: '.mp3',
      );

      final json = song.toJson();
      final fromJson = SongModel.fromJson(json);

      expect(fromJson.title, song.title);
      expect(fromJson.artist, song.artist);
      expect(fromJson.path, song.path);
      expect(fromJson.fileSize, 4096);
      expect(fromJson.fileExtension, '.mp3');
    });
  });

  group('StorageService & Stats Tests', () {
    test('formatBytes calcola correttamente B, KB, MB, GB', () {
      expect(StorageService.formatBytes(500), '500 B');
      expect(StorageService.formatBytes(2048), '2.0 KB');
      expect(StorageService.formatBytes(15 * 1024 * 1024), '15.0 MB');
      expect(StorageService.formatBytes((3.5 * 1024 * 1024 * 1024).toInt()), '3.50 GB');
    });
  });

  group('SettingsService Tests', () {
    test('Valori di default e persistenza impostazioni', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);

      expect(settings.isAmoledBlack, isFalse);
      expect(settings.isWavySeekBar, isTrue);
      expect(settings.minDurationSeconds, 0);
      expect(settings.cleanTitlesEnabled, isTrue);
      expect(settings.playbackSpeed, 1.0);
      expect(settings.seekStepSeconds, 10);

      await settings.setAmoledBlack(true);
      expect(settings.isAmoledBlack, isTrue);
      expect(settings.backgroundColor.toARGB32(), 0xFF000000);

      await settings.setMinDurationSeconds(30);
      expect(settings.minDurationSeconds, 30);

      await settings.setPlaybackSpeed(1.25);
      expect(settings.playbackSpeed, 1.25);
    });
  });

  group('PlaylistModel Tests', () {
    test('Gestione aggiunta e rimozione brani', () {
      final pl = PlaylistModel(
        id: '1',
        name: 'Rock',
        songPaths: ['/path/song1.mp3'],
      );

      final updated = pl.copyWith(
        songPaths: [...pl.songPaths, '/path/song2.mp3'],
      );

      expect(updated.songPaths.length, 2);
      expect(updated.songPaths.contains('/path/song2.mp3'), isTrue);
    });
  });
}
