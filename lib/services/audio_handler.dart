// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.antigravity.musicplayer.channel.audio',
      androidNotificationChannelName: 'Riproduzione Musicale',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationClickStartsActivity: true,
    ),
  );
}

class MusicAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  List<SongModel> _currentSongList = [];
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;

  // --- STREAM ERRORI VISIBILI A SCHERMO ---
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  // Completer per assicurarsi che AudioSession sia pronta prima di suonare
  final Completer<void> _audioSessionReady = Completer<void>();

  AudioPlayer get player => _player;
  List<SongModel> get currentSongList => _currentSongList;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

  MusicAudioHandler() {
    _initStreams();
    _initAudioSession();
  }

  void _emitError(String message) {
    debugPrint('AUDIO_ERROR: $message');
    _errorController.add(message);
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        pause();
      });

      _audioSessionReady.complete();
      debugPrint('AudioSession configurata OK');
    } catch (e) {
      _emitError('Errore config AudioSession: $e');
      // Completa comunque per non bloccare la riproduzione
      if (!_audioSessionReady.isCompleted) {
        _audioSessionReady.complete();
      }
    }
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  void _initStreams() {
    // 1. Ascolta lo stato di riproduzione E gli errori del player ExoPlayer
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        _broadcastState();
      },
      onError: (Object e, StackTrace st) {
        // Errori dal livello nativo ExoPlayer (file corrotto, codec non supportato, ecc.)
        if (e is PlayerException) {
          _emitError('Errore player: ${e.message ?? "sconosciuto"} (codice: ${e.code})');
        } else if (e is PlayerInterruptedException) {
          _emitError('Riproduzione interrotta: ${e.message}');
        } else {
          _emitError('Errore audio nativo: $e');
        }
      },
    );

    // 2. Ascolta la posizione per sincronizzare la seekbar nella tendina notifiche / lockscreen
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 3. Ascolta il cambio traccia mantenendo la durata
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        final item = queue.value[index];
        mediaItem.add(item.copyWith(duration: _player.duration));
        _broadcastState();
      }
    });

    // 4. Aggiorna istantaneamente la durata del brano appena caricato
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
        _broadcastState();
      }
    });

    // 5. Monitora lo stato del player per rilevare blocchi e completamenti
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _broadcastState();
      }
    });
  }

  // --- SLEEP TIMER ---
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      _sleepTimerEndTime = null;
      return;
    }
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      pause();
      _sleepTimerEndTime = null;
    });
  }

  // Avvia una lista di brani partendo da un indice
  Future<void> playSongList(List<SongModel> songs, int initialIndex) async {
    if (songs.isEmpty) return;

    // Aspetta che AudioSession sia configurata prima di tentare qualsiasi cosa
    await _audioSessionReady.future;

    final targetIndex = initialIndex.clamp(0, songs.length - 1);
    final targetSong = songs[targetIndex];

    // Verifica che il file esista fisicamente
    final file = File(targetSong.path);
    if (!await file.exists()) {
      _emitError('File non trovato: ${targetSong.title}\n${targetSong.path}');
      return;
    }

    // Se la lista è già quella in coda, fa seek rapido senza ricostruire la sorgente
    final bool isSameList = _currentSongList.length == songs.length &&
        _currentSongList.isNotEmpty &&
        _currentSongList.first.path == songs.first.path &&
        _currentSongList.last.path == songs.last.path;

    if (isSameList && _player.audioSource != null) {
      try {
        await _player.seek(Duration.zero, index: targetIndex);
        await _player.play();
        return;
      } catch (e) {
        _emitError('Seek rapido fallito per "${targetSong.title}": $e\nRicarico la sorgente...');
      }
    }

    _currentSongList = List.from(songs);

    final mediaItems = songs.map((s) {
      return MediaItem(
        id: s.path,
        album: s.album,
        title: s.title,
        artist: s.artist,
        duration: null,
      );
    }).toList();

    // Aggiorna la coda
    queue.add(mediaItems);

    final audioSources = songs.map((s) {
      return AudioSource.uri(
        Uri.file(s.path),
        tag: MediaItem(
          id: s.path,
          album: s.album,
          title: s.title,
          artist: s.artist,
        ),
      );
    }).toList();

    _playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: audioSources,
    );

    try {
      // Stop pulito prima di caricare nuova sorgente per evitare race conditions
      await _player.stop();
      await _player.setAudioSource(
        _playlist,
        initialIndex: targetIndex,
      );
      await _player.play();
    } on PlayerException catch (e) {
      _emitError('Errore riproduzione "${targetSong.title}": ${e.message ?? e.code}');
    } on PlayerInterruptedException catch (e) {
      _emitError('Riproduzione interrotta per "${targetSong.title}": ${e.message}');
    } catch (e, stack) {
      _emitError('Errore imprevisto per "${targetSong.title}": $e');
      debugPrint('Stack trace: $stack');
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      _emitError('Errore play(): $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      _emitError('Errore pause(): $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await super.stop();
    } catch (e) {
      _emitError('Errore stop(): $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      _emitError('Errore seek(): $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      } else if (_player.loopMode == LoopMode.all && queue.value.isNotEmpty) {
        await _player.seek(Duration.zero, index: 0);
      }
    } catch (e) {
      _emitError('Errore skip successivo: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      // Se siamo oltre i 3 secondi, riavvia la traccia (comportamento standard)
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      } else if (_player.loopMode == LoopMode.all && queue.value.isNotEmpty) {
        await _player.seek(Duration.zero, index: queue.value.length - 1);
      } else {
        await _player.seek(Duration.zero);
      }
    } catch (e) {
      _emitError('Errore skip precedente: $e');
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index >= 0 && index < queue.value.length) {
        await _player.seek(Duration.zero, index: index);
        await _player.play();
      }
    } catch (e) {
      _emitError('Errore salto a traccia #$index: $e');
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.value.length) return;

    try {
      await _playlist.removeAt(index);
    } catch (e) {
      _emitError('Errore rimozione dalla coda: $e');
    }

    if (index < _currentSongList.length) {
      _currentSongList.removeAt(index);
    }

    final updatedQueue = List<MediaItem>.from(queue.value);
    updatedQueue.removeAt(index);
    queue.add(updatedQueue);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.value.length) return;
    if (newIndex < 0 || newIndex > queue.value.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    try {
      await _playlist.move(oldIndex, newIndex);
    } catch (e) {
      _emitError('Errore riordinamento coda: $e');
    }

    if (oldIndex < _currentSongList.length && newIndex < _currentSongList.length) {
      final song = _currentSongList.removeAt(oldIndex);
      _currentSongList.insert(newIndex, song);
    }

    final updatedQueue = List<MediaItem>.from(queue.value);
    final item = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, item);
    queue.add(updatedQueue);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  Future<void> toggleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case LoopMode.all:
        await setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case LoopMode.one:
        await setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
  }

  Future<void> toggleShuffleMode() async {
    final isEnabled = _player.shuffleModeEnabled;
    await setShuffleMode(
      isEnabled ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
  }
}
