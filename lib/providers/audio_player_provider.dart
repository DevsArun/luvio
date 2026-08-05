import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;

import '../models/app_enums.dart';
import '../models/audio_track.dart';
import 'audio_library_provider.dart';
import 'settings_provider.dart';

/// Owns the audio-only media_kit [Player] and the full listening session:
/// queue, shuffle, repeat modes, speed, sleep timer and equalizer.
class AudioPlayerProvider extends ChangeNotifier {
  AudioPlayerProvider({
    required SettingsProvider settings,
    required AudioLibraryProvider library,
  })  : _settings = settings,
        _library = library;

  final SettingsProvider _settings;
  final AudioLibraryProvider _library;

  Player? _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  AudioTrack? _current;
  AudioTrack? get current => _current;

  List<AudioTrack> _queue = <AudioTrack>[];
  List<AudioTrack> get queue => List.unmodifiable(_queue);

  List<int> _order = <int>[];
  int _orderCursor = -1;

  bool _active = false;
  bool get isActive => _active && _current != null;

  String? lastError;
  bool buffering = false;

  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  double volume = 100;

  bool shuffle = false;
  RepeatMode repeatMode = RepeatMode.off;

  Duration _lastPersisted = Duration.zero;

  double get progressFraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0)
          .toDouble();

  Duration? sleepTotal;
  Duration? sleepRemaining;
  bool sleepStopAfterCurrent = false;
  Timer? _sleepTicker;
  bool _sleepArmed = false;
  bool get sleepTimerActive => sleepRemaining != null;

  int get _currentQueueIndex {
    final cur = _current;
    if (cur == null) return -1;
    return _queue.indexWhere((t) => t.path == cur.path);
  }

  bool get hasNext {
    if (_queue.isEmpty) return false;
    if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.one) {
      return true;
    }
    return _orderCursor >= 0 && _orderCursor < _order.length - 1;
  }

  bool get hasPrevious => _queue.isNotEmpty;

  String? get queueLabel {
    final index = _currentQueueIndex;
    if (_queue.length < 2 || index < 0) return null;
    return '${index + 1} of ${_queue.length}';
  }

  Future<void> play(AudioTrack track, {List<AudioTrack>? queue}) async {
    _queue = (queue == null || queue.isEmpty)
        ? <AudioTrack>[track]
        : List.of(queue);
    _rebuildOrder(startPath: track.path);
    await _openCurrent(track);
  }

  void _rebuildOrder({String? startPath}) {
    _order = List<int>.generate(_queue.length, (i) => i);
    if (shuffle) {
      _order.shuffle(Random());
    }
    if (startPath != null) {
      final startIndex = _queue.indexWhere((t) => t.path == startPath);
      if (startIndex >= 0) {
        _order.remove(startIndex);
        _order.insert(0, startIndex);
        _orderCursor = 0;
      }
    } else {
      _orderCursor = _order.isEmpty ? -1 : 0;
    }
  }

  Future<void> _openCurrent(AudioTrack track) async {
    final player = await _ensurePlayer();
    _persistPosition();
    _current = track;
    _active = true;
    lastError = null;
    position = track.position;
    duration = track.duration;
    _lastPersisted = Duration.zero;
    notifyListeners();

    unawaited(_library.resolveMetadata(track).then((_) => notifyListeners()));

    try {
      await player.open(Media(track.path), play: true);
      final resume = _settings.autoResume &&
          track.positionMs > 5000 &&
          (track.durationMs <= 0 ||
              track.positionMs < track.durationMs * 0.97);
      if (resume) await player.seek(track.position);
      if ((_settings.defaultSpeed - speed).abs() > 0.001) {
        await player.setRate(_settings.defaultSpeed);
        speed = _settings.defaultSpeed;
      }
    } catch (_) {
      lastError = 'Could not play ${track.title}';
      _active = false;
    }
    notifyListeners();
  }

  Future<Player> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player(
      configuration: const PlayerConfiguration(title: 'Luvio Player — Audio'),
    );
    _player = player;

    await applyEqualizer(_settings);
    await player.setVolume(volume);

    _subs.addAll([
      player.stream.playing.listen((value) {
        playing = value;
        if (!value) _persistPosition();
        notifyListeners();
      }),
      player.stream.position.listen(_onPosition),
      player.stream.buffering.listen((value) {
        buffering = value;
        notifyListeners();
      }),
      player.stream.duration.listen((value) {
        duration = value;
        notifyListeners();
      }),
      player.stream.rate.listen((value) {
        speed = value;
        notifyListeners();
      }),
      player.stream.volume.listen((value) {
        volume = value;
        notifyListeners();
      }),
      player.stream.completed.listen((done) {
        if (done) _onCompleted();
      }),
      player.stream.error.listen((message) {
        lastError = message;
        notifyListeners();
      }),
    ]);
    return player;
  }

  void _onPosition(Duration value) {
    position = value;
    final cur = _current;
    if (cur != null &&
        duration > Duration.zero &&
        (value - _lastPersisted).abs() > const Duration(seconds: 5)) {
      _lastPersisted = value;
      _library.updatePlaybackState(cur.path,
          position: value, duration: duration);
    }
    notifyListeners();
  }

  void _onCompleted() {
    _persistPosition(completed: true);
    if (_sleepArmed) {
      _sleepArmed = false;
      cancelSleepTimer();
      stop();
      return;
    }
    if (repeatMode == RepeatMode.one) {
      final cur = _current;
      if (cur != null) {
        _openCurrent(cur);
        return;
      }
    }
    playNext(auto: true);
  }

  void _persistPosition({bool completed = false}) {
    final cur = _current;
    if (cur == null) return;
    _library.updatePlaybackState(
      cur.path,
      position: completed ? Duration.zero : position,
      duration: duration > Duration.zero ? duration : null,
    );
  }

  Future<void> playOrPause() async => _player?.playOrPause();

  Future<void> seek(Duration target) async {
    final player = _player;
    if (player == null) return;
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (duration > Duration.zero && clamped > duration) clamped = duration;
    position = clamped;
    notifyListeners();
    await player.seek(clamped);
  }

  Future<void> seekRelative(Duration delta) => seek(position + delta);

  Future<void> playNext({bool auto = false}) async {
    if (_queue.isEmpty) return;
    if (_orderCursor < _order.length - 1) {
      _orderCursor++;
    } else if (repeatMode == RepeatMode.all ||
        (repeatMode == RepeatMode.one && auto)) {
      _orderCursor = 0;
    } else if (!auto && repeatMode == RepeatMode.off) {
      _orderCursor = 0;
    } else {
      playing = false;
      notifyListeners();
      return;
    }
    await _openCurrent(_queue[_order[_orderCursor]]);
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    if (position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_orderCursor > 0) {
      _orderCursor--;
    } else if (repeatMode == RepeatMode.all) {
      _orderCursor = _order.length - 1;
    } else {
      await seek(Duration.zero);
      return;
    }
    await _openCurrent(_queue[_order[_orderCursor]]);
  }

  Future<void> setSpeed(double value) async {
    speed = value;
    notifyListeners();
    await _player?.setRate(value);
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0.0, 100.0).toDouble();
    notifyListeners();
    await _player?.setVolume(volume);
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    final cur = _current;
    _rebuildOrder(startPath: cur?.path);
    notifyListeners();
  }

  void cycleRepeatMode() {
    repeatMode = switch (repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    notifyListeners();
  }

  Future<void> stop() async {
    _persistPosition();
    _active = false;
    playing = false;
    _current = null;
    _queue = <AudioTrack>[];
    _order = <int>[];
    _orderCursor = -1;
    notifyListeners();
    await _player?.stop();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    _rebuildOrder(startPath: _current?.path);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue[index];
    if (_current?.path == removed.path) return;
    _queue.removeAt(index);
    _rebuildOrder(startPath: _current?.path);
    notifyListeners();
  }

  void startSleepTimer(Duration length, {bool stopAfterCurrent = false}) {
    _sleepTicker?.cancel();
    sleepTotal = length;
    sleepRemaining = length;
    sleepStopAfterCurrent = stopAfterCurrent;
    _sleepArmed = false;
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = sleepRemaining;
      if (remaining == null) return;
      final next = remaining - const Duration(seconds: 1);
      if (next > Duration.zero) {
        sleepRemaining = next;
        notifyListeners();
        return;
      }
      _sleepTicker?.cancel();
      _sleepTicker = null;
      if (sleepStopAfterCurrent && playing) {
        sleepRemaining = Duration.zero;
        _sleepArmed = true;
      } else {
        cancelSleepTimer();
        _player?.pause();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    sleepTotal = null;
    sleepRemaining = null;
    sleepStopAfterCurrent = false;
    _sleepArmed = false;
    notifyListeners();
  }

  /// Rebuilds the mpv audio-filter chain from the shared equalizer settings.
  Future<void> applyEqualizer(SettingsProvider settings) async {
    final dynamic platform = _player?.platform;
    if (platform == null) return;
    try {
      if (!settings.eqEnabled) {
        await platform.setProperty('af', '');
        return;
      }
      final freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final entries = <String>[];
      for (var i = 0; i < freqs.length; i++) {
        var gain = i < settings.eqBands.length ? settings.eqBands[i] : 0.0;
        if (i < 3) gain += settings.eqBassBoost * 6;
        entries.add('entry(${freqs[i]},${gain.toStringAsFixed(1)})');
      }
      final masterDb = (settings.eqMasterGain - 0.75) * 24;
      final filters = <String>[
        "lavfi=[firequalizer=gain_entry='${entries.join(';')}']",
        'lavfi=[volume=${masterDb.toStringAsFixed(1)}dB]',
        if (settings.eqVirtualizer > 0.05)
          'lavfi=[extrastereo=m=${(1 + settings.eqVirtualizer).toStringAsFixed(2)}]',
      ];
      await platform.setProperty('af', filters.join(','));
    } catch (_) {
      // Filter chain unsupported — audio continues unprocessed.
    }
  }

  @override
  void dispose() {
    _sleepTicker?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
