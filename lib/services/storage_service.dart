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

    // Prova prima con i permessi specifici audio (Android 13+)
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    // Se fallisce, prova il permesso classico storage
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    // Se ancora non concesso, prova manageExternalStorage per cartelle arbitrarie
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
  Future<List<SongModel>> scanConfiguredFolders() async {
    final folders = getFolders();
    final List<SongModel> songs = [];
    final Set<String> seenPaths = {};

    for (final folderPath in folders) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (_supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
              seenPaths.add(entity.path);
              songs.add(SongModel.fromFile(entity));
            }
          }
        }
      } catch (e) {
        debugPrint('Errore durante la scansione di $folderPath: $e');
      }
    }

    return songs;
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
