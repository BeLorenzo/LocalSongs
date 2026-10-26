import 'package:flutter/material.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../services/storage_service.dart';
import 'artwork_widget.dart';
import 'animated_equalizer.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final bool isPlayingAudio;
  final VoidCallback onTap;
  final StorageService storageService;
  final VoidCallback onStateChanged;

  const SongTile({
    super.key,
    required this.song,
    required this.isPlaying,
    this.isPlayingAudio = true,
    required this.onTap,
    required this.storageService,
    required this.onStateChanged,
  });

  void _showAddToPlaylistDialog(BuildContext context) {
    final playlists = storageService.getPlaylists();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF282828),
              title: const Text('Aggiungi a playlist', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_box_rounded, color: Color(0xFF1DB954)),
                      title: const Text('Crea nuova playlist', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        showDialog(
                          context: ctx,
                          builder: (subCtx) {
                            return AlertDialog(
                              backgroundColor: const Color(0xFF282828),
                              title: const Text('Nuova Playlist', style: TextStyle(color: Colors.white)),
                              content: TextField(
                                controller: textController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Nome playlist',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF1DB954)),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(subCtx),
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
                                        songPaths: [song.path],
                                      );
                                      await storageService.savePlaylist(newPl);
                                      if (subCtx.mounted) Navigator.pop(subCtx);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      onStateChanged();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Aggiunto a "$name"')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Crea e aggiungi'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const Divider(color: Colors.white24),
                    if (playlists.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Nessuna playlist creata.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, i) {
                            final pl = playlists[i];
                            final containsSong = pl.songPaths.contains(song.path);
                            return ListTile(
                              leading: const Icon(Icons.playlist_play_rounded, color: Colors.white70),
                              title: Text(pl.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${pl.songPaths.length} brani', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              trailing: containsSong
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954))
                                  : null,
                              onTap: () async {
                                if (containsSong) {
                                  await storageService.removeSongFromPlaylist(pl.id, song.path);
                                } else {
                                  await storageService.addSongToPlaylist(pl.id, song.path);
                                }
                                setDialogState(() {});
                                onStateChanged();
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Chiudi', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = storageService.isFavorite(song.path);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ArtworkWidget(
            title: song.title,
            artist: song.artist,
            size: 48,
            borderRadius: 6,
          ),
          if (isPlaying)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: AnimatedEqualizerBars(
                isPlaying: isPlayingAudio,
                size: 22,
              ),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? const Color(0xFF1DB954) : Colors.white,
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? const Color(0xFF1DB954) : Colors.white38,
              size: 22,
            ),
            onPressed: () async {
              await storageService.toggleFavorite(song.path);
              onStateChanged();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
            color: const Color(0xFF282828),
            onSelected: (val) {
              if (val == 'playlist') {
                _showAddToPlaylistDialog(context);
              } else if (val == 'info') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF282828),
                    title: const Text('Info Traccia', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Titolo: ${song.title}\nArtista: ${song.artist}\nAlbum: ${song.album}\n\nPercorso:\n${song.path}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK', style: TextStyle(color: Color(0xFF1DB954))),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Aggiungi a playlist', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Info file', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
