import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_handler.dart';
import '../../services/storage_service.dart';
import '../widgets/artwork_widget.dart';
import '../widgets/animated_equalizer.dart';
import '../widgets/wavy_seek_bar.dart';

class NowPlayingScreen extends StatefulWidget {
  final MusicAudioHandler audioHandler;
  final StorageService storageService;

  const NowPlayingScreen({
    super.key,
    required this.audioHandler,
    required this.storageService,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
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
              // SLEEP TIMER
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Color(0xFF1DB954)),
                title: const Text('Timer di spegnimento', style: TextStyle(color: Colors.white)),
                subtitle: widget.audioHandler.sleepTimerEndTime != null
                    ? Text(
                        'Attivo (spegnimento tra ~${widget.audioHandler.sleepTimerEndTime!.difference(DateTime.now()).inMinutes + 1} min)',
                        style: const TextStyle(color: Color(0xFF1DB954), fontSize: 12),
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
                          child: const Text('OK', style: TextStyle(color: Color(0xFF1DB954))),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
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
      trailing: const Icon(Icons.alarm_on_rounded, color: Colors.white38),
      onTap: () {
        widget.audioHandler.setSleepTimer(duration);
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
          SnackBar(content: Text('Timer impostato per $label')),
        );
      },
    );
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (dCtx, scrollController) {
            return StreamBuilder<PlaybackState>(
              stream: widget.audioHandler.playbackState,
              builder: (context, playSnapshot) {
                final isPlayingAudio = playSnapshot.data?.playing ?? false;
                return StreamBuilder<List<MediaItem>>(
                  stream: widget.audioHandler.queue,
                  builder: (context, queueSnapshot) {
                    final queue = queueSnapshot.data ?? widget.audioHandler.queue.value;
                    final currentId = widget.audioHandler.mediaItem.value?.id;

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
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

                              return ListTile(
                                key: ValueKey('queue_item_${item.id}_$i'),
                                leading: ArtworkWidget(
                                  title: item.title,
                                  artist: item.artist ?? '',
                                  size: 40,
                                  borderRadius: 6,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                        // Swipe verso sinistra -> Brano successivo
                        widget.audioHandler.skipToNext();
                      } else if (_dragDistance > 45 || v > 200) {
                        // Swipe verso destra -> Brano precedente
                        widget.audioHandler.skipToPrevious();
                      }
                      _dragDistance = 0;
                    },
                    child: Hero(
                      tag: 'current_artwork',
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ArtworkWidget(
                          title: mediaItem?.title ?? '',
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
                              mediaItem?.title ?? 'Nessun brano in riproduzione',
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
                          color: isFav ? const Color(0xFF1DB954) : Colors.white60,
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

                  // --- WAVY SEEKBAR (ONDULATO IN PLAY, PIATTO IN PAUSA) ---
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
                                child: WavySeekBar(
                                  position: position,
                                  duration: duration,
                                  isPlaying: isPlaying,
                                  onSeek: (pos) => widget.audioHandler.seek(pos),
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
                      final loopMode = widget.audioHandler.player.loopMode;
                      final shuffleEnabled = widget.audioHandler.player.shuffleModeEnabled;

                      IconData loopIcon = Icons.repeat_rounded;
                      Color loopColor = Colors.white38;
                      if (loopMode == LoopMode.all) {
                        loopIcon = Icons.repeat_rounded;
                        loopColor = const Color(0xFF1DB954);
                      } else if (loopMode == LoopMode.one) {
                        loopIcon = Icons.repeat_one_rounded;
                        loopColor = const Color(0xFF1DB954);
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // SHUFFLE TOGGLE
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: shuffleEnabled ? const Color(0xFF1DB954) : Colors.white38,
                              size: 26,
                            ),
                            onPressed: () => widget.audioHandler.toggleShuffleMode(),
                          ),

                          // PREVIOUS
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: () => widget.audioHandler.skipToPrevious(),
                          ),

                          // BIG PLAY / PAUSE BUTTON
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1DB954),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 38,
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

                          // NEXT
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: () => widget.audioHandler.skipToNext(),
                          ),

                          // LOOP TOGGLE
                          IconButton(
                            icon: Icon(
                              loopIcon,
                              color: loopColor,
                              size: 26,
                            ),
                            onPressed: () => widget.audioHandler.toggleLoopMode(),
                          ),
                        ],
                      );
                    },
                  ),

                  // Suggerimento Swipe
                  const Text(
                    'Scorri sulla copertina per cambiare canzone',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
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
