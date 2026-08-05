import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/app_enums.dart';
import '../models/video_item.dart';
import '../services/media_notification_service.dart';
import 'library_provider.dart';
import 'settings_provider.dart';

/// A subtitle or audio track choice surfaced in the player UI.
class MediaTrackOption {
  const MediaTrackOption({
    required this.id,
    required this.label,
    required this.selected,
  });

  final String id;
  final String label;
  final bool selected;
}

/// Owns the media_kit [Player] and the full playback session: queue, speed,
/// volume, aspect/mirror, A–B repeat, sleep timer, PiP and track selection.
/// Lives for the whole app session so playback survives navigation
/// (background playback + picture-in-picture).
class PlayerProvider extends ChangeNotifier {
  PlayerProvider({
    required SettingsProvider settings,
    required LibraryProvider library,
  })  : _settings = settings,
        _library = library {
    _attachNotificationHandlers();
  }

  // --- Lockscreen / notification media controls -------------------------------
  final MediaNotificationService _notification =
      MediaNotificationService.instance;
  Duration _lastNotificationSync = Duration.zero;
  bool _lastNotificationPlaying = false;

  void _attachNotificationHandlers() {
    _notification.onAction = (action) {
      switch (action) {
        case 'playPause':
          playOrPause();
        case 'next':
          playNext();
        case 'previous':
          playPrevious();
        case 'rewind':
          seekRelative(Duration(seconds: -10));
        case 'forward':
          seekRelative(Duration(seconds: 10));
        case 'stop':
          stop();
      }
    };
    _notification.onSeek = (ms) => seek(Duration(milliseconds: ms));
  }

  /// Pushes the current session to the lockscreen / notification shade.
  /// [force] bypasses the 3-second throttle used for position updates.
  void _syncNotification({bool force = false}) {
    final cur = _current;
    if (!_active || cur == null) return;

    if (!force) {
      final movedEnough =
          (position - _lastNotificationSync).abs() >= Duration(seconds: 3);
      final stateChanged = playing != _lastNotificationPlaying;
      if (!movedEnough && !stateChanged) return;
    }

    _lastNotificationSync = position;
    _lastNotificationPlaying = playing;

    _notification.show(
      title: cur.name,
      subtitle: queueLabel ?? 'Luvio Player',
      playing: playing,
      position: position,
      duration: duration,
      hasNext: hasNext,
      hasPrevious: hasPrevious,
    );
  }

  // --- Network streams --------------------------------------------------------

  /// True when the current item is a URL rather than an on-device file.
  bool isNetworkStream = false;

  static const List<String> streamSchemes = <String>[
    'http://',
    'https://',
    'rtsp://',
    'rtmp://',
    'rtmps://',
    'smb://',
    'ftp://',
    'ftps://',
    'mms://',
    'udp://',
    'srt://',
  ];

  static bool isStreamUrl(String value) {
    final v = value.trim().toLowerCase();
    for (final scheme in streamSchemes) {
      if (v.startsWith(scheme)) return true;
    }
    return false;
  }

  /// Plays a network URL: HTTP/HTTPS (incl. HLS .m3u8 and DASH .mpd), RTSP,
  /// RTMP, SMB / Windows shares, FTP, UDP and SRT.
  Future<void> openNetworkStream(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return;
    await open(
      VideoItem(path: clean, sizeBytes: 0, modified: DateTime.now()),
    );
  }

  // --- A/V sync (audio delay) --------------------------------------------------

  /// Audio delay in seconds. Positive = audio plays later than video.
  double audioDelay = 0.0;

