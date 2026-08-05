import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_enums.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vault_provider.dart';
import '../../widgets/dialogs/feedback_dialog.dart';
import '../about/about_screen.dart';
import '../shell/app_shell.dart';
import 'gesture_settings_page.dart';
import 'language_page.dart';
import 'decoder_page.dart';
import 'backup_restore_page.dart';
import 'developer_options_page.dart';
import 'subtitle_manager_page.dart';

/// Settings — max-w-4xl column with uppercase primary section labels
/// (GENERAL / PLAYBACK / PRIVACY & DATA / ABOUT) and rounded groups of rows
/// with 40px tinted icon circles, per the reference. Sub-pages (Language,
/// Subtitle Appearance, Gestures, Decoder) slide in as nested content.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.onSectionSelected});

  final ValueChanged<AppSection> onSectionSelected;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _SettingsPage { root, language, subtitles, gestures, decoder, about, backup, developer }

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsPage _page = _SettingsPage.root;

  void _open(_SettingsPage page) => setState(() => _page = page);
  void _back() => setState(() => _page = _SettingsPage.root);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: AppMotion.ease,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: Offset(0.02, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: switch (_page) {
        _SettingsPage.root => _RootSettings(
            key: ValueKey('root'),
            onOpen: _open,
            onSectionSelected: widget.onSectionSelected,
          ),
        _SettingsPage.language =>
          LanguagePage(key: ValueKey('language'), onBack: _back),
        _SettingsPage.subtitles => SubtitleManagerPage(
            key: ValueKey('subtitles'), onBack: _back),
        _SettingsPage.gestures => GestureSettingsPage(
            key: ValueKey('gestures'), onBack: _back),
        _SettingsPage.decoder =>
          DecoderPage(key: ValueKey('decoder'), onBack: _back),
        _SettingsPage.about =>
          AboutScreen(key: ValueKey('about'), onBack: _back),
        _SettingsPage.backup =>
          BackupRestorePage(key: ValueKey('backup'), onBack: _back),
        _SettingsPage.developer =>
          DeveloperOptionsPage(key: ValueKey('developer'), onBack: _back),
      },
    );
  }
}

class _RootSettings extends StatelessWidget {
  _RootSettings({
    super.key,
    required this.onOpen,
    required this.onSectionSelected,
  });

