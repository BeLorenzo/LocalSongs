import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/storage_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile.dart';
import '../widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;

  const HomeScreen({
    super.key,
    required this.audioHandler,
    required this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SongModel> _allSongs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late SongSortOrder _currentSortOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentSortOrder = widget.storageService.getSortOrder();
    _loadMusicLibrary();

    // Verifica automatica aggiornamenti all'avvio (come su Al-Piof)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateDialog.showIfAvailable(context);
    });
  }

  Future<void> _loadMusicLibrary() async {
    setState(() => _isLoading = true);
    await widget.storageService.requestStoragePermissions();
    final songs = await widget.storageService.scanConfiguredFolders();
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickNewFolder() async {
    final hasPerm = await widget.storageService.requestStoragePermissions();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permessi di archiviazione negati. Abilitali nelle impostazioni.'),
          ),
        );
      }
      return;
    }

    try {
      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        await widget.storageService.addFolder(selectedDirectory);
        await _loadMusicLibrary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cartella aggiunta: $selectedDirectory')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la selezione: $e')),
        );
      }
    }
  }

  void _playSong(List<SongModel> playlist, int index) {
    widget.audioHandler.playSongList(playlist, index);
  }

  void _shuffleAll(List<SongModel> songs) {
    if (songs.isEmpty) return;
    widget.audioHandler.playShuffled(songs);
  }

  void _showSortOrderBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.sort_rounded, color: Color(0xFF1DB954), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Ordina brani per',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                ...SongSortOrder.values.map((order) {
                  final isSelected = order == _currentSortOrder;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? const Color(0xFF1DB954) : Colors.grey,
                      size: 20,
                    ),
                    title: Text(
                      order.label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF1DB954) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _currentSortOrder = order;
                      });
                      widget.storageService.setSortOrder(order);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPlaylistDetail(String title, List<SongModel> songs, {String? playlistId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          title: title,
          songs: songs,
          playlistId: playlistId,
          audioHandler: widget.audioHandler,
          storageService: widget.storageService,
          onPlaylistUpdated: () {
            setState(() {});
          },
        ),
      ),
    );
  }

  void _createNewPlaylistDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Nuova Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nome della playlist',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1DB954)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                final newPl = PlaylistModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  songPaths: [],
                );
                await widget.storageService.savePlaylist(newPl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSongs = _allSongs.where((s) {
      final q = _searchQuery.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'LocalSongs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.white),
            tooltip: 'Riscansiona libreria',
            onPressed: _loadMusicLibrary,
          ),
          IconButton(
            icon: const Icon(Icons.system_update_rounded, color: Colors.white),
            tooltip: 'Controlla aggiornamenti',
            onPressed: () {
              UpdateDialog.showIfAvailable(context, force: true, showToastIfUpToDate: true);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cerca brano, artista o album...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF1DB954),
                labelColor: const Color(0xFF1DB954),
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'BRANI'),
                  Tab(text: 'PLAYLIST'),
                  Tab(text: 'CARTELLE'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: BRANI
                      _buildSongsTab(filteredSongs),

                      // TAB 2: PLAYLIST
                      _buildPlaylistsTab(),

                      // TAB 3: CARTELLE
                      _buildFoldersTab(),
                    ],
                  ),
          ),
          // MINI PLAYER ANCORATO IN BASSO
          MiniPlayer(
            audioHandler: widget.audioHandler,
            storageService: widget.storageService,
          ),
        ],
      ),
    );
  }

  // --- TAB BRANI ---
  Widget _buildSongsTab(List<SongModel> songs) {
    if (widget.storageService.getFolders().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open_rounded, size: 70, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Nessuna cartella configurata',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seleziona le cartelle del telefono contenenti la tua musica per iniziare.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi Cartella', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _pickNewFolder,
              ),
            ],
          ),
        ),
      );
    }

    if (songs.isEmpty) {
      return const Center(
        child: Text('Nessun brano trovato nelle cartelle selezionate.', style: TextStyle(color: Colors.grey)),
      );
    }

    // Applica l'ordinamento dinamico corrente
    final sortedSongs = StorageService.sortSongs(songs, _currentSortOrder);

    return Column(
      children: [
        // Barra controlli ordinamento e riproduzione
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                '${sortedSongs.length} brani',
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              // Tasto Riproduci sequenziale (dalla prima all'ultima nell'ordine scelto)
              InkWell(
                onTap: () {
                  if (sortedSongs.isNotEmpty) {
                    _playSong(sortedSongs, 0);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 18, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Riproduci',
                        style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tasto Shuffle rapido
              InkWell(
                onTap: () => _shuffleAll(sortedSongs),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.shuffle_rounded, size: 18, color: Color(0xFF1DB954)),
                ),
              ),
              const SizedBox(width: 8),
              // Selettore ordinamento
              InkWell(
                onTap: () => _showSortOrderBottomSheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _currentSortOrder.shortLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<PlaybackState>(
            stream: widget.audioHandler.playbackState,
            builder: (context, playSnapshot) {
              final isPlayingAudio = playSnapshot.data?.playing ?? false;
              return StreamBuilder<MediaItem?>(
                stream: widget.audioHandler.mediaItem,
                builder: (context, mediaSnapshot) {
                  final currentMediaId = mediaSnapshot.data?.id;
                  return ListView.builder(
                    itemCount: sortedSongs.length,
                    itemBuilder: (context, index) {
                      final song = sortedSongs[index];
                      final isCurrent = currentMediaId == song.path;

                      return SongTile(
                        song: song,
                        isPlaying: isCurrent,
                        isPlayingAudio: isPlayingAudio,
                        storageService: widget.storageService,
                        onTap: () => _playSong(sortedSongs, index),
                        onStateChanged: () => setState(() {}),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB PLAYLIST ---
  Widget _buildPlaylistsTab() {
    final playlists = widget.storageService.getPlaylists();
    final favPaths = widget.storageService.getFavorites();
    final favSongs = _allSongs.where((s) => favPaths.contains(s.path)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bottone Nuova Playlist
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: const Color(0xFF282828),
          leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF1DB954), size: 36),
          title: const Text('Crea Nuova Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onTap: _createNewPlaylistDialog,
        ),
        const SizedBox(height: 12),

        // Preferiti sempre in cima
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: const Color(0xFF1E1E1E),
          leading: const Icon(Icons.favorite_rounded, color: Color(0xFF1DB954), size: 32),
          title: const Text('Brani Preferiti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('${favSongs.length} brani', style: const TextStyle(color: Colors.grey)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          onTap: () => _openPlaylistDetail('Brani Preferiti', favSongs),
        ),
        const SizedBox(height: 8),

        // Elenco Playlist create dall'utente
        ...playlists.map((pl) {
          final count = pl.songPaths.length;
          final playlistSongs = _allSongs.where((s) => pl.songPaths.contains(s.path)).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: const Color(0xFF1E1E1E),
              leading: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 32),
              title: Text(pl.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text('$count brani', style: const TextStyle(color: Colors.grey)),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                color: const Color(0xFF282828),
                onSelected: (val) async {
                  if (val == 'delete') {
                    await widget.storageService.deletePlaylist(pl.id);
                    setState(() {});
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text('Elimina', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _openPlaylistDetail(pl.name, playlistSongs, playlistId: pl.id),
            ),
          );
        }),
      ],
    );
  }

  // --- TAB CARTELLE ---
  Widget _buildFoldersTab() {
    final folders = widget.storageService.getFolders();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bottone Aggiungi Cartella
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.create_new_folder_rounded),
          label: const Text('Aggiungi Cartella di Musica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          onPressed: _pickNewFolder,
        ),
        const SizedBox(height: 16),

        if (folders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Nessuna cartella presente. Aggiungine una per fare la scansione dei file musicali.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...folders.map(
            (f) => Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.folder_rounded, color: Color(0xFF1DB954)),
                title: Text(f, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await widget.storageService.removeFolder(f);
                    await _loadMusicLibrary();
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- DETTAGLIO PLAYLIST ---
class PlaylistDetailScreen extends StatefulWidget {
  final String title;
  final List<SongModel> songs;
  final String? playlistId;
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final VoidCallback onPlaylistUpdated;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    required this.songs,
    this.playlistId,
    required this.audioHandler,
    required this.storageService,
    required this.onPlaylistUpdated,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<SongModel> _currentSongs;

  @override
  void initState() {
    super.initState();
    _currentSongs = List.from(widget.songs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentSongs.length} brani',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                if (_currentSongs.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Riproduci'),
                        onPressed: () {
                          widget.audioHandler.playSongList(_currentSongs, 0);
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded, color: Color(0xFF1DB954)),
                        tooltip: 'Casuale',
                        onPressed: () {
                          widget.audioHandler.playShuffled(_currentSongs);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _currentSongs.isEmpty
                ? const Center(
                    child: Text('Nessun brano in questa playlist.', style: TextStyle(color: Colors.grey)),
                  )
                : StreamBuilder<PlaybackState>(
                    stream: widget.audioHandler.playbackState,
                    builder: (context, playSnapshot) {
                      final isPlayingAudio = playSnapshot.data?.playing ?? false;
                      return StreamBuilder<MediaItem?>(
                        stream: widget.audioHandler.mediaItem,
                        builder: (context, mediaSnapshot) {
                          final currentMediaId = mediaSnapshot.data?.id;
                          return ListView.builder(
                            itemCount: _currentSongs.length,
                            itemBuilder: (context, index) {
                              final song = _currentSongs[index];
                              final isCurrent = currentMediaId == song.path;

                              return SongTile(
                                song: song,
                                isPlaying: isCurrent,
                                isPlayingAudio: isPlayingAudio,
                                storageService: widget.storageService,
                                onTap: () {
                                  widget.audioHandler.playSongList(_currentSongs, index);
                                },
                                onStateChanged: () {
                                  setState(() {});
                                  widget.onPlaylistUpdated();
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          MiniPlayer(
            audioHandler: widget.audioHandler,
            storageService: widget.storageService,
          ),
        ],
      ),
    );
  }
}
