import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/player_provider.dart';

/// Floating in-app Picture-in-Picture window. Lives above every route via
/// the MaterialApp builder Stack; draggable, resizable, with transport
/// controls, progress bar, expand and close.
class PipOverlayHost extends StatefulWidget {
  const PipOverlayHost({super.key});

  @override
  State<PipOverlayHost> createState() => _PipOverlayHostState();
}

class _PipOverlayHostState extends State<PipOverlayHost> {
  Offset? _position;
  double _width = 480;
  bool _controlsVisible = false;

  static const double _margin = 8;

  double _maxWidth(Size screen) =>
      (screen.width * 0.55).clamp(280.0, 560.0);

  Offset _clamp(Offset raw, Size screen, Size pip) {
    return Offset(
      raw.dx.clamp(_margin, screen.width - pip.width - _margin),
      raw.dy.clamp(_margin, screen.height - pip.height - _margin),
    );
  }

  void _expand(PlayerProvider player) {
    player.exitPip();
    rootNavigatorKey.currentState?.pushNamed(
      Routes.player,
      arguments: PlayerScreenArgs(fromPip: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    if (!player.pipActive || !player.isActive) {
      return SizedBox.shrink();
    }

    final screen = MediaQuery.of(context).size;
    final width = _width.clamp(280.0, _maxWidth(screen));
    final height = width * 9 / 16;
    final pipSize = Size(width, height);

    // Default dock: bottom-right.
    final position = _clamp(
      _position ??
          Offset(screen.width - width - 48, screen.height - height - 32),
      screen,
      pipSize,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: () =>
            setState(() => _controlsVisible = !_controlsVisible),
        onPanUpdate: (details) {
          setState(() {
            _position = _clamp(
                position + details.delta, screen, pipSize);
          });
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _controlsVisible = true),
          onExit: (_) => setState(() => _controlsVisible = false),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: AppRadius.card,
              border:
                  Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: AppColors.ambientShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (player.controller != null)
                  Video(
                    controller: player.controller!,
                    controls: NoVideoControls,
                    fit: BoxFit.cover,
                  ),
                // --- Top gradient bar -------------------------------------
                _Fade(
                  visible: _controlsVisible,
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding:
                        EdgeInsets.fromLTRB(12, 8, 8, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            player.current?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLg
                                .copyWith(color: Colors.white),
                          ),
                        ),
                        _PipIconButton(
                          icon: Icons.open_in_full,
                          tooltip: 'Expand',
                          onTap: () => _expand(player),
                        ),
                        SizedBox(width: 4),
                        _PipIconButton(
                          icon: Icons.close,
                          tooltip: 'Close',
                          onTap: player.closePip,
                        ),
                      ],
                    ),
                  ),
                ),
                // --- Bottom controls ---------------------------------------
                _Fade(
                  visible: _controlsVisible,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding:
                        EdgeInsets.fromLTRB(12, 20, 12, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PipProgressBar(player: player),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            _PipIconButton(
                              icon: Icons.replay_10,
                              tooltip: 'Back 10 seconds',
                              onTap: () => player.seekRelative(
                                  Duration(seconds: -10)),
                            ),
                            SizedBox(width: 8),
                            Material(
                              color: AppColors.primaryContainer,
                              shape: CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: player.playOrPause,
                                customBorder: CircleBorder(),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    player.playing
                                        ? Icons.pause
                                        : Icons.play_arrow_rounded,
                                    color:
                                        AppColors.onPrimaryContainer,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            _PipIconButton(
                              icon: Icons.forward_10,
                              tooltip: 'Forward 10 seconds',
                              onTap: () => player.seekRelative(
                                  Duration(seconds: 10)),
                            ),
                            Spacer(),
                            Text(
                              '${Formatters.duration(player.position)} / ${Formatters.duration(player.duration)}',
                              style: AppTypography.labelMd.copyWith(
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
                // --- Resize handle ------------------------------------------
                if (_controlsVisible)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _width = (_width + details.delta.dx)
                              .clamp(280.0, _maxWidth(screen));
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.bottomRight,
                        padding: EdgeInsets.all(4),
                        child: Transform.rotate(
                          angle: -0.785398, // -45°
                          child: Icon(Icons.unfold_more,
                              size: 16, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PipProgressBar extends StatelessWidget {
  _PipProgressBar({required this.player});

  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(double dx) {
          final fraction =
              (dx / constraints.maxWidth).clamp(0.0, 1.0);
          player.seek(Duration(
            milliseconds:
                (player.duration.inMilliseconds * fraction).round(),
          ));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
          child: SizedBox(
            height: 16,
            child: Center(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: player.progressFraction,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                        player.progressFraction * 2 - 1, 0),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
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
  }
}

class _PipIconButton extends StatelessWidget {
  _PipIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: Colors.white.withOpacity(0.10),
      shape: CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: CircleBorder(),
        child: SizedBox(width: 36, height: 36),
      ),
    );
    button = Stack(
      alignment: Alignment.center,
      children: [
        button,
        IgnorePointer(
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ],
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Slide + fade for the PiP control layers.
class _Fade extends StatelessWidget {
  _Fade({
    required this.visible,
    required this.child,
    required this.alignment,
  });

  final bool visible;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedSlide(
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        offset: visible
            ? Offset.zero
            : Offset(0, alignment == Alignment.topCenter ? -0.3 : 0.3),
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: child,
          ),
        ),
      ),
    );
  }
}
