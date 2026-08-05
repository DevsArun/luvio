import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/vault_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/glass_panel.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/media/video_card.dart';
import '../dialogs/video_options_sheet.dart';

/// Private Vault: PIN setup, PIN/fingerprint unlock, and the hidden
/// video grid once unlocked.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  // PIN-setup local state (only used when no PIN exists yet).
  String _setupPin = '';
  String _confirmPin = '';
  bool _confirmStage = false;
  String? _setupError;

  Future<void> _setupDigit(String digit) async {
    setState(() => _setupError = null);
    if (!_confirmStage) {
      if (_setupPin.length >= 4) return;
      setState(() => _setupPin += digit);
      if (_setupPin.length == 4) {
        setState(() => _confirmStage = true);
      }
    } else {
      if (_confirmPin.length >= 4) return;
      setState(() => _confirmPin += digit);
      if (_confirmPin.length == 4) {
        if (_confirmPin == _setupPin) {
          await context.read<VaultProvider>().setPin(_setupPin);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Vault PIN set — your hidden videos are protected')),
          );
          setState(() {
            _setupPin = '';
            _confirmPin = '';
            _confirmStage = false;
          });
        } else {
          setState(() {
            _setupError = 'PINs don’t match — try again';
            _setupPin = '';
            _confirmPin = '';
            _confirmStage = false;
          });
        }
      }
    }
  }

  void _setupBackspace() {
    setState(() {
      if (_confirmStage && _confirmPin.isNotEmpty) {
        _confirmPin =
            _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_confirmStage && _setupPin.isNotEmpty) {
        _setupPin = _setupPin.substring(0, _setupPin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    if (!vault.unlocked) {
      return _LockedView(
        vault: vault,
        setupPinLength: _confirmStage
            ? _confirmPin.length
            : _setupPin.length,
        confirmStage: _confirmStage,
        setupError: _setupError,
        onSetupDigit: _setupDigit,
        onSetupBackspace: _setupBackspace,
      );
    }
    return _UnlockedView(vault: vault);
  }
}

// ---------------------------------------------------------------------------
// Locked state (PIN setup or unlock)
// ---------------------------------------------------------------------------

class _LockedView extends StatelessWidget {
  _LockedView({
    required this.vault,
    required this.setupPinLength,
    required this.confirmStage,
    required this.setupError,
    required this.onSetupDigit,
    required this.onSetupBackspace,
  });

  final VaultProvider vault;
  final int setupPinLength;
  final bool confirmStage;
  final String? setupError;
  final ValueChanged<String> onSetupDigit;
  final VoidCallback onSetupBackspace;

  @override
  Widget build(BuildContext context) {
    final settingUp = !vault.hasPin;
    final filled = settingUp
        ? setupPinLength
        : vault.enteredPin.length;

    final Color dotAccent = switch (vault.phase) {
      VaultAuthPhase.failure => AppColors.error,
      VaultAuthPhase.success => AppColors.tertiary,
      _ => AppColors.primary,
    };

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.containerPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: GlassPanel(
            padding: EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Icon(
                    vault.phase == VaultAuthPhase.success
                        ? Icons.lock_open
                        : Icons.lock_outline,
                    color: dotAccent,
                    size: 36,
                  ),
                ),
                SizedBox(height: 24),
                Text('Private Vault',
                    style: AppTypography.headlineLg),
                SizedBox(height: 8),
                Text(
                  settingUp
                      ? (confirmStage
                          ? 'Confirm your 4-digit PIN'
                          : 'Create a 4-digit PIN to protect hidden videos')
                      : 'Enter your PIN to unlock',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.8)),
                ),
                if (setupError != null ||
                    vault.phase == VaultAuthPhase.failure) ...[
                  SizedBox(height: 10),
                  Text(
                    setupError ?? 'Incorrect PIN — try again',
                    style: AppTypography.labelLg
                        .copyWith(color: AppColors.error),
                  ),
                ],
                SizedBox(height: 28),
                // --- PIN dots -------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        curve: AppMotion.ease,
                        margin: EdgeInsets.symmetric(
                            horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < filled
                              ? dotAccent
                              : Colors.transparent,
                          border: Border.all(
                            color: i < filled
                                ? dotAccent
                                : AppColors.outline,
                            width: 2,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 32),
                // --- Keypad ---------------------------------------------
                _Keypad(
                  onDigit: settingUp
                      ? onSetupDigit
                      : vault.appendPinDigit,
                  onBackspace: settingUp
                      ? onSetupBackspace
                      : vault.deletePinDigit,
                  extra: (!settingUp)
                      ? _KeypadExtra(
                          icon: vault.phase ==
                                  VaultAuthPhase.scanning
                              ? Icons.fingerprint
                              : Icons.fingerprint,
                          pulsing: vault.phase ==
                              VaultAuthPhase.scanning,
                          onTap: () =>
                              vault.authenticateWithBiometrics(),
                        )
                      : null,
                ),
                SizedBox(height: 24),
                Text(
                  settingUp
                      ? 'Hidden videos stay on this device — nothing is uploaded.'
                      : 'Vault locks automatically when the app goes to the background.',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadExtra {
  _KeypadExtra({
    required this.icon,
    required this.onTap,
    this.pulsing = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool pulsing;
}

class _Keypad extends StatelessWidget {
  _Keypad({
    required this.onDigit,
    required this.onBackspace,
    this.extra,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final _KeypadExtra? extra;

  @override
  Widget build(BuildContext context) {
    Widget key(String digit) => _KeypadButton(
          child: Text(digit,
              style: AppTypography.headlineMd
                  .copyWith(fontSize: 26)),
          onTap: () => onDigit(digit),
          semantics: 'Digit $digit',
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final digit in row)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 7),
                    child: key(digit),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 7),
              child: extra != null
                  ? _KeypadButton(
                      onTap: extra!.onTap,
                      semantics: 'Unlock with fingerprint',
                      child: _PulsingIcon(
                        icon: extra!.icon,
                        pulsing: extra!.pulsing,
                      ),
                    )
                  : SizedBox(width: 64, height: 64),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 7),
              child: key('0'),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 7),
              child: _KeypadButton(
                onTap: onBackspace,
                semantics: 'Delete digit',
                child: Icon(Icons.backspace_outlined,
                    color: AppColors.onSurfaceVariant, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  _KeypadButton({
    required this.child,
    required this.onTap,
    required this.semantics,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: Material(
        color: AppColors.surfaceContainerHigh,
        shape: CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: CircleBorder(),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  _PulsingIcon({required this.icon, required this.pulsing});

  final IconData icon;
  final bool pulsing;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900),
    lowerBound: 0.5,
  );

  @override
  void didUpdateWidget(covariant _PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.pulsing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Icon(widget.icon,
          color: AppColors.tertiary, size: 26),
    );
  }
}

// ---------------------------------------------------------------------------
// Unlocked state
// ---------------------------------------------------------------------------

class _UnlockedView extends StatelessWidget {
  _UnlockedView({required this.vault});

  final VaultProvider vault;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final videos = library.vaultVideos;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1400 ? 4 : (width >= 1000 ? 3 : 2);

    void play(VideoItem video) {
      context
          .read<PlayerProvider>()
          .open(video, queue: videos);
      Navigator.of(context).pushNamed(
        Routes.player,
        arguments: PlayerScreenArgs(video: video),
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppSpacing.containerPadding),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MicroHeader('PROTECTED'),
                SizedBox(height: 8),
                SectionHeader(
                  title: 'Private Vault',
                  trailing: OutlinedButton.icon(
                    onPressed: vault.lock,
                    icon: Icon(Icons.lock, size: 18),
                    label: Text('Lock Now'),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${videos.length} hidden ${videos.length == 1 ? 'video' : 'videos'}',
                  style: AppTypography.bodyLg.copyWith(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.7)),
                ),
                SizedBox(height: 28),
                if (videos.isEmpty)
                  EmptyState(
                    icon: Icons.shield_outlined,
                    title: 'Nothing hidden yet',
                    message:
                        'Hide any video from its options menu → “Hide in Private Vault”. '
                        'Hidden videos disappear from your library and only show here.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppSpacing.cardGap,
                      crossAxisSpacing: AppSpacing.cardGap,
                      childAspectRatio: 16 / 12.4,
                    ),
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      return VideoCard(
                        video: video,
                        onTap: () => play(video),
                        onMore: () => showVideoOptionsSheet(
                            context,
                            video: video,
                            inVault: true),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
