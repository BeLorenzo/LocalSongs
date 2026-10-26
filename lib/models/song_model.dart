import 'dart:io';
import 'package:path/path.dart' as p;

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final int durationMs;
  final int dateModifiedMs;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    this.durationMs = 0,
    this.dateModifiedMs = 0,
  });

  factory SongModel.fromFile(File file) {
    final rawName = p.basenameWithoutExtension(file.path);
    String artist = 'Artista sconosciuto';
    String title = rawName;

    // Se il nome file è nel formato "Artista - Titolo"
    if (rawName.contains(' - ')) {
      final parts = rawName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    } else {
      // Pulizia underscore o trattini
      title = rawName.replaceAll('_', ' ').trim();
    }

    int dateModified = 0;
    try {
      dateModified = file.lastModifiedSync().millisecondsSinceEpoch;
    } catch (_) {}

    return SongModel(
      id: file.path,
      title: title.isEmpty ? 'Traccia senza titolo' : title,
      artist: artist,
      album: p.basename(p.dirname(file.path)),
      path: file.path,
      durationMs: 0,
      dateModifiedMs: dateModified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'path': path,
        'durationMs': durationMs,
        'dateModifiedMs': dateModifiedMs,
      };

  factory SongModel.fromJson(Map<String, dynamic> json) => SongModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Traccia senza titolo',
        artist: json['artist'] as String? ?? 'Artista sconosciuto',
        album: json['album'] as String? ?? 'Album sconosciuto',
        path: json['path'] as String? ?? '',
        durationMs: json['durationMs'] as int? ?? 0,
        dateModifiedMs: json['dateModifiedMs'] as int? ?? 0,
      );

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    int? durationMs,
    int? dateModifiedMs,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      durationMs: durationMs ?? this.durationMs,
      dateModifiedMs: dateModifiedMs ?? this.dateModifiedMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