  Future<void> setAudioDelay(double seconds) async {
    final clamped = seconds.clamp(-10.0, 10.0).toDouble();
    audioDelay = double.parse(clamped.toStringAsFixed(2));
    final dynamic platform = _player?.platform;
    if (platform != null) {
      try {
        await platform.setProperty('audio-delay', audioDelay.toString());
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> nudgeAudioDelay(double deltaSeconds) =>
      setAudioDelay(audioDelay + deltaSeconds);

  Future<void> resetAudioDelay() => setAudioDelay(0);

  // --- Night mode / video brightness boost --------------------------------------

  /// Extra video brightness applied by the decoder (-100..100), which can go
  /// far past the screen's own maximum backlight.
  double videoBrightness = 0;
  double videoContrast = 0;
  double videoSaturation = 0;
  bool nightMode = false;

  Future<void> _applyVideoFilters() async {
    final dynamic platform = _player?.platform;
    if (platform == null) return;
    try {
      await platform.setProperty('brightness', videoBrightness.round().toString());
      await platform.setProperty('contrast', videoContrast.round().toString());
      await platform.setProperty('saturation', videoSaturation.round().toString());
    } catch (_) {}
  }

  Future<void> setVideoBrightness(double value) async {
    videoBrightness = value.clamp(-100, 100).toDouble();
    await _applyVideoFilters();
    notifyListeners();
  }

  Future<void> setVideoContrast(double value) async {
    videoContrast = value.clamp(-100, 100).toDouble();
    await _applyVideoFilters();
    notifyListeners();
  }

  Future<void> setVideoSaturation(double value) async {
    videoSaturation = value.clamp(-100, 100).toDouble();
    await _applyVideoFilters();
    notifyListeners();
  }

  /// Night mode lifts dark scenes and softens colour so late-night viewing in
  /// a dark room is comfortable.
  Future<void> toggleNightMode() async {
    nightMode = !nightMode;
    if (nightMode) {
      videoBrightness = 18;
      videoContrast = -8;
      videoSaturation = -12;
    } else {
      videoBrightness = 0;
      videoContrast = 0;
      videoSaturation = 0;
    }
    await _applyVideoFilters();
    notifyListeners();
  }

  Future<void> resetVideoFilters() async {
    nightMode = false;
    videoBrightness = 0;
    videoContrast = 0;
    videoSaturation = 0;
    await _applyVideoFilters();
    notifyListeners();
  }

  // --- Chapters ------------------------------------------------------------------

  List<String> chapterTitles = <String>[];
  List<Duration> chapterTimes = <Duration>[];

  bool get hasChapters => chapterTitles.isNotEmpty;

  /// Reads the chapter list embedded in MKV / MP4 containers.
  Future<void> loadChapters() async {
    chapterTitles = <String>[];
    chapterTimes = <Duration>[];
    final dynamic platform = _player?.platform;
    if (platform != null) {
      try {
        final rawCount = await platform.getProperty('chapter-list/count');
        final count = int.tryParse('${rawCount ?? ''}') ?? 0;
        for (var i = 0; i < count && i < 500; i++) {
          final rawTitle = await platform.getProperty('chapter-list/$i/title');
          final rawTime = await platform.getProperty('chapter-list/$i/time');
          final seconds = double.tryParse('${rawTime ?? ''}') ?? 0;
          final title = '${rawTitle ?? ''}'.trim();
          chapterTitles.add(title.isEmpty ? 'Chapter ${i + 1}' : title);
          chapterTimes.add(Duration(milliseconds: (seconds * 1000).round()));
        }
      } catch (_) {
        chapterTitles = <String>[];
        chapterTimes = <Duration>[];
      }
    }
    notifyListeners();
  }

  int get currentChapterIndex {
    var index = -1;
    for (var i = 0; i < chapterTimes.length; i++) {
      if (chapterTimes[i] <= position) index = i;
    }
    return index;
  }

  Future<void> jumpToChapter(int index) async {
    if (index < 0 || index >= chapterTimes.length) return;
    await seek(chapterTimes[index]);
  }

  Future<void> nextChapter() => jumpToChapter(currentChapterIndex + 1);

  Future<void> previousChapter() async {
    final current = currentChapterIndex;
    if (current < 0) return;
    // Restart the current chapter unless we are near its start.
    final startedAt = chapterTimes[current];
    if (position - startedAt > Duration(seconds: 3)) {
      await jumpToChapter(current);
    } else {
      await jumpToChapter(current - 1);
    }
  }

  final SettingsProvider _settings;
  final LibraryProvider _library;

  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Video controller for the active session (null when idle).
  VideoController? get controller => _controller;

  VideoItem? _current;
  VideoItem? get current => _current;

  List<VideoItem> _queue = <VideoItem>[];
  List<VideoItem> get queue => List.unmodifiable(_queue);

  bool _active = false;
  bool get isActive => _active && _controller != null && _current != null;

  String? lastError;

  /// True while the engine is stalled filling its buffer.
  bool buffering = false;

  // --- Live playback state ----------------------------------------------------
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  double volume = 100;

  int? _videoWidth;
  int? _videoHeight;
  Duration _lastPersisted = Duration.zero;

  double get progressFraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0)
          .toDouble();

  // --- Display ------------------------------------------------------------------
  AspectMode aspectMode = AspectMode.fit;
  bool mirrored = false;

  // --- A–B repeat ---------------------------------------------------------------
  Duration? abPointA;
  Duration? abPointB;
  bool get abRepeatActive => abPointA != null && abPointB != null;

  // --- Picture-in-picture ---------------------------------------------------------
  bool pipActive = false;

  // --- Sleep timer ----------------------------------------------------------------
  Duration? sleepTotal;
  Duration? sleepRemaining;
  bool sleepStopAfterCurrent = false;
  Timer? _sleepTicker;
  bool _sleepArmed = false;
  bool get sleepTimerActive => sleepRemaining != null;

  // --- Background playback ----------------------------------------------------------
  bool backgroundPlaybackActive = false;

  // --- Tracks -------------------------------------------------------------------------
  Tracks? _tracks;
  Track? _selection;

  bool get subtitleEnabled {
    final selected = _selection?.subtitle;
    if (selected == null) return false;
    return selected.id != 'no' && selected.id != 'auto';
  }

  List<MediaTrackOption> get subtitleTracks {
    final tracks = _tracks;
    if (tracks == null) return [];
    final selectedId = _selection?.subtitle.id;
    final options = <MediaTrackOption>[];
    var index = 0;
    for (final track in tracks.subtitle) {
      if (track.id == 'auto' || track.id == 'no') continue;
      index++;
      options.add(MediaTrackOption(
        id: track.id,
        label: _trackLabel(track.title, track.language, 'Subtitle track $index'),
        selected: track.id == selectedId,
      ));
    }
    return options;
  }

  List<MediaTrackOption> get audioTracks {
    final tracks = _tracks;
    if (tracks == null) return [];
    final selectedId = _selection?.audio.id;
    final options = <MediaTrackOption>[];
    var index = 0;
    for (final track in tracks.audio) {
      if (track.id == 'auto' || track.id == 'no') continue;
      index++;
      options.add(MediaTrackOption(
        id: track.id,
        label: _trackLabel(track.title, track.language, 'Audio track $index'),
        selected: track.id == selectedId,
      ));
    }
    return options;
  }

  String _trackLabel(String? title, String? language, String fallback) {
    final hasTitle = title != null && title.trim().isNotEmpty;
    final hasLanguage = language != null && language.trim().isNotEmpty;
    if (hasTitle && hasLanguage) return '$title ($language)';
    if (hasTitle) return title;
    if (hasLanguage) return language.toUpperCase();
    return fallback;
  }

  Future<void> selectSubtitleTrack(String id) async {
    final tracks = _tracks;
    final player = _player;
    if (tracks == null || player == null) return;
    for (final track in tracks.subtitle) {
      if (track.id == id) {
        await player.setSubtitleTrack(track);
        notifyListeners();
        return;
      }
    }
  }

  Future<void> disableSubtitles() async {
    await _player?.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  /// Sideloads an external subtitle file (.srt/.ass/.ssa/.vtt/.sub).
  Future<void> loadExternalSubtitle(String path) async {
    final player = _player;
    if (player == null) return;
    await player.setSubtitleTrack(SubtitleTrack.uri(path));
    notifyListeners();
  }

  Future<void> selectAudioTrack(String id) async {
    final tracks = _tracks;
    final player = _player;
    if (tracks == null || player == null) return;
    for (final track in tracks.audio) {
      if (track.id == id) {
        await player.setAudioTrack(track);
        notifyListeners();
        return;
      }
    }
  }

  // --- Queue -----------------------------------------------------------------------

  int get _queueIndex {
    final cur = _current;
    if (cur == null) return -1;
    return _queue.indexWhere((v) => v.path == cur.path);
  }

  bool get hasPrevious => _queueIndex > 0;
  bool get hasNext => _queueIndex >= 0 && _queueIndex < _queue.length - 1;

  /// '2 of 8' when playing from a multi-item queue, otherwise null.
  String? get queueLabel {
    final index = _queueIndex;
    if (_queue.length < 2 || index < 0) return null;
    return '${index + 1} of ${_queue.length}';
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    await open(_queue[_queueIndex + 1], queue: _queue);
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await open(_queue[_queueIndex - 1], queue: _queue);
  }

  // --- Session ---------------------------------------------------------------------

  /// Opens [video] (optionally within [queue]). Re-opening the video that is
  /// already playing only refreshes the queue — it never restarts playback.
  Future<void> open(VideoItem video, {List<VideoItem>? queue}) async {
    _queue = (queue == null || queue.isEmpty)
        ? <VideoItem>[video]
        : List.of(queue);

    if (isActive && _current?.path == video.path) {
      notifyListeners();
      return;
    }

    _persistPosition();

    final player = await _ensurePlayer();
    _current = video;
    _active = true;
    isNetworkStream = isStreamUrl(video.path);
    chapterTitles = <String>[];
    chapterTimes = <Duration>[];
    audioDelay = 0;
    lastError = null;
    abPointA = null;
    abPointB = null;
    position = video.position;
    duration = video.duration;
    _videoWidth = null;
    _videoHeight = null;
    _lastPersisted = Duration.zero;
    notifyListeners();

    try {
      await player.open(Media(video.path), play: true);
      final resume = _settings.autoResume &&
          video.positionMs > 5000 &&
          video.progress < 0.97;
      if (resume) {
        await player.seek(video.position);
      }
      if ((_settings.defaultSpeed - speed).abs() > 0.001) {
        await player.setRate(_settings.defaultSpeed);
        speed = _settings.defaultSpeed;
      }
      await _applyVideoFilters();
      await loadChapters();
    } catch (_) {
      lastError = 'Could not open ${video.name}';
      _active = false;
    }
    _syncNotification(force: true);
    notifyListeners();
  }

  Future<Player> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player(
      configuration: PlayerConfiguration(title: 'Luvio Player'),
    );
    _player = player;
    _controller = VideoController(player);

    await applyDecoderMode();
    await applyEqualizer(_settings);
    await player.setVolume(volume);

    _subs.addAll([
      player.stream.playing.listen((value) {
        playing = value;
        if (!value) _persistPosition();
        _syncNotification(force: true);
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
      player.stream.width.listen((value) => _videoWidth = value),
      player.stream.height.listen((value) => _videoHeight = value),
      player.stream.tracks.listen((value) {
        _tracks = value;
        notifyListeners();
      }),
      player.stream.track.listen((value) {
        _selection = value;
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

    // A–B repeat loop.
    final a = abPointA;
    final b = abPointB;
    if (a != null && b != null && b > a && value >= b) {
      _player?.seek(a);
    }

    // Throttled resume-state persistence.
    final cur = _current;
    if (cur != null &&
        !isNetworkStream &&
        duration > Duration.zero &&
        (value - _lastPersisted).abs() > Duration(seconds: 5)) {
      _lastPersisted = value;
      _library.updatePlaybackState(
        cur.path,
        position: value,
        duration: duration,
        width: _videoWidth,
        height: _videoHeight,
      );
    }
    _syncNotification();
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
    if (hasNext) {
      playNext();
    } else {
      playing = false;
      notifyListeners();
    }
  }

  void _persistPosition({bool completed = false}) {
    final cur = _current;
    if (cur == null) return;
    _library.updatePlaybackState(
      cur.path,
      position: completed ? Duration.zero : position,
      duration: duration > Duration.zero ? duration : null,
      width: _videoWidth,
      height: _videoHeight,
    );
  }

  // --- Transport ----------------------------------------------------------------

  Future<void> playOrPause() async {
    await _player?.playOrPause();
  }

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

  Future<void> stop() async {
    _persistPosition();
    _active = false;
    pipActive = false;
    playing = false;
    backgroundPlaybackActive = false;
    _current = null;
    _queue = <VideoItem>[];
    abPointA = null;
    abPointB = null;
    _lastNotificationSync = Duration.zero;
    _lastNotificationPlaying = false;
    _notification.hide();
    notifyListeners();
    await _player?.stop();
  }

  // --- Display --------------------------------------------------------------------

  void cycleAspectMode() {
    final cycle = [AspectMode.fit, AspectMode.crop, AspectMode.stretch];
    final index = cycle.indexOf(aspectMode);
    aspectMode = cycle[(index + 1) % cycle.length];
    notifyListeners();
  }

  void toggleMirror() {
    mirrored = !mirrored;
    notifyListeners();
  }

  // --- Part 3 advanced: frame step, capture, stats ------------------------------
  int? get videoWidth => _videoWidth;
  int? get videoHeight => _videoHeight;
  String get resolutionLabel =>
      (_videoWidth != null && _videoHeight != null)
          ? '${_videoWidth}x${_videoHeight}'
          : '—';

  /// Captures the current frame as PNG bytes (null if unsupported).
  Future<Uint8List?> captureFrame() async {
    final player = _player;
    if (player == null) return null;
    try {
      return await player.screenshot(format: 'image/png');
    } catch (_) {
      return null;
    }
  }

  /// Steps a single frame forward/back (pauses first for precise stepping).
  Future<void> stepFrame({bool forward = true}) async {
    final player = _player;
    if (player == null) return;
    if (playing) await player.pause();
    const frame = Duration(milliseconds: 42);
    await seek(forward ? position + frame : position - frame);
  }

  // --- A–B repeat ------------------------------------------------------------------

  void setAbPointA() {
    abPointA = position;
    final b = abPointB;
    if (b != null && b <= position) abPointB = null;
    notifyListeners();
  }

  void setAbPointB() {
    final a = abPointA;
    if (a != null && position <= a) return;
    abPointB = position;
    notifyListeners();
  }

  void clearAbRepeat() {
    abPointA = null;
    abPointB = null;
    notifyListeners();
  }

  // --- Picture-in-picture -------------------------------------------------------------

  void enterPip() {
    if (!isActive) return;
    pipActive = true;
    notifyListeners();
  }

  void exitPip() {
    pipActive = false;
    notifyListeners();
  }

  void closePip() {
    pipActive = false;
    stop();
  }

  // --- Sleep timer -----------------------------------------------------------------------

  void startSleepTimer(Duration length, {bool stopAfterCurrent = false}) {
    _sleepTicker?.cancel();
    sleepTotal = length;
    sleepRemaining = length;
    sleepStopAfterCurrent = stopAfterCurrent;
    _sleepArmed = false;
    _sleepTicker = Timer.periodic(Duration(seconds: 1), (_) {
      final remaining = sleepRemaining;
      if (remaining == null) return;
      final next = remaining - Duration(seconds: 1);
      if (next > Duration.zero) {
        sleepRemaining = next;
        notifyListeners();
        return;
      }
      _sleepTicker?.cancel();
      _sleepTicker = null;
      if (sleepStopAfterCurrent && playing) {
        // Let the current video finish, then stop.
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

  // --- Engine configuration -------------------------------------------------------------

  /// Applies the decoder preference (HW / HW+ / SW) to the mpv backend.
  Future<void> applyDecoderMode([DecoderMode? mode]) async {
    final selected = mode ?? _settings.decoderMode;
    final dynamic platform = _player?.platform;
    if (platform == null) return;
    try {
      await platform.setProperty(
        'hwdec',
        switch (selected) {
          DecoderMode.hardware => 'mediacodec-copy',
          DecoderMode.hardwarePlus => 'auto-safe',
          DecoderMode.software => 'no',
        },
      );
    } catch (_) {
      // Property unsupported on this backend — mpv falls back safely.
    }
  }

  /// Rebuilds the mpv audio filter chain from the equalizer settings.
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
        if (i < 3) gain += settings.eqBassBoost * 6; // bass boost lifts lows
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

  /// Keeps the session alive when the app is backgrounded.
  Future<void> enableBackgroundPlayback() async {
    backgroundPlaybackActive = true;
    notifyListeners();
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
