import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../screens/now_playing_screen.dart';
import 'artwork_widget.dart';

class MiniPlayer extends StatelessWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final SettingsService? settingsService;

  const MiniPlayer({
    super.key,
    required this.audioHandler,
    required this.storageService,
    this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        final cleanTitles = settingsService?.cleanTitlesEnabled ?? true;
        final displayTitle = cleanTitles
            ? SongModel.cleanSongTitle(mediaItem.title)
            : mediaItem.title;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingScreen(
                  audioHandler: audioHandler,
                  storageService: storageService,
                  settingsService: settingsService,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: settingsService?.surfaceColor ?? const Color(0xFF282828),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra di avanzamento sottile in cima al mini player
                StreamBuilder<Duration>(
                  stream: audioHandler.player.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration = audioHandler.player.duration ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;

                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'current_artwork',
                        child: ArtworkWidget(
                          title: displayTitle,
                          artist: mediaItem.artist ?? '',
                          size: 44,
                          borderRadius: 6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Titolo e artista
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mediaItem.artist ?? 'Artista sconosciuto',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play/Pause
                      StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, stateSnapshot) {
                          final isPlaying = stateSnapshot.data?.playing ?? false;
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                          );
                        },
                      ),
                      // Skip Next
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => audioHandler.skipToNext(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
