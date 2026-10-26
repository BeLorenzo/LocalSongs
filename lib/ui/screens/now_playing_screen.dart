import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/song_model.dart';
import '../../services/audio_handler.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../widgets/artwork_widget.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/wavy_seek_bar.dart';
import 'car_mode_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;
  final SettingsService? settingsService;

  const NowPlayingScreen({
    super.key,
    required this.audioHandler,
    required this.storageService,
    this.settingsService,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double _dragDistance = 0;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours > 0 ? '${duration.inHours}:' : '';
    return '$hours$minutes:$seconds';
  }

  void _showOptionsMenu(BuildContext context, MediaItem? mediaItem) {
    final accentColor = widget.settingsService?.accentColor ?? const Color(0xFF1DB954);
    final surfaceColor = widget.settingsService?.surfaceColor ?? const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // MODALITÀ GUIDA
                ListTile(
                  leading: Icon(Icons.directions_car_rounded, color: accentColor),
                  title: const Text('Modalità Guida (Car Mode)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Interfaccia a tutto schermo con tasti giganti', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (widget.settingsService != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CarModeScreen(
                            audioHandler: widget.audioHandler,
                            storageService: widget.storageService,
                            settingsService: widget.settingsService!,
                          ),
                        ),
                      );
                    }
                  },
                ),
                // EQUALIZZATORE DI SISTEMA
                ListTile(
                  leading: Icon(Icons.equalizer_rounded, color: accentColor),
                  title: const Text('Equalizzatore di Sistema', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Apri effetti audio nativi Android / Dolby', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final ok = await widget.audioHandler.openSystemEqualizer();
                    if (!ok) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Equalizzatore di sistema non disponibile.')),
                      );
                    }
                  },
                ),
                // CONDIVIDI FILE AUDIO
                if (mediaItem != null)
                  ListTile(
                    leading: Icon(Icons.share_rounded, color: accentColor),
                    title: const Text('Condividi file audio', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Invia MP3 tramite WhatsApp, Telegram, Quick Share', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Share.shareXFiles(
                        [XFile(mediaItem.id)],
                        text: 'Ascolta "${mediaItem.title}"!',
                      );
                    },
                  ),
                // SLEEP TIMER
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: accentColor),
                  title: const Text('Timer di spegnimento', style: TextStyle(color: Colors.white)),
                  subtitle: widget.audioHandler.sleepTimerEndTime != null
                      ? Text(
                          'Attivo (spegnimento tra ~${widget.audioHandler.sleepTimerEndTime!.difference(DateTime.now()).inMinutes + 1} min)',
                          style: TextStyle(color: accentColor, fontSize: 12),
                        )
                      : const Text('Disattivato', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSleepTimerDialog(context);
                  },
                ),
                // CODA DI RIPRODUZIONE
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: Colors.white70),
                  title: const Text('Coda di riproduzione', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${widget.audioHandler.queue.value.length} brani in coda',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showQueueBottomSheet(context);
                  },
                ),
                // DETTAGLI FILE
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                  title: const Text('Dettagli traccia', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    mediaItem?.id ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF282828),
                        title: const Text('Informazioni file', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Titolo: ${mediaItem?.title ?? "Sconosciuto"}\n'
                          'Artista: ${mediaItem?.artist ?? "Sconosciuto"}\n'
                          'Album: ${mediaItem?.album ?? "Sconosciuto"}\n'
                          'Durata: ${_formatDuration(mediaItem?.duration)}\n\n'
                          'Percorso su dispositivo:\n${mediaItem?.id ?? ""}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: Text('OK', style: TextStyle(color: accentColor)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Timer di Spegnimento', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerOption(ctx, context, '15 minuti', const Duration(minutes: 15)),
            _buildTimerOption(ctx, context, '30 minuti', const Duration(minutes: 30)),
            _buildTimerOption(ctx, context, '45 minuti', const Duration(minutes: 45)),
            _buildTimerOption(ctx, context, '60 minuti (1 ora)', const Duration(minutes: 60)),
            if (widget.audioHandler.sleepTimerEndTime != null) ...[
              const Divider(color: Colors.white24),
              ListTile(
                title: const Text('Disattiva timer', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  widget.audioHandler.setSleepTimer(null);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Timer di spegnimento disattivato')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(
    BuildContext dialogCtx,
    BuildContext scaffoldCtx,
    String label,
    Duration duration,
  ) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: () {
        widget.audioHandler.setSleepTimer(duration);
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
          SnackBar(content: Text('Timer impostato su $label')),
        );
      },
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    final accentColor = widget.settingsService?.accentColor ?? const Color(0xFF1DB954);
    final surfaceColor = widget.settingsService?.surfaceColor ?? const Color(0xFF1E1E1E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return StreamBuilder<List<MediaItem>>(
              stream: widget.audioHandler.queue,
              builder: (context, queueSnapshot) {
                final queue = queueSnapshot.data ?? [];
                final currentId = widget.audioHandler.mediaItem.value?.id;

                return StreamBuilder<PlaybackState>(
                  stream: widget.audioHandler.playbackState,
                  builder: (context, stateSnapshot) {
                    final isPlayingAudio = stateSnapshot.data?.playing ?? false;

                    return Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Coda di Riproduzione',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${queue.length} brani',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: ReorderableListView.builder(
                            scrollController: scrollController,
                            buildDefaultDragHandles: false,
                            itemCount: queue.length,
                            onReorder: (oldIndex, newIndex) {
                              widget.audioHandler.reorderQueue(oldIndex, newIndex);
                            },
                            itemBuilder: (context, i) {
                              final item = queue[i];
                              final isCurrent = item.id == currentId;
                              final cleanTitle = widget.settingsService?.cleanTitlesEnabled ?? true
                                  ? SongModel.cleanSongTitle(item.title)
                                  : item.title;

                              return ListTile(
                                key: ValueKey('queue_item_${item.id}_$i'),
                                leading: ArtworkWidget(
                                  title: cleanTitle,
                                  artist: item.artist ?? '',
                                  size: 40,
                                  borderRadius: 6,
                                ),
                                title: Text(
                                  cleanTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? accentColor : Colors.white,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  item.artist ?? 'Artista sconosciuto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCurrent)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: AnimatedEqualizerBars(
                                          isPlaying: isPlayingAudio,
                                          size: 16,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                                      tooltip: 'Rimuovi dalla coda',
                                      onPressed: () {
                                        widget.audioHandler.removeFromQueue(i);
                                      },
                                    ),
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  widget.audioHandler.skipToQueueItem(i);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.settingsService?.accentColor ?? const Color(0xFF1DB954);
    final bgColor = widget.settingsService?.backgroundColor ?? const Color(0xFF121212);
    final isWavy = widget.settingsService?.isWavySeekBar ?? true;
    final cleanTitles = widget.settingsService?.cleanTitlesEnabled ?? true;
    final seekStep = widget.settingsService?.seekStepSeconds ?? 10;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 36, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'IN RIPRODUZIONE',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            StreamBuilder<MediaItem?>(
              stream: widget.audioHandler.mediaItem,
              builder: (context, snapshot) {
                final album = snapshot.data?.album ?? 'Libreria Locale';
                return Text(
                  album,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Tasto rapido Car Mode
          if (widget.settingsService != null)
            IconButton(
              icon: const Icon(Icons.directions_car_rounded, color: Colors.white),
              tooltip: 'Modalità Guida',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CarModeScreen(
                      audioHandler: widget.audioHandler,
                      storageService: widget.storageService,
                      settingsService: widget.settingsService!,
                    ),
                  ),
                );
              },
            ),
          StreamBuilder<MediaItem?>(
            stream: widget.audioHandler.mediaItem,
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () => _showOptionsMenu(context, snapshot.data),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: widget.audioHandler.mediaItem,
        builder: (context, itemSnapshot) {
          final mediaItem = itemSnapshot.data;
          final isFav = mediaItem != null && widget.storageService.isFavorite(mediaItem.id);
          final rawTitle = mediaItem?.title ?? 'Nessun brano in riproduzione';
          final title = cleanTitles ? SongModel.cleanSongTitle(rawTitle) : rawTitle;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // --- COVER ARTWORK DINAMICA CON GESTURE SWIPE REATTIVA ---
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      _dragDistance = 0;
                    },
                    onHorizontalDragUpdate: (details) {
                      _dragDistance += details.primaryDelta ?? 0;
                    },
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (_dragDistance < -45 || v < -200) {
                        widget.audioHandler.skipToNext();
                      } else if (_dragDistance > 45 || v > 200) {
                        widget.audioHandler.skipToPrevious();
                      }
                      _dragDistance = 0;
                    },
                    child: Hero(
                      tag: 'current_artwork',
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ArtworkWidget(
                          title: title,
                          artist: mediaItem?.artist ?? '',
                          size: double.infinity,
                          borderRadius: 20,
                          isLarge: true,
                        ),
                      ),
                    ),
                  ),

                  // --- INFO BRANO & FAVORITE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mediaItem?.artist ?? 'Artista sconosciuto',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? accentColor : Colors.white60,
                          size: 28,
                        ),
                        onPressed: () async {
                          if (mediaItem != null) {
                            await widget.storageService.toggleFavorite(mediaItem.id);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),

                  // --- SEEKBAR (WAVY O LINEARE CLASSICA IN BASE AI SETTINGS) ---
                  StreamBuilder<PlaybackState>(
                    stream: widget.audioHandler.playbackState,
                    builder: (context, stateSnapshot) {
                      final isPlaying = stateSnapshot.data?.playing ?? false;

                      return StreamBuilder<Duration>(
                        stream: widget.audioHandler.player.positionStream,
                        builder: (context, posSnapshot) {
                          final position = posSnapshot.data ?? Duration.zero;
                          final duration = widget.audioHandler.player.duration ?? Duration.zero;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: isWavy
                                    ? WavySeekBar(
                                        position: position,
                                        duration: duration,
                                        isPlaying: isPlaying,
                                        accentColor: accentColor,
                                        onSeek: (pos) => widget.audioHandler.seek(pos),
                                      )
                                    : SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: accentColor,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                          overlayColor: accentColor.withAlpha(50),
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                          trackHeight: 4,
                                        ),
                                        child: Slider(
                                          value: duration.inMilliseconds > 0
                                              ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble()
                                              : 0.0,
                                          max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                          onChanged: (val) {
                                            widget.audioHandler.seek(Duration(milliseconds: val.toInt()));
                                          },
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  // --- CONTROLLI DI RIPRODUZIONE (LOOP, PREV, PLAY/PAUSE, NEXT, SHUFFLE) ---
                  StreamBuilder<PlaybackState>(
                    stream: widget.audioHandler.playbackState,
                    builder: (context, stateSnapshot) {
                      final playbackState = stateSnapshot.data;
                      final isPlaying = playbackState?.playing ?? false;
                      final repeatMode = playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
                      final isShuffle = widget.audioHandler.isShuffleActive;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tasto Shuffle
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: isShuffle ? accentColor : Colors.white38,
                              size: 26,
                            ),
                            tooltip: 'Riproduzione casuale senza ripetizioni',
                            onPressed: () => widget.audioHandler.toggleShuffleMode(),
                          ),
                          // Salto indietro configurabile
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 26),
                            tooltip: 'Indietro di $seekStep sec',
                            onPressed: () => widget.audioHandler.seekRelative(-seekStep),
                          ),
                          // Prev
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                            onPressed: () => widget.audioHandler.skipToPrevious(),
                          ),
                          // Play / Pause
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withAlpha(80),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 36,
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
                          // Next
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                            onPressed: () => widget.audioHandler.skipToNext(),
                          ),
                          // Salto avanti configurabile
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 26),
                            tooltip: 'Avanti di $seekStep sec',
                            onPressed: () => widget.audioHandler.seekRelative(seekStep),
                          ),
                          // Loop Mode
                          IconButton(
                            icon: Icon(
                              repeatMode == AudioServiceRepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: repeatMode != AudioServiceRepeatMode.none
                                  ? accentColor
                                  : Colors.white38,
                              size: 26,
                            ),
                            tooltip: 'Modalità ripetizione',
                            onPressed: () => widget.audioHandler.toggleLoopMode(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
