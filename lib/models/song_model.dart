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
  final int fileSize;
  final String fileExtension;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    this.durationMs = 0,
    this.dateModifiedMs = 0,
    this.fileSize = 0,
    this.fileExtension = '',
  });

  /// Stringa formattata per la dimensione del file (es: "4.8 MB")
  String get fileSizeFormatted {
    if (fileSize <= 0) return 'Dimensione sconosciuta';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Pulisce il titolo dai soliti tag di YouTube/downloader: [Official Video], (Lyrics), ecc.
  static String cleanSongTitle(String raw) {
    var cleaned = raw;

    // Rimuovi prefissi/suffissi tipici dei siti web di download
    cleaned = cleaned.replaceAll(RegExp(r'^(yt1s\.com|y2mate\.com|snaptube|savefrom)\s*[-_]?\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[SPOTIFY-DOWNLOADER\.COM\]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[SPOTIFLYER\]', caseSensitive: false), '');

    // Rimuovi tag comuni tra parentesi quadre o tonde
    final noisePatterns = [
      r'\[\s*(official\s*(music\s*)?video|video\s*ufficiale|official\s*audio|audio\s*ufficiale|official\s*hd|lyrics?|testo|hq|hd|4k|1080p|720p|explicit|visualizer|clip\s*officiel)\s*\]',
      r'\(\s*(official\s*(music\s*)?video|video\s*ufficiale|official\s*audio|audio\s*ufficiale|official\s*hd|lyrics?|testo|hq|hd|4k|1080p|720p|explicit|visualizer|clip\s*officiel)\s*\)',
      r'\[\s*(remastered(\s*\d{4})?|live(\s*version)?|bonus\s*track)\s*\]',
      r'\(\s*(remastered(\s*\d{4})?|live(\s*version)?|bonus\s*track)\s*\)',
      r'\[\s*\d{2,3}kbps\s*\]',
      r'\(\s*\d{2,3}kbps\s*\)',
    ];

    for (final pattern in noisePatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // Rimuovi eventuali parentesi rimaste vuote: (), [], {}
    cleaned = cleaned.replaceAll(RegExp(r'\[\s*\]|\(\s*\)|\{\s*\}'), '');

    // Normalizza spazi multipli e rimuovi spazi e trattini finali rimasti
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[-–—]\s*$'), '').trim();

    return cleaned.isEmpty ? raw : cleaned;
  }

  /// Restituisce il titolo formattato in base all'impostazione Clean Titles
  String displayTitle(bool cleanTitlesEnabled) {
    if (!cleanTitlesEnabled) return title;
    return cleanSongTitle(title);
  }

  factory SongModel.fromFile(File file) {
    final rawName = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path).toLowerCase();
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
      // Pulizia underscore o trattini isolati
      title = rawName.replaceAll('_', ' ').trim();
    }

    int dateModified = 0;
    int size = 0;
    try {
      final stat = file.statSync();
      dateModified = stat.modified.millisecondsSinceEpoch;
      size = stat.size;
    } catch (_) {}

    return SongModel(
      id: file.path,
      title: title.isEmpty ? 'Traccia senza titolo' : title,
      artist: artist,
      album: p.basename(p.dirname(file.path)),
      path: file.path,
      durationMs: 0,
      dateModifiedMs: dateModified,
      fileSize: size,
      fileExtension: ext,
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
        'fileSize': fileSize,
        'fileExtension': fileExtension,
      };

  factory SongModel.fromJson(Map<String, dynamic> json) => SongModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Traccia senza titolo',
        artist: json['artist'] as String? ?? 'Artista sconosciuto',
        album: json['album'] as String? ?? 'Album sconosciuto',
        path: json['path'] as String? ?? '',
        durationMs: json['durationMs'] as int? ?? 0,
        dateModifiedMs: json['dateModifiedMs'] as int? ?? 0,
        fileSize: json['fileSize'] as int? ?? 0,
        fileExtension: json['fileExtension'] as String? ?? '',
      );

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? path,
    int? durationMs,
    int? dateModifiedMs,
    int? fileSize,
    String? fileExtension,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      durationMs: durationMs ?? this.durationMs,
      dateModifiedMs: dateModifiedMs ?? this.dateModifiedMs,
      fileSize: fileSize ?? this.fileSize,
      fileExtension: fileExtension ?? this.fileExtension,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}
