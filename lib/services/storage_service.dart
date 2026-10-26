import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';

enum SongSortOrder {
  newestFirst,
  oldestFirst,
  titleAsc,
  titleDesc,
  artistAsc,
}

extension SongSortOrderExtension on SongSortOrder {
  String get label {
    switch (this) {
      case SongSortOrder.newestFirst:
        return 'Più recenti (Novità)';
      case SongSortOrder.oldestFirst:
        return 'Meno recenti';
      case SongSortOrder.titleAsc:
        return 'Titolo (A - Z)';
      case SongSortOrder.titleDesc:
        return 'Titolo (Z - A)';
      case SongSortOrder.artistAsc:
        return 'Artista (A - Z)';
    }
  }

  String get shortLabel {
    switch (this) {
      case SongSortOrder.newestFirst:
        return 'Novità';
      case SongSortOrder.oldestFirst:
        return 'Vecchi';
      case SongSortOrder.titleAsc:
        return 'A - Z';
      case SongSortOrder.titleDesc:
        return 'Z - A';
      case SongSortOrder.artistAsc:
        return 'Artista';
    }
  }
}

class LibraryStats {
  final int totalSongs;
  final int totalBytes;
  final String formattedSize;
  final int totalPlaylists;
  final int totalFolders;

  const LibraryStats({
    required this.totalSongs,
    required this.totalBytes,
    required this.formattedSize,
    required this.totalPlaylists,
    required this.totalFolders,
  });
}

class StorageService {
  static const _keyFolders = 'saved_music_folders';
  static const _keyFavorites = 'saved_favorite_paths';
  static const _keyPlaylists = 'saved_custom_playlists';
  static const _keySortOrder = 'saved_songs_sort_order';

  static const _supportedExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.m4a',
    '.ogg',
    '.opus',
    '.wma',
  };

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- GESTIONE ORDINAMENTO ---
  SongSortOrder getSortOrder() {
    final raw = _prefs.getString(_keySortOrder);
    if (raw == null) return SongSortOrder.titleAsc;
    return SongSortOrder.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SongSortOrder.titleAsc,
    );
  }

  Future<void> setSortOrder(SongSortOrder order) async {
    await _prefs.setString(_keySortOrder, order.name);
  }

  static List<SongModel> sortSongs(List<SongModel> songs, SongSortOrder order) {
    final list = List<SongModel>.from(songs);
    switch (order) {
      case SongSortOrder.newestFirst:
        list.sort((a, b) {
          final cmp = b.dateModifiedMs.compareTo(a.dateModifiedMs);
          if (cmp != 0) return cmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SongSortOrder.oldestFirst:
        list.sort((a, b) {
          final cmp = a.dateModifiedMs.compareTo(b.dateModifiedMs);
          if (cmp != 0) return cmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SongSortOrder.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SongSortOrder.titleDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SongSortOrder.artistAsc:
        list.sort((a, b) {
          final cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          if (cmp != 0) return cmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    return list;
  }

  // --- GESTIONE PERMESSI ---
  Future<bool> requestStoragePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    return false;
  }

  // --- CARTELLE SORGENTE ---
  List<String> getFolders() {
    return _prefs.getStringList(_keyFolders) ?? [];
  }

  Future<void> addFolder(String path) async {
    final current = getFolders();
    if (!current.contains(path)) {
      current.add(path);
      await _prefs.setStringList(_keyFolders, current);
    }
  }

  Future<void> removeFolder(String path) async {
    final current = getFolders();
    current.remove(path);
    await _prefs.setStringList(_keyFolders, current);
  }

  // --- SCANSIONE FILE AUDIO ---
  Future<List<SongModel>> scanConfiguredFolders({int minDurationSeconds = 0}) async {
    final folders = getFolders();
    final List<SongModel> songs = [];
    final Set<String> seenPaths = {};

    // Stima della dimensione minima in byte per filtrare file brevi (es. vocali whatsapp / suoni notifiche)
    // A ~96-128 kbps, 1 secondo sono circa ~12-16 KB.
    // 15s = ~180 KB, 30s = ~360 KB, 60s = ~720 KB
    final int minBytesThreshold = minDurationSeconds > 0 ? (minDurationSeconds * 12 * 1024) : 0;

    for (final folderPath in folders) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (_supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
              final song = SongModel.fromFile(entity);
              // Filtro audio brevi se impostato
              if (minBytesThreshold > 0 && song.fileSize > 0 && song.fileSize < minBytesThreshold) {
                continue;
              }
              seenPaths.add(entity.path);
              songs.add(song);
            }
          }
        }
      } catch (e) {
        debugPrint('Errore durante la scansione di $folderPath: $e');
      }
    }

    return songs;
  }

  // --- STATISTICHE LIBRERIA ---
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  LibraryStats getLibraryStats(List<SongModel> songs) {
    int totalBytes = 0;
    for (final song in songs) {
      totalBytes += song.fileSize;
    }
    return LibraryStats(
      totalSongs: songs.length,
      totalBytes: totalBytes,
      formattedSize: formatBytes(totalBytes),
      totalPlaylists: getPlaylists().length,
      totalFolders: getFolders().length,
    );
  }

  Future<void> clearTemporaryCache() async {
    try {
      final tempDir = Directory.systemTemp;
      if (await tempDir.exists()) {
        final entries = tempDir.listSync();
        for (final entry in entries) {
          try {
            if (entry.path.contains('localsongs') || entry.path.contains('flutter')) {
              entry.deleteSync(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Errore pulizia cache: $e');
    }
  }

  // --- PREFERITI ---
  Set<String> getFavorites() {
    final list = _prefs.getStringList(_keyFavorites) ?? [];
    return list.toSet();
  }

  Future<void> toggleFavorite(String path) async {
    final favs = getFavorites();
    if (favs.contains(path)) {
      favs.remove(path);
    } else {
      favs.add(path);
    }
    await _prefs.setStringList(_keyFavorites, favs.toList());
  }

  bool isFavorite(String path) {
    return getFavorites().contains(path);
  }

  // --- PLAYLIST ---
  List<PlaylistModel> getPlaylists() {
    final raw = _prefs.getStringList(_keyPlaylists) ?? [];
    return raw.map((item) {
      try {
        return PlaylistModel.fromJson(jsonDecode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<PlaylistModel>().toList();
  }

  Future<void> savePlaylist(PlaylistModel playlist) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index >= 0) {
      playlists[index] = playlist;
    } else {
      playlists.add(playlist);
    }
    await _savePlaylists(playlists);
  }

  Future<void> deletePlaylist(String id) async {
    final playlists = getPlaylists();
    playlists.removeWhere((p) => p.id == id);
    await _savePlaylists(playlists);
  }

  Future<void> addSongToPlaylist(String playlistId, String songPath) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final currentSongs = List<String>.from(playlists[index].songPaths);
      if (!currentSongs.contains(songPath)) {
        currentSongs.add(songPath);
        playlists[index] = playlists[index].copyWith(songPaths: currentSongs);
        await _savePlaylists(playlists);
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songPath) async {
    final playlists = getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final currentSongs = List<String>.from(playlists[index].songPaths);
      currentSongs.remove(songPath);
      playlists[index] = playlists[index].copyWith(songPaths: currentSongs);
      await _savePlaylists(playlists);
    }
  }

  Future<void> _savePlaylists(List<PlaylistModel> playlists) async {
    final raw = playlists.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_keyPlaylists, raw);
  }
}
