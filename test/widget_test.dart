import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lettore_musicale/models/playlist_model.dart';
import 'package:lettore_musicale/models/song_model.dart';

void main() {
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

    test('Serializzazione e deserializzazione JSON', () {
      const song = SongModel(
        id: 'test_path',
        title: 'Canzone Test',
        artist: 'Artista Test',
        album: 'Album Test',
        path: '/path/test.mp3',
      );

      final json = song.toJson();
      final fromJson = SongModel.fromJson(json);

      expect(fromJson.title, song.title);
      expect(fromJson.artist, song.artist);
      expect(fromJson.path, song.path);
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