  final ValueChanged<_SettingsPage> onOpen;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final vault = context.watch<VaultProvider>();
    final volume = library.volumes.isNotEmpty ? library.volumes.first : null;
    final usedFraction = volume != null && volume.totalBytes > 0
        ? (volume.totalBytes - volume.freeBytes) / volume.totalBytes
        : null;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Settings', style: AppTypography.displayLg),
                  SizedBox(height: 8),
                  Text(
                    'Manage playback preferences and application behavior.',
                    style: AppTypography.bodyLg.copyWith(
                        color:
                            AppColors.onSurfaceVariant.withOpacity(0.7)),
                  ),
                  SizedBox(height: 36),
                  // --- GENERAL ------------------------------------------
                  _SectionLabel('GENERAL'),
                  _Group(children: [
                    _Row(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Theme',
                      subtitle: 'Optimized for low-light viewing',
                      trailing: Switch(
                        value: settings.darkTheme,
                        onChanged: settings.setDarkTheme,
                      ),
                    ),
                    _Row(
                      icon: Icons.translate,
                      title: 'Language',
                      subtitle: settings.language.displayName,
                      onTap: () => onOpen(_SettingsPage.language),
                    ),
                  ]),
                  // --- PLAYBACK ----------------------------------------
                  _SectionLabel('PLAYBACK'),
                  _Group(children: [
                    _Row(
                      icon: Icons.speed,
                      title: 'Default Playback Speed',
                      subtitle: settings.defaultSpeed == 1.0
                          ? '1.0x (Normal)'
                          : '${settings.defaultSpeed}x',
                      onTap: () => _pickSpeed(context, settings),
                    ),
                    _Row(
                      icon: Icons.play_circle_outline,
                      title: 'Auto-Resume',
                      subtitle: 'Continue videos where you left off',
                      trailing: Switch(
                        value: settings.autoResume,
                        onChanged: settings.setAutoResume,
                      ),
                    ),
                    _Row(
                      icon: Icons.headphones_outlined,
                      title: 'Background Playback',
                      subtitle: 'Keep audio playing when the app is hidden',
                      trailing: Switch(
                        value: settings.backgroundPlayback,
                        onChanged: settings.setBackgroundPlayback,
                      ),
                    ),
                    _Row(
                      icon: Icons.subtitles_outlined,
                      title: 'Subtitle Appearance',
                      subtitle:
                          'White text, ${settings.subtitleFontSize.round()}px, position ${(settings.subtitleVerticalPos * 100).round()}%',
                      onTap: () => onOpen(_SettingsPage.subtitles),
                    ),
                    _Row(
                      icon: Icons.equalizer,
                      title: 'Audio Equalizer',
                      subtitle: settings.eqEnabled
                          ? '${_presetName(settings.eqPreset)} profile active'
                          : 'Disabled',
                      onTap: () =>
                          onSectionSelected(AppSection.equalizer),
                    ),
                    _Row(
                      icon: Icons.touch_app_outlined,
                      title: 'Gesture Controls',
                      subtitle:
                          'Brightness, volume, seek and double-tap',
                      onTap: () => onOpen(_SettingsPage.gestures),
                    ),
                    _Row(
                      icon: Icons.backup_outlined,
                      title: 'Backup & Restore',
                      subtitle: 'Export or import settings and library',
                      onTap: () => onOpen(_SettingsPage.backup),
                    ),
                    _Row(
                      icon: Icons.developer_mode_outlined,
                      title: 'Developer Options',
                      subtitle: 'Decoder, cache and playback tuning',
                      onTap: () => onOpen(_SettingsPage.developer),
                    ),
                    _Row(
                      icon: Icons.memory,
                      title: 'Hardware Decoder',
                      subtitle: switch (settings.decoderMode) {
                        DecoderMode.hardware => 'HW (recommended)',
                        DecoderMode.hardwarePlus => 'HW+ (aggressive)',
                        DecoderMode.software => 'SW (compatibility)',
                      },
                      onTap: () => onOpen(_SettingsPage.decoder),
                    ),
                  ]),
                  // --- PRIVACY & DATA ----------------------------------
                  _SectionLabel('PRIVACY & DATA'),
                  _Group(children: [
                    _Row(
                      icon: Icons.storage_outlined,
                      title: 'Storage Management',
                      subtitle: volume != null && usedFraction != null
                          ? '${Formatters.bytes(volume.totalBytes - volume.freeBytes)} of ${Formatters.bytes(volume.totalBytes)} used'
                          : 'Scan storage to see usage',
                      trailing: usedFraction != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: usedFraction,
                                      minHeight: 6,
                                      backgroundColor: AppColors
                                          .surfaceContainerHighest
                                          .withOpacity(0.7),
                                      color:
                                          AppColors.primaryContainer,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '${(usedFraction * 100).round()}% Used',
                                  style: AppTypography.labelMd.copyWith(
                                      color:
                                          AppColors.onSurfaceVariant),
                                ),
                              ],
                            )
                          : null,
                    ),
                    _Row(
                      icon: Icons.lock_outline,
                      title: 'Private Vault PIN',
                      subtitle: vault.hasPin
                          ? 'Change PIN or enable biometric unlock'
                          : 'Set up a PIN to hide private media',
                      iconTint: AppColors.error,
                      onTap: () => onSectionSelected(AppSection.vault),
                    ),
                  ]),
                  // --- ABOUT --------------------------------------------
                  _SectionLabel('ABOUT'),
                  _Group(children: [
                    _Row(
                      icon: Icons.info_outline,
                      title: 'About Luvio Player',
                      subtitle: 'Version 2.6.0 (Build 5000)',
                      onTap: () => onOpen(_SettingsPage.about),
                    ),
                    _Row(
                      icon: Icons.star_outline,
                      title: 'Rate Luvio Player',
                      subtitle: 'Love the app? Leave a rating',
                      iconTint: AppColors.tertiary,
                      onTap: () => showFeedbackDialog(context),
                    ),
                    _Row(
                      icon: Icons.chat_bubble_outline,
                      title: 'Send Feedback',
                      subtitle: 'Report issues or request features',
                      onTap: () => showFeedbackDialog(context),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _presetName(EqPreset preset) => switch (preset) {
        EqPreset.rock => 'Rock',
        EqPreset.pop => 'Pop',
        EqPreset.jazz => 'Jazz',
        EqPreset.movie => 'Movie',
        EqPreset.voice => 'Voice',
        EqPreset.custom => 'Custom',
      };

  void _pickSpeed(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Default Playback Speed'),
        children: [
          for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            RadioListTile<double>(
              title: Text(speed == 1.0 ? '1.0x (Normal)' : '${speed}x'),
              value: speed,
              groupValue: settings.defaultSpeed,
              onChanged: (v) {
                if (v != null) settings.setDefaultSpeed(v);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8, bottom: 12, left: 4),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.primary,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.55),
        borderRadius: AppRadius.panel,
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  indent: 76,
                  color: Colors.white.withOpacity(0.04)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconTint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    final tint = iconTint ?? AppColors.secondary;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.panel),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tint.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: tint),
      ),
      title: Text(title, style: AppTypography.bodyLg),
      subtitle: Text(
        subtitle,
        style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant.withOpacity(0.6)),
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right,
                  color: AppColors.onSurfaceVariant.withOpacity(0.5))
              : null),
    );
  }
}
