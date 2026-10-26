// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  List<SongModel> _originalSongList = [];
  bool _isShuffleActive = false;
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
  bool get isShuffleActive => _isShuffleActive;

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
      shuffleMode: _isShuffleActive ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  void _initStreams() {
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        _broadcastState();
      },
      onError: (Object e, StackTrace st) {
        if (e is PlayerException) {
          _emitError('Errore player: ${e.message ?? "sconosciuto"} (codice: ${e.code})');
        } else if (e is PlayerInterruptedException) {
          _emitError('Riproduzione interrotta: ${e.message}');
        } else {
          _emitError('Errore audio nativo: $e');
        }
      },
    );

    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty && index < queue.value.length) {
        final item = queue.value[index];
        mediaItem.add(item.copyWith(duration: _player.duration));
        _broadcastState();
      }
    });

    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
        _broadcastState();
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _broadcastState();
        if (_player.loopMode == LoopMode.all && _isShuffleActive && _currentSongList.length > 1) {
          // Ricomincia con un nuovo rimescolamento completo senza ripetizioni
          skipToNext();
        }
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

  // Helper interno per ricostruire la sorgente e impostare la coda
  Future<void> _buildAndPlaySources(
    List<SongModel> songs,
    int initialIndex, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    final mediaItems = songs.map((s) {
      return MediaItem(
        id: s.path,
        album: s.album,
        title: s.title,
        artist: s.artist,
        duration: null,
      );
    }).toList();

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
      await _player.stop();
      await _player.setAudioSource(
        _playlist,
        initialIndex: initialIndex.clamp(0, songs.length - 1),
        initialPosition: initialPosition,
      );
      if (autoPlay) {
        await _player.play();
      }
    } on PlayerException catch (e) {
      _emitError('Errore riproduzione: ${e.message ?? e.code}');
    } on PlayerInterruptedException catch (e) {
      _emitError('Riproduzione interrotta: ${e.message}');
    } catch (e, stack) {
      _emitError('Errore imprevisto: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // Avvia una lista di brani normale (lineare)
  Future<void> playSongList(List<SongModel> songs, int initialIndex) async {
    if (songs.isEmpty) return;
    await _audioSessionReady.future;

    _isShuffleActive = false;
    _originalSongList = List.from(songs);
    _currentSongList = List.from(songs);

    final targetIndex = initialIndex.clamp(0, songs.length - 1);
    final targetSong = songs[targetIndex];

    final file = File(targetSong.path);
    if (!await file.exists()) {
      _emitError('File non trovato: ${targetSong.title}\n${targetSong.path}');
      return;
    }

    await _buildAndPlaySources(songs, targetIndex);
  }

  // Avvia una lista in modalità Shuffle: crea un mazzo casuale senza ripetizioni
  Future<void> playShuffled(List<SongModel> songs, {int? startIndex}) async {
    if (songs.isEmpty) return;
    await _audioSessionReady.future;

    _originalSongList = List.from(songs);
    _isShuffleActive = true;

    final targetSong = (startIndex != null && startIndex >= 0 && startIndex < songs.length)
        ? songs[startIndex]
        : null;

    final shuffled = List<SongModel>.from(songs);
    shuffled.shuffle();

    if (targetSong != null) {
      shuffled.removeWhere((s) => s.path == targetSong.path);
      shuffled.insert(0, targetSong);
    }

    _currentSongList = shuffled;
    await _buildAndPlaySources(shuffled, 0);
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
        if (_isShuffleActive && _currentSongList.length > 1) {
          // Quando tutti i brani della coda casuale sono passati senza ripetizioni,
          // genera un nuovo mazzo casuale per il ciclo successivo!
          final reshuffled = List<SongModel>.from(_currentSongList);
          reshuffled.shuffle();
          _currentSongList = reshuffled;
          await _buildAndPlaySources(reshuffled, 0);
        } else {
          await _player.seek(Duration.zero, index: 0);
        }
      }
    } catch (e) {
      _emitError('Errore skip successivo: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
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
    final wantShuffle = shuffleMode != AudioServiceShuffleMode.none;
    if (wantShuffle != _isShuffleActive) {
      await toggleShuffleMode();
    }
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
    if (_currentSongList.isEmpty) return;

    if (!_isShuffleActive) {
      // ATTIVAZIONE SHUFFLE
      _isShuffleActive = true;
      if (_originalSongList.isEmpty) {
        _originalSongList = List.from(_currentSongList);
      }

      final currentIndex = _player.currentIndex ?? 0;
      final currentSong = (currentIndex >= 0 && currentIndex < _currentSongList.length)
          ? _currentSongList[currentIndex]
          : _currentSongList.first;

      // Crea un mazzo casuale con i restanti brani (nessuna ripetizione)
      final remaining = _currentSongList.where((s) => s.path != currentSong.path).toList();
      remaining.shuffle();

      final newQueue = [currentSong, ...remaining];
      final currentPos = _player.position;
      final wasPlaying = _player.playing;

      _currentSongList = newQueue;
      await _buildAndPlaySources(newQueue, 0, initialPosition: currentPos, autoPlay: wasPlaying);
    } else {
      // DISATTIVAZIONE SHUFFLE: ripristina la coda originaria
      _isShuffleActive = false;
      final currentIndex = _player.currentIndex ?? 0;
      final currentSong = (currentIndex >= 0 && currentIndex < _currentSongList.length)
          ? _currentSongList[currentIndex]
          : null;

      final restoredList = _originalSongList.isNotEmpty
          ? List<SongModel>.from(_originalSongList)
          : List<SongModel>.from(_currentSongList);

      int restoredIndex = 0;
      if (currentSong != null) {
        restoredIndex = restoredList.indexWhere((s) => s.path == currentSong.path);
        if (restoredIndex < 0) restoredIndex = 0;
      }

      final currentPos = _player.position;
      final wasPlaying = _player.playing;

      _currentSongList = restoredList;
      await _buildAndPlaySources(restoredList, restoredIndex, initialPosition: currentPos, autoPlay: wasPlaying);
    }
    _broadcastState();
  }

  // --- EQUALIZZATORE DI SISTEMA ---
  static const MethodChannel _systemChannel =
      MethodChannel('com.antigravity.localsongs/system_equalizer');

  Future<bool> openSystemEqualizer() async {
    try {
      final sessionId = _player.androidAudioSessionId ?? 0;
      final result = await _systemChannel.invokeMethod<bool>(
        'openEqualizer',
        {'sessionId': sessionId},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Errore apertura equalizzatore: $e');
      return false;
    }
  }

  // --- VELOCITÀ DI RIPRODUZIONE ---
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      _broadcastState();
    } catch (e) {
      _emitError('Errore impostazione velocità: $e');
    }
  }

  // --- SALTO AVANTI / INDIETRO CONFIGURABILE ---
  Future<void> seekRelative(int seconds) async {
    try {
      final current = _player.position;
      final total = _player.duration ?? Duration.zero;
      final target = current + Duration(seconds: seconds);
      if (target < Duration.zero) {
        await seek(Duration.zero);
      } else if (total > Duration.zero && target > total) {
        await skipToNext();
      } else {
        await seek(target);
      }
    } catch (e) {
      _emitError('Errore seek: $e');
    }
  }

  @override
  Future<void> fastForward() async => seekRelative(10);

  @override
  Future<void> rewind() async => seekRelative(-10);
}
