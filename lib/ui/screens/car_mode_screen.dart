import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../widgets/artwork_widget.dart';

class CarModeScreen extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final SettingsService settingsService;

  const CarModeScreen({
    super.key,
    required this.audioHandler,
    required this.storageService,
    required this.settingsService,
  });

  @override
  State<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends State<CarModeScreen> {
  String? _gestureFeedback;

  @override
  void initState() {
    super.initState();
    // Nascondi barre di sistema per immersione totale in auto
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Autoplay: all'ingresso in modalità guida fa partire subito la musica
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlaybackIfStopped();
    });
  }

  Future<void> _startPlaybackIfStopped() async {
    final isPlaying = widget.audioHandler.playbackState.value.playing;
    if (isPlaying) return;

    // Se c'è già una canzone nel player o in coda, fai play
    if (widget.audioHandler.mediaItem.value != null) {
      await widget.audioHandler.play();
      _triggerFeedback('RIPRODUZIONE AVVIATA ▶️');
    } else {
      // Altrimenti carica e avvia subito il primo brano della libreria
      final songs = await widget.storageService.scanConfiguredFolders(
        minDurationSeconds: widget.settingsService.minDurationSeconds,
      );
      if (songs.isNotEmpty && mounted) {
        final sorted = StorageService.sortSongs(songs, widget.storageService.getSortOrder());
        await widget.audioHandler.playSongList(sorted, 0);
        _triggerFeedback('MUSICA AVVIATA ▶️');
      }
    }
  }

  @override
  void dispose() {
    // Ripristina barre di sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _triggerFeedback(String message) {
    setState(() => _gestureFeedback = message);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _gestureFeedback = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.settingsService.accentColor;

    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        final rawTitle = mediaItem?.title ?? 'Nessun brano';
        final displayTitle = widget.settingsService.cleanTitlesEnabled
            ? SongModel.cleanSongTitle(rawTitle)
            : rawTitle;
        final artist = mediaItem?.artist ?? 'Seleziona una canzone';
        final songPath = mediaItem?.id ?? '';
        final isFav = songPath.isNotEmpty && widget.storageService.isFavorite(songPath);

        return StreamBuilder<PlaybackState>(
          stream: widget.audioHandler.playbackState,
          builder: (context, stateSnapshot) {
            final playbackState = stateSnapshot.data;
            final isPlaying = playbackState?.playing ?? false;

            return Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isPlaying) {
                    widget.audioHandler.pause();
                    _triggerFeedback('PAUSA');
                  } else {
                    widget.audioHandler.play();
                    _triggerFeedback('RIPRODUCI');
                  }
                },
                onDoubleTap: () async {
                  if (songPath.isNotEmpty) {
                    await widget.storageService.toggleFavorite(songPath);
                    setState(() {});
                    _triggerFeedback(widget.storageService.isFavorite(songPath)
                        ? 'AGGIUNTO AI PREFERITI ❤️'
                        : 'RIMOSSO DAI PREFERITI 🤍');
                  }
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300) {
                    // Swipe verso sinistra -> Prossimo brano
                    widget.audioHandler.skipToNext();
                    _triggerFeedback('BRANO SUCCESSIVO ⏭️');
                  } else if (velocity > 300) {
                    // Swipe verso destra -> Brano precedente
                    widget.audioHandler.skipToPrevious();
                    _triggerFeedback('BRANO PRECEDENTE ⏮️');
                  }
                },
                child: SafeArea(
                  child: Stack(
                    children: [
                      // CONTENUTO PRINCIPALE AD ALTO CONTRASTO
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // TOP BAR
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.directions_car_rounded, color: accentColor, size: 28),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'MODALITÀ GUIDA',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
                                  tooltip: 'Esci dalla modalità guida',
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),

                            // SEZIONE CENTRALE: COVER E TESTI GIGANTI
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ArtworkWidget(
                                    title: displayTitle,
                                    artist: artist,
                                    size: 160,
                                    borderRadius: 16,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // GESTURE HINT SUL FONDO
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                'Tocca = Play/Pausa • Swipe = Brani • Doppio tocco = Preferito',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ),

                            // CONTROLLI TASTI GIGANTI
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Tasto Preferiti Gigante
                                  IconButton(
                                    iconSize: 44,
                                    icon: Icon(
                                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isFav ? accentColor : Colors.white60,
                                    ),
                                    onPressed: () async {
                                      if (songPath.isNotEmpty) {
                                        await widget.storageService.toggleFavorite(songPath);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  // Prev Gigante
                                  IconButton(
                                    iconSize: 56,
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                                    onPressed: () => widget.audioHandler.skipToPrevious(),
                                  ),
                                  // Play / Pause Gigante
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withAlpha(100),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      iconSize: 48,
                                      icon: Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                      ),
                                      onPressed: () {
                                        if (isPlaying) {
                                          widget.audioHandler.pause();
                                        } else {
                                          widget.audioHandler.play();
                                        }
                                      },
                                    ),
                                  ),
                                  // Next Gigante
                                  IconButton(
                                    iconSize: 56,
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                                    onPressed: () => widget.audioHandler.skipToNext(),
                                  ),
                                  // Shuffle
                                  IconButton(
                                    iconSize: 38,
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      color: widget.audioHandler.isShuffleActive
                                          ? accentColor
                                          : Colors.white38,
                                    ),
                                    onPressed: () => widget.audioHandler.toggleShuffleMode(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // OVERLAY FEEDBACK GESTURE AL CENTRO
                      if (_gestureFeedback != null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(220),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: accentColor, width: 2),
                            ),
                            child: Text(
                              _gestureFeedback!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
