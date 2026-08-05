import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../services/brightness_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_enums.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../dialogs/sleep_timer_dialog.dart';
import '../../models/video_bookmark.dart';
import '../../services/bookmark_service.dart';
import '../../services/capture_service.dart';
import '../../services/subtitle_download_service.dart';
import 'playback_stats_overlay.dart';

/// Fullscreen video player: immersive video surface, glass controls,
/// gesture layer (brightness / volume / seek / double-tap), lock mode,
/// AB repeat, subtitle & audio track selection, PiP hand-off.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.args});

  final PlayerScreenArgs args;

  @override
  State<VideoPlayerScreen> createState() =>
      _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _controlsVisible = true;
  bool _locked = false;
  bool _showStats = false;
  final BookmarkService _bookmarks = BookmarkService();
  final CaptureService _capture = CaptureService();
  Timer? _hideTimer;

  // Gesture state.
  double? _dragStartBrightness;
  double? _dragStartVolume;
  double _brightness = 0.6;
  _HudData? _hud;
  Duration? _seekPreview;
  Duration? _seekStartPosition;
  _SeekRipple? _ripple;
  Timer? _rippleTimer;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky);
    BrightnessService().current().then((value) {
      if (mounted) setState(() => _brightness = value);
    });

    if (widget.args.video != null && !widget.args.fromPip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PlayerProvider>().open(
              widget.args.video!,
              queue: widget.args.queue,
            );
      });
    }
    _poke();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _rippleTimer?.cancel();
    // Give brightness control back to the system slider on exit.
    BrightnessService().reset();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    super.dispose();
  }

  // --- Controls visibility --------------------------------------------------

  void _poke() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(Duration(seconds: 3), () {
      if (mounted && !_locked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleOrientation() {
    final landscape = MediaQuery.of(context).orientation ==
        Orientation.landscape;
    SystemChrome.setPreferredOrientations(landscape
        ? [DeviceOrientation.portraitUp]
        : [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
    _poke();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _poke();
    }
  }

  // --- Gestures --------------------------------------------------------------

  void _onDoubleTapDown(TapDownDetails details) {
    final settings = context.read<SettingsProvider>();
    final player = context.read<PlayerProvider>();
    final width = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (settings.doubleTapGesture && dx < width * 0.35) {
      player.seekRelative(
          Duration(seconds: -settings.doubleTapSeconds));
      _showRipple(details.globalPosition, forward: false,
          seconds: settings.doubleTapSeconds);
    } else if (settings.doubleTapGesture && dx > width * 0.65) {
      player.seekRelative(
          Duration(seconds: settings.doubleTapSeconds));
      _showRipple(details.globalPosition, forward: true,
          seconds: settings.doubleTapSeconds);
    } else {
      player.playOrPause();
      _poke();
    }
  }

  void _showRipple(Offset position,
      {required bool forward, required int seconds}) {
    _rippleTimer?.cancel();
    setState(() => _ripple = _SeekRipple(
        position: position, forward: forward, seconds: seconds));
    _rippleTimer =
        Timer(Duration(milliseconds: 700), () {
      if (mounted) setState(() => _ripple = null);
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_locked) return;
    final width = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < width / 2) {
      _dragStartBrightness = _brightness;
      _dragStartVolume = null;
    } else {
      _dragStartVolume =
          context.read<PlayerProvider>().volume;
      _dragStartBrightness = null;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_locked) return;
    final settings = context.read<SettingsProvider>();
    final height = MediaQuery.of(context).size.height;
    final delta = -details.delta.dy / (height * 0.7);

    if (_dragStartBrightness != null) {
      if (!settings.brightnessGesture) return;
      _brightness = (_brightness + delta).clamp(0.0, 1.0).toDouble();
      // Fire and forget: the native window attribute applies on the next frame.
      BrightnessService().set(_brightness);
      setState(() => _hud = _HudData(
            icon: _brightness < 0.05
                ? Icons.brightness_low
                : (_brightness < 0.6
                    ? Icons.brightness_medium
                    : Icons.brightness_high),
            fraction: _brightness,
          ));
    } else if (_dragStartVolume != null) {
      if (!settings.volumeGesture) return;
      final player = context.read<PlayerProvider>();
      final volume =
          (player.volume + delta * 100).clamp(0.0, 100.0);
      player.setVolume(volume);
      setState(() => _hud = _HudData(
            icon: volume <= 0
                ? Icons.volume_off
                : (volume < 50
                    ? Icons.volume_down
                    : Icons.volume_up),
            fraction: volume / 100,
          ));
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragStartBrightness = null;
    _dragStartVolume = null;
    if (_hud != null) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) setState(() => _hud = null);
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_locked) return;
    if (!context.read<SettingsProvider>().seekGesture) return;
    final player = context.read<PlayerProvider>();
    _seekStartPosition = player.position;
    setState(() => _seekPreview = player.position);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_locked || _seekStartPosition == null) return;
    final player = context.read<PlayerProvider>();
    final width = MediaQuery.of(context).size.width;
    // Full screen width scrubs ~90 seconds.
    final deltaMs = (details.localPosition.dx -
            (details.localPosition.dx - details.delta.dx)) /
        width *
        90000;
    final next = Duration(
      milliseconds: ((_seekPreview ?? _seekStartPosition!)
                  .inMilliseconds +
              deltaMs)
          .round()
          .clamp(0, player.duration.inMilliseconds),
    );
    setState(() => _seekPreview = next);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_seekPreview != null) {
      context.read<PlayerProvider>().seek(_seekPreview!);
    }
    setState(() {
      _seekPreview = null;
      _seekStartPosition = null;
    });
  }

  // --- Menus & sheets ---------------------------------------------------------

  void _cycleSpeed() {
    final player = context.read<PlayerProvider>();
    final index = _speeds.indexWhere(
        (s) => (s - player.speed).abs() < 0.01);
    final next = _speeds[(index + 1) % _speeds.length];
    player.setSpeed(next);
    _poke();
  }

  Future<void> _showSpeedSheet() async {
    final player = context.read<PlayerProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Text('Playback Speed',
                style: AppTypography.headlineMd),
            SizedBox(height: 8),
            for (final speed in _speeds)
              ListTile(
                title: Text(speed == 1.0
                    ? '1.0x (Normal)'
                    : '${speed}x'),
                trailing: (speed - player.speed).abs() < 0.01
                    ? Icon(Icons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  player.setSpeed(speed);
                  Navigator.of(context).pop();
                },
              ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
    _poke();
  }

  Future<void> _showSubtitleSheet() async {
    final player = context.read<PlayerProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Text('Subtitles',
                  style: AppTypography.headlineMd),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.subtitles_off_outlined),
                title: Text('Off'),
                trailing: !player.subtitleEnabled
                    ? Icon(Icons.check,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  player.disableSubtitles();
                  Navigator.of(context).pop();
                },
              ),
              for (final track in player.subtitleTracks)
                ListTile(
                  leading:
                      Icon(Icons.subtitles_outlined),
                  title: Text(track.label),
                  trailing: track.selected &&
                          player.subtitleEnabled
                      ? Icon(Icons.check,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    player.selectSubtitleTrack(track.id);
                    Navigator.of(context).pop();
                  },
                ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Load external .srt / .ass / .vtt files from the ⋮ menu → “Load Subtitle File”.',
                  style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _poke();
  }

  Future<void> _showAudioSheet() async {
    final player = context.read<PlayerProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16),
            Text('Audio Track',
                style: AppTypography.headlineMd),
            SizedBox(height: 8),
            if (player.audioTracks.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This video has a single audio track.',
                  style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant),
                ),
              )
            else
              for (final track in player.audioTracks)
                ListTile(
                  leading:
                      Icon(Icons.audiotrack_outlined),
                  title: Text(track.label),
                  trailing: track.selected
                      ? Icon(Icons.check,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    player.selectAudioTrack(track.id);
                    Navigator.of(context).pop();
                  },
                ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
    _poke();
  }

  Future<void> _showAbRepeatSheet() async {
    final player = context.read<PlayerProvider>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 16),
              Text('AB Repeat',
                  style: AppTypography.headlineMd),
              SizedBox(height: 4),
              Text(
                'Loop a section of the video between two points.',
                style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant
                        .withOpacity(0.7)),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.flag_outlined,
                    color: AppColors.tertiary),
                title: Text('Set Point A'),
                subtitle: Text(player.abPointA != null
                    ? 'A at ${Formatters.duration(player.abPointA!)}'
                    : 'Not set'),
                onTap: player.setAbPointA,
              ),
              ListTile(
                leading: Icon(Icons.flag,
                    color: AppColors.tertiary),
                title: Text('Set Point B'),
                subtitle: Text(player.abPointB != null
                    ? 'B at ${Formatters.duration(player.abPointB!)}'
                    : 'Not set'),
                onTap: player.setAbPointB,
              ),
              ListTile(
                leading: Icon(Icons.clear,
                    color: AppColors.error),
                title: Text('Clear AB Repeat',
                    style:
                        TextStyle(color: AppColors.error)),
                enabled: player.abPointA != null ||
                    player.abPointB != null,
                onTap: () {
                  player.clearAbRepeat();
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    _poke();
  }

  Future<void> _loadSubtitleFile() async {
    final player = context.read<PlayerProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await player.loadExternalSubtitle(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Loaded subtitle: ${path.split('/').last}')),
    );
    _poke();
  }

  /// Downloads a subtitle from a direct link and attaches it to the video.
  Future<void> _loadSubtitleFromUrl() async {
    final player = context.read<PlayerProvider>();
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Subtitle from URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'https://example.com/movie.srt',
            helperText: 'Direct link to a .srt, .vtt or .ass file',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: Text('Download'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading subtitle\u2026')),
    );
    final path = await SubtitleDownloadService().downloadFromUrl(url);
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subtitle download failed.')),
      );
      return;
    }
    await player.loadExternalSubtitle(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subtitle loaded.')),
    );
    _poke();
  }

  /// A/V sync \u2014 nudge the audio earlier or later than the video.
  Future<void> _showAudioDelaySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) => Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Audio Delay', style: AppTypography.headlineMd),
                SizedBox(height: 4),
                Text(
                  'Fix out-of-sync sound. Positive delays the audio.',
                  style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant.withOpacity(0.7)),
                ),
                SizedBox(height: 16),
                Text(
                  '${player.audioDelay > 0 ? '+' : ''}'
                  '${player.audioDelay.toStringAsFixed(2)} s',
                  style: AppTypography.headlineMd
                      .copyWith(color: AppColors.primary),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => player.nudgeAudioDelay(-0.05),
                      child: Text('\u2212 50 ms'),
                    ),
                    SizedBox(width: 12),
                    TextButton(
                      onPressed: player.resetAudioDelay,
                      child: Text('Reset'),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => player.nudgeAudioDelay(0.05),
                      child: Text('+ 50 ms'),
                    ),
                  ],
                ),
                Slider(
                  value: player.audioDelay.clamp(-5.0, 5.0),
                  min: -5,
                  max: 5,
                  divisions: 200,
                  label: '${player.audioDelay.toStringAsFixed(2)} s',
                  onChanged: player.setAudioDelay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _poke();
  }

  /// Video look controls: night mode plus manual brightness / contrast.
  Future<void> _showVideoToolsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) => Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Video Adjust', style: AppTypography.headlineMd),
                SizedBox(height: 8),
                SwitchListTile(
                  value: player.nightMode,
                  onChanged: (_) => player.toggleNightMode(),
                  secondary: Icon(Icons.nightlight_round),
                  title: Text('Night Mode'),
                  subtitle: Text('Brighten dark scenes, soften colour'),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.light_mode_outlined),
                  title: Text('Brightness boost'),
                  subtitle: Slider(
                    value: player.videoBrightness,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: player.videoBrightness.round().toString(),
                    onChanged: player.setVideoBrightness,
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.contrast),
                  title: Text('Contrast'),
                  subtitle: Slider(
                    value: player.videoContrast,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: player.videoContrast.round().toString(),
                    onChanged: player.setVideoContrast,
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Saturation'),
                  subtitle: Slider(
                    value: player.videoSaturation,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    label: player.videoSaturation.round().toString(),
                    onChanged: player.setVideoSaturation,
                  ),
                ),
                TextButton(
                  onPressed: player.resetVideoFilters,
                  child: Text('Reset all'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _poke();
  }

  /// Chapter list read from the MKV / MP4 container.
  Future<void> _showChaptersSheet() async {
    final player = context.read<PlayerProvider>();
    if (!player.hasChapters) await player.loadChapters();
    if (!mounted) return;
    if (!player.hasChapters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This video has no chapters.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (context, player, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                Text('Chapters', style: AppTypography.headlineMd),
                SizedBox(height: 8),
                for (var i = 0; i < player.chapterTitles.length; i++)
                  ListTile(
                    leading: Icon(
                      i == player.currentChapterIndex
                          ? Icons.play_circle_fill
                          : Icons.bookmark_border,
                      color: i == player.currentChapterIndex
                          ? AppColors.primary
                          : null,
                    ),
                    title: Text(player.chapterTitles[i]),
                    subtitle:
                        Text(Formatters.duration(player.chapterTimes[i])),
                    onTap: () {
                      player.jumpToChapter(i);
                      Navigator.of(context).pop();
                    },
                  ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    _poke();
  }

  // --- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final settings = context.watch<SettingsProvider>();

    if (!player.isActive || player.controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              SizedBox(height: 16),
              Text('Playback stopped',
                  style: AppTypography.headlineMd),
              if (player.lastError != null) ...[
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 48),
                  child: Text(
                    player.lastError!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
              SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).maybePop(),
                child: Text('Back to Library'),
              ),
            ],
          ),
        ),
      );
    }

    final position = _seekPreview ?? player.position;

    // Subtitle styling from settings.
    final subtitleShadows = <Shadow>[
      ...switch (settings.subtitleShadow) {
        SubtitleShadow.none => <Shadow>[],
        SubtitleShadow.subtle => [
            Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 1)),
          ],
        SubtitleShadow.heavy => [
            Shadow(
                color: Colors.black87,
                blurRadius: 10,
                offset: Offset(0, 2)),
          ],
      },
      ...switch (settings.subtitleOutline) {
        SubtitleOutline.none => <Shadow>[],
        SubtitleOutline.thin => _outlineShadows(1),
        SubtitleOutline.normal => _outlineShadows(2),
        SubtitleOutline.thick => _outlineShadows(3),
      },
    ];

    final screenHeight = MediaQuery.of(context).size.height;
    final subtitleBottomPadding = (screenHeight *
            (1 - settings.subtitleVerticalPos))
        .clamp(16.0, screenHeight * 0.5);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Video surface -------------------------------------------
          Transform.flip(
            flipX: player.mirrored,
            child: Video(
              controller: player.controller!,
              controls: NoVideoControls,
              fit: switch (player.aspectMode) {
                AspectMode.fit => BoxFit.contain,
                AspectMode.crop => BoxFit.cover,
                AspectMode.stretch => BoxFit.fill,
                AspectMode.ratio16x9 => BoxFit.fitWidth,
                AspectMode.ratio4x3 => BoxFit.contain,
              },
              subtitleViewConfiguration:
                  SubtitleViewConfiguration(
                style: TextStyle(
                  fontSize: settings.subtitleFontSize,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: settings.subtitleColor,
                  shadows: subtitleShadows,
                  backgroundColor:
                      switch (settings.subtitleBackground) {
                    SubtitleBackground.transparent =>
                      Colors.transparent,
                    SubtitleBackground.translucent =>
                      Colors.black54,
                    SubtitleBackground.solid => Colors.black,
                  },
                ),
                textAlign: TextAlign.center,
                padding: EdgeInsets.fromLTRB(
                    64, 0, 64, subtitleBottomPadding),
              ),
            ),
          ),
          // --- Gesture layer -------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _locked ? null : _toggleControls,
            onDoubleTapDown:
                _locked ? null : _onDoubleTapDown,
            onDoubleTap: () {},
            onVerticalDragStart:
                _locked ? null : _onVerticalDragStart,
            onVerticalDragUpdate:
                _locked ? null : _onVerticalDragUpdate,
            onVerticalDragEnd:
                _locked ? null : _onVerticalDragEnd,
            onHorizontalDragStart:
                _locked ? null : _onHorizontalDragStart,
            onHorizontalDragUpdate:
                _locked ? null : _onHorizontalDragUpdate,
            onHorizontalDragEnd:
                _locked ? null : _onHorizontalDragEnd,
          ),
          // --- Double-tap ripple ----------------------------------------
          if (_ripple != null)
            Positioned(
              left: _ripple!.position.dx - 60,
              top: _ripple!.position.dy - 60,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration:
                      Duration(milliseconds: 700),
                  builder: (context, t, _) => Opacity(
                    opacity: 1 - t,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            _ripple!.forward
                                ? Icons.fast_forward
                                : Icons.fast_rewind,
                            color: Colors.white,
                            size: 32,
                          ),
                          Text(
                            '${_ripple!.seconds}s',
                            style: AppTypography.labelLg
                                .copyWith(
                                    color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // --- Gesture HUD ----------------------------------------------
          if (_hud != null)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: AppRadius.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_hud!.icon,
                          color: Colors.white, size: 28),
                      SizedBox(width: 16),
                      SizedBox(
                        width: 160,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _hud!.fraction,
                            minHeight: 6,
                            backgroundColor: Colors.white
                                .withOpacity(0.2),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        '${(_hud!.fraction * 100).round()}%',
                        style: AppTypography.labelLg
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // --- Seek preview pill ----------------------------------------
          if (_seekPreview != null)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    '${Formatters.duration(_seekPreview!)} / ${Formatters.duration(player.duration)}',
                    style: AppTypography.headlineMd.copyWith(
                      color: Colors.white,
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // --- Buffering spinner -----------------------------------------
          if (player.buffering && player.lastError == null)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 76,
                  height: 76,
                  padding: EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          // --- Error state with retry ------------------------------------
          if (player.lastError != null)
            Center(
              child: Container(
                margin: EdgeInsets.all(32),
                padding: EdgeInsets.all(24),
                constraints: BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.78),
                  borderRadius: AppRadius.card,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 42),
                    SizedBox(height: 12),
                    Text(
                      player.lastError!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd
                          .copyWith(color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
                          child: Text('Back',
                              style:
                                  TextStyle(color: Colors.white70)),
                        ),
                        SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () {
                            final video = player.current;
                            if (video != null) player.open(video);
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Retry'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // --- Playback stats overlay -----------------------------------
          if (_showStats)
            Positioned(
              top: 24,
              left: 24,
              child: SafeArea(
                child: PlaybackStatsOverlay(player: player),
              ),
            ),
          // --- Lock mode -------------------------------------------------
          if (_locked)
            Positioned(
              top: 24,
              right: 24,
              child: SafeArea(
                child: _GlassButton(
                  icon: Icons.lock,
                  tooltip: 'Unlock controls',
                  highlighted: true,
                  onTap: () {
                    setState(() => _locked = false);
                    _poke();
                  },
                ),
              ),
            ),
          // --- Controls overlay ------------------------------------------
          if (!_locked)
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                duration: AppMotion.slow,
                curve: AppMotion.ease,
                opacity: _controlsVisible ? 1 : 0,
                child: _buildControls(
                    context, player, position),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    final player = context.read<PlayerProvider>();
    final bytes = await player.captureFrame();
    if (!mounted) return;
    if (bytes == null) {
      _snack('Screenshot not supported on this device');
      return;
    }
    final path = await _capture.saveScreenshot(bytes);
    if (!mounted) return;
    _snack(path == null
        ? 'Could not save screenshot'
        : 'Saved: ${path.split('/').last}');
  }

  Future<void> _addBookmark() async {
    final player = context.read<PlayerProvider>();
    final video = player.current;
    if (video == null) return;
    final pos = player.position;
    await _bookmarks.add(
      video.path,
      VideoBookmark(
        positionMs: pos.inMilliseconds,
        label: Formatters.duration(pos),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    _snack('Bookmark added at ${Formatters.duration(pos)}');
  }

  Future<void> _showBookmarksSheet() async {
    final player = context.read<PlayerProvider>();
    final video = player.current;
    if (video == null) return;
    final items = await _bookmarks.list(video.path);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      builder: (sheetContext) => SafeArea(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bookmarks yet'))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final b in items)
                    ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(b.label),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        player.seek(b.position);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _bookmarks.removeAt(video.path, b.positionMs);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
  }

  Widget _buildControls(BuildContext context,
      PlayerProvider player, Duration position) {
    final settings = context.read<SettingsProvider>();
    final compact = MediaQuery.of(context).size.width < 600;
    return Column(
      children: [
        // ==== Header =========================================================
        Container(
          padding: compact
              ? EdgeInsets.fromLTRB(12, 8, 12, 24)
              : EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _GlassButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () =>
                      Navigator.of(context).maybePop(),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.current?.title ?? 'Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd
                            .copyWith(color: Colors.white),
                      ),
                      if (player.queueLabel != null)
                        Text(
                          player.queueLabel!,
                          style: AppTypography.labelMd
                              .copyWith(
                                  color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                if (player.abRepeatActive) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer
                          .withOpacity(0.8),
                      borderRadius: AppRadius.pill,
                    ),
                    child: Text('A–B',
                        style: AppTypography.labelMd
                            .copyWith(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700)),
                  ),
                  SizedBox(width: 12),
                ],
                _GlassButton(
                  icon: Icons.screen_rotation_rounded,
                  tooltip: 'Rotate screen',
                  onTap: _toggleOrientation,
                ),
                SizedBox(width: 12),
                _GlassButton(
                  icon: Icons.lock_open,
                  tooltip: 'Lock controls',
                  onTap: () {
                    _hideTimer?.cancel();
                    setState(() {
                      _locked = true;
                      _controlsVisible = false;
                    });
                  },
                ),
                SizedBox(width: 12),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  color: AppColors.surfaceContainerHigh,
                  onSelected: (action) async {
                    switch (action) {
                      case 'ab':
                        await _showAbRepeatSheet();
                      case 'aspect':
                        player.cycleAspectMode();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              'Aspect ratio: ${player.aspectMode.label}'),
                          duration: Duration(
                              seconds: 1),
                        ));
                        _poke();
                      case 'mirror':
                        player.toggleMirror();
                        _poke();
                      case 'sleep':
                        await showSleepTimerDialog(
                            context);
                        _poke();
                      case 'subtitle_file':
                        await _loadSubtitleFile();
                      case 'screenshot':
                        await _takeScreenshot();
                      case 'bookmark_add':
                        await _addBookmark();
                      case 'bookmarks':
                        await _showBookmarksSheet();
                      case 'frame_back':
                        await player.stepFrame(forward: false);
                        _poke();
                      case 'frame_fwd':
                        await player.stepFrame(forward: true);
                        _poke();
                      case 'subtitle_url':
                        await _loadSubtitleFromUrl();
                      case 'audio_delay':
                        await _showAudioDelaySheet();
                      case 'video_adjust':
                        await _showVideoToolsSheet();
                      case 'night':
                        await player.toggleNightMode();
                        _poke();
                      case 'chapters':
                        await _showChaptersSheet();
                      case 'stats':
                        setState(() => _showStats = !_showStats);
                        _poke();
                      case 'background':
                        await player
                            .enableBackgroundPlayback();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                    }
                  },
                  itemBuilder: (context) => [
                    _menuItem('ab', Icons.repeat,
                        'AB Repeat',
                        checked: player.abRepeatActive),
                    _menuItem('aspect',
                        Icons.aspect_ratio, 'Aspect Ratio'),
                    _menuItem('mirror', Icons.flip,
                        'Mirror',
                        checked: player.mirrored),
                    _menuItem('sleep',
                        Icons.bedtime_outlined,
                        'Sleep Timer',
                        checked:
                            player.sleepTimerActive),
                    _menuItem(
                        'subtitle_file',
                        Icons.upload_file,
                        'Load Subtitle File'),
                    _menuItem('screenshot',
                        Icons.photo_camera_outlined, 'Screenshot'),
                    _menuItem('bookmark_add',
                        Icons.bookmark_add_outlined, 'Add Bookmark'),
                    _menuItem('bookmarks',
                        Icons.bookmarks_outlined, 'Bookmarks'),
                    _menuItem('frame_back',
                        Icons.skip_previous_outlined, 'Previous Frame'),
                    _menuItem('frame_fwd',
                        Icons.skip_next_outlined, 'Next Frame'),
                    _menuItem(
                        'subtitle_url',
                        Icons.cloud_download_outlined,
                        'Subtitle from URL'),
                    _menuItem('audio_delay',
                        Icons.av_timer, 'Audio Delay (A/V sync)'),
                    _menuItem('video_adjust',
                        Icons.tune, 'Video Adjust'),
                    _menuItem('night', Icons.nightlight_round,
                        'Night Mode',
                        checked: player.nightMode),
                    _menuItem('chapters',
                        Icons.list_alt_outlined, 'Chapters'),
                    _menuItem('stats',
                        Icons.insights_outlined, 'Playback Stats'),
                    _menuItem(
                        'background',
                        Icons.music_video,
                        'Play in Background'),
                  ],
                  child: _GlassButton(
                    icon: Icons.more_vert,
                    forceEnabledLook: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ==== Center controls =================================================
        Expanded(
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 40),
                child: _SideRail(
                  icon: Icons.brightness_6_outlined,
                  fraction: _brightness,
                  enabled: settings.brightnessGesture,
                  onChanged: (f) {
                    _brightness = f;
                    BrightnessService().set(f);
                    setState(() {});
                    _poke();
                  },
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    _GlassButton(
                      icon: Icons.skip_previous_rounded,
                      size: compact ? 40.0 : AppSpacing.playbackControl,
                      iconSize: compact ? 24.0 : 32,
                      tooltip: 'Previous',
                      onTap: player.hasPrevious
                          ? () {
                              player.playPrevious();
                              _poke();
                            }
                          : null,
                    ),
                    SizedBox(width: compact ? 12.0 : 28),
                    _GlassButton(
                      icon: Icons.replay_10_rounded,
                      size: compact ? 40.0 : AppSpacing.playbackControl,
                      iconSize: compact ? 22.0 : 30,
                      tooltip: 'Rewind 10 seconds',
                      onTap: () {
                        player.seekRelative(
                            Duration(seconds: -10));
                        _poke();
                      },
                    ),
                    SizedBox(width: compact ? 12.0 : 28),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppColors.primaryGlow,
                      ),
                      child: Material(
                        color: AppColors.primaryContainer,
                        shape: CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            player.playOrPause();
                            _poke();
                          },
                          customBorder:
                              CircleBorder(),
                          child: SizedBox(
                            width: (compact ? 64.0 : AppSpacing.playbackControlLarge),
                            height: (compact ? 64.0 : AppSpacing.playbackControlLarge),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: AppMotion.fast,
                                transitionBuilder:
                                    (child, animation) =>
                                        ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                                child: Icon(
                                  player.playing
                                      ? Icons.pause_rounded
                                      : Icons
                                          .play_arrow_rounded,
                                  key: ValueKey(
                                      player.playing),
                                  color: AppColors
                                      .onPrimaryContainer,
                                  size: compact ? 32.0 : 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 12.0 : 28),
                    _GlassButton(
                      icon: Icons.forward_10_rounded,
                      size: compact ? 40.0 : AppSpacing.playbackControl,
                      iconSize: compact ? 22.0 : 30,
                      tooltip: 'Forward 10 seconds',
                      onTap: () {
                        player.seekRelative(
                            Duration(seconds: 10));
                        _poke();
                      },
                    ),
                    SizedBox(width: compact ? 12.0 : 28),
                    _GlassButton(
                      icon: Icons.skip_next_rounded,
                      size: compact ? 40.0 : AppSpacing.playbackControl,
                      iconSize: compact ? 24.0 : 32,
                      tooltip: 'Next',
                      onTap: player.hasNext
                          ? () {
                              player.playNext();
                              _poke();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 40),
                child: _SideRail(
                  icon: player.volume <= 0
                      ? Icons.volume_off
                      : Icons.volume_up_outlined,
                  fraction: player.volume / 100,
                  enabled: true,
                  onChanged: (f) {
                    player.setVolume(f * 100);
                    _poke();
                  },
                ),
              ),
            ],
          ),
        ),
        // ==== Footer ==========================================================
        Container(
          padding: compact
              ? EdgeInsets.fromLTRB(12, 24, 12, 8)
              : EdgeInsets.fromLTRB(24, 32, 24, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _SpeedPill(
                      label: player.speed % 1 == 0
                          ? '${player.speed.toStringAsFixed(0)}x'
                          : '${player.speed}x',
                      onTap: _cycleSpeed,
                      onLongPress: _showSpeedSheet,
                    ),
                    SizedBox(width: compact ? 8.0 : 16),
                    _GlassButton(
                      icon: Icons.subtitles_outlined,
                      size: compact ? 38.0 : 48,
                      iconSize: compact ? 18.0 : 22,
                      tooltip: 'Subtitles',
                      highlighted: player.subtitleEnabled,
                      onTap: _showSubtitleSheet,
                    ),
                    SizedBox(width: compact ? 8.0 : 16),
                    _GlassButton(
                      icon: Icons.audiotrack_outlined,
                      size: compact ? 38.0 : 48,
                      iconSize: compact ? 18.0 : 22,
                      tooltip: 'Audio track',
                      onTap: _showAudioSheet,
                    ),
                    Spacer(),
                    _GlassButton(
                      icon: Icons.equalizer_rounded,
                      size: compact ? 38.0 : 48,
                      iconSize: compact ? 18.0 : 22,
                      tooltip: 'Equalizer',
                      highlighted: settings.eqEnabled,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(
                            Routes.shell,
                            arguments: 'equalizer');
                      },
                    ),
                    SizedBox(width: compact ? 8.0 : 16),
                    _GlassButton(
                      icon: Icons.picture_in_picture_alt,
                      size: compact ? 38.0 : 48,
                      iconSize: compact ? 18.0 : 22,
                      tooltip: 'Picture in Picture',
                      onTap: () {
                        player.enterPip();
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(width: compact ? 8.0 : 16),
                    _GlassButton(
                      icon: Icons.fullscreen_exit,
                      size: compact ? 38.0 : 48,
                      iconSize: compact ? 18.0 : 22,
                      tooltip: 'Exit player',
                      onTap: () =>
                          Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      Formatters.duration(position),
                      style: AppTypography.labelLg.copyWith(
                        color: Colors.white,
                        fontFeatures: [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _SeekBar(
                        position: position,
                        duration: player.duration,
                        abPointA: player.abPointA,
                        abPointB: player.abPointB,
                        onSeek: (target) {
                          player.seek(target);
                          _poke();
                        },
                      ),
                    ),
                    SizedBox(width: 20),
                    Text(
                      Formatters.duration(player.duration),
                      style: AppTypography.labelLg.copyWith(
                        color: Colors.white70,
                        fontFeatures: [
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label,
      {bool checked = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: AppColors.onSurfaceVariant),
          SizedBox(width: 14),
          Expanded(child: Text(label)),
          if (checked)
            Icon(Icons.check,
                size: 18, color: AppColors.primary),
        ],
      ),
    );
  }

  static List<Shadow> _outlineShadows(double width) => [
        for (final dx in [-width, 0.0, width])
          for (final dy in [-width, 0.0, width])
            if (dx != 0 || dy != 0)
              Shadow(
                  color: Colors.black,
                  offset: Offset(dx, dy),
                  blurRadius: 0),
      ];
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

class _HudData {
  _HudData({required this.icon, required this.fraction});

  final IconData icon;
  final double fraction;
}

class _SeekRipple {
  _SeekRipple({
    required this.position,
    required this.forward,
    required this.seconds,
  });

  final Offset position;
  final bool forward;
  final int seconds;
}

/// Frosted circular control button used across the player chrome.
class _GlassButton extends StatelessWidget {
  _GlassButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 48,
    this.iconSize = 22,
    this.highlighted = false,
    this.forceEnabledLook = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool highlighted;

  /// When true the button renders in its enabled style even without an
  /// `onTap` — used when wrapped by [PopupMenuButton], which handles taps.
  final bool forceEnabledLook;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || forceEnabledLook;

    Widget button = Material(
      color: highlighted
          ? AppColors.primaryContainer.withOpacity(0.4)
          : Colors.white.withOpacity(0.12),
      shape: CircleBorder(
        side: BorderSide(
          color: highlighted
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled
                ? Colors.white
                : Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Vertical brightness / volume rail beside the transport controls.
class _SideRail extends StatelessWidget {
  _SideRail({
    required this.icon,
    required this.fraction,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final double fraction;
  final bool enabled;
  final ValueChanged<double> onChanged;

  static const double _height = 128;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.of(context).size.width < 600) {
      return SizedBox(width: 16);
    }

    void handle(Offset localPosition) {
      final f =
          (1 - localPosition.dy / _height).clamp(0.0, 1.0);
      onChanged(f);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) =>
              handle(details.localPosition),
          onTapDown: (details) =>
              handle(details.localPosition),
          child: SizedBox(
            width: 40,
            height: _height,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 8,
                  height: _height,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                          color: Colors.white
                              .withOpacity(0.2)),
                      FractionallySizedBox(
                        heightFactor:
                            fraction.clamp(0.0, 1.0),
                        child: Container(
                            color: AppColors
                                .primaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Speed pill: tap to cycle, long-press for the full sheet.
class _SpeedPill extends StatelessWidget {
  _SpeedPill({
    required this.label,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      shape: StadiumBorder(
        side: BorderSide(
            color: Colors.white.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 48,
          padding:
              EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.labelLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFeatures: [
                FontFeature.tabularFigures()
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom seek bar with AB-repeat markers and a glowing thumb.
class _SeekBar extends StatelessWidget {
  _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.abPointA,
    this.abPointB,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Duration? abPointA;
  final Duration? abPointB;

  @override
  Widget build(BuildContext context) {
    final totalMs =
        duration.inMilliseconds.clamp(1, 1 << 62);
    final fraction =
        (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(double dx) {
          final f =
              (dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek(Duration(
              milliseconds: (f * totalMs).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              seekTo(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              seekTo(details.localPosition.dx),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Track.
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(2),
                  ),
                ),
                // Fill.
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(2),
                    ),
                  ),
                ),
                // AB markers.
                if (abPointA != null)
                  _AbMarker(
                      label: 'A',
                      fraction: (abPointA!.inMilliseconds /
                              totalMs)
                          .clamp(0.0, 1.0),
                      maxWidth: constraints.maxWidth),
                if (abPointB != null)
                  _AbMarker(
                      label: 'B',
                      fraction: (abPointB!.inMilliseconds /
                              totalMs)
                          .clamp(0.0, 1.0),
                      maxWidth: constraints.maxWidth),
                // Thumb.
                Align(
                  alignment:
                      Alignment(fraction * 2 - 1, 0),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors
                              .primaryContainer
                              .withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
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

class _AbMarker extends StatelessWidget {
  _AbMarker({
    required this.label,
    required this.fraction,
    required this.maxWidth,
  });

  final String label;
  final double fraction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (fraction * maxWidth - 10)
          .clamp(0.0, maxWidth - 20),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
