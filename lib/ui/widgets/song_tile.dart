import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
  final bool cleanTitlesEnabled;

  const SongTile({
    super.key,
    required this.song,
    required this.isPlaying,
    this.isPlayingAudio = true,
    required this.onTap,
    required this.storageService,
    required this.onStateChanged,
    this.cleanTitlesEnabled = true,
  });

  void _showAddToPlaylistDialog(BuildContext context) {
    final playlists = storageService.getPlaylists();
    final textController = TextEditingController();
    final primaryColor = Theme.of(context).colorScheme.primary;

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
                      leading: Icon(Icons.add_box_rounded, color: primaryColor),
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
                                decoration: InputDecoration(
                                  hintText: 'Nome playlist',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: primaryColor),
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
                                    backgroundColor: primaryColor,
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
                                  ? Icon(Icons.check_circle_rounded, color: primaryColor)
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

  void _shareSong(BuildContext context) {
    try {
      Share.shareXFiles(
        [XFile(song.path)],
        text: 'Ascolta "${song.title}" su LocalSongs!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore condivisione: $e')),
      );
    }
  }

  void _showSongDetailsDialog(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white70),
            SizedBox(width: 8),
            Text('Dettagli File Audio', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Titolo:', song.title),
            _buildDetailRow('Artista:', song.artist),
            _buildDetailRow('Album:', song.album),
            _buildDetailRow('Formato:', song.fileExtension.toUpperCase().replaceAll('.', '')),
            _buildDetailRow('Dimensione:', song.fileSizeFormatted),
            const SizedBox(height: 8),
            const Text('Percorso file:', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 2),
            SelectableText(
              song.path,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = storageService.isFavorite(song.path);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final displayTitle = song.displayTitle(cleanTitlesEnabled);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ArtworkWidget(
            title: displayTitle,
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
        displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? primaryColor : Colors.white,
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
              color: isFav ? primaryColor : Colors.white38,
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
              } else if (val == 'share') {
                _shareSong(context);
              } else if (val == 'info') {
                _showSongDetailsDialog(context);
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
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Condividi file', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Dettagli file', style: TextStyle(color: Colors.white)),
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
