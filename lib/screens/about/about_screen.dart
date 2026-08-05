import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/dialogs/feedback_dialog.dart';

/// About Luvio Player — 192px logo card with play_circle, version chip,
/// "Legal & Information" list, Developer + Feedback cards and the copyright
/// footer, per the reference.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.onBack});

  /// When embedded in the Settings shell, back returns inline; when pushed
  /// as a standalone route this pops the navigator.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1150;

    final legal = _LegalCard(context: context);
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeveloperCard(),
        SizedBox(height: 24),
        _FeedbackCard(onSend: () => showFeedbackDialog(context)),
      ],
    );

    final body = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 64),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        glass: true,
                        border: true,
                        onPressed: onBack ??
                            () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Hero: logo + name + version
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 192,
                          height: 192,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryContainer,
                                AppColors.primaryContainer
                                    .withOpacity(0.55),
                              ],
                            ),
                            boxShadow: AppColors.primaryGlow,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Icon(Icons.play_circle,
                              size: 120,
                              color: AppColors.onPrimaryContainer),
                        ),
                        SizedBox(height: 28),
                        Text('Luvio Player',
                            style: AppTypography.displayLg),
                        SizedBox(height: 10),
                        Text(
                          'Premium Offline Media Experience designed for power users.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLg.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(0.7)),
                        ),
                        SizedBox(height: 18),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh
                                .withOpacity(0.7),
                            borderRadius: AppRadius.pill,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            'Version 2.6.0 (Build 5000)',
                            style: AppTypography.labelLg.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 48),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: legal),
                        SizedBox(width: 24),
                        Expanded(flex: 4, child: side),
                      ],
                    )
                  else ...[
                    legal,
                    SizedBox(height: 24),
                    side,
                  ],
                  SizedBox(height: 48),
                  Center(
                    child: Text(
                      '© 2026 Luvio Labs. All rights reserved.',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Standalone route needs its own Scaffold; embedded use inherits one.
    return onBack != null ? body : Scaffold(body: body);
  }
}

class _LegalCard extends StatelessWidget {
  _LegalCard({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    Widget row({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.panel),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.secondary),
        ),
        title: Text(title, style: AppTypography.bodyLg),
        trailing: Icon(Icons.chevron_right,
            color: AppColors.onSurfaceVariant.withOpacity(0.5)),
      );
    }

    void showDoc(String title, String body) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: 560, maxHeight: 480),
            child: SingleChildScrollView(
              child: Text(body,
                  style: AppTypography.bodyMd.copyWith(height: 1.6)),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.55),
        borderRadius: AppRadius.panel,
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'LEGAL & INFORMATION',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          row(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => showDoc(
              'Privacy Policy',
              'Luvio Player is a fully offline application.\n\n'
              '• No account is required and none can be created.\n'
              '• Your videos, playlists, watch history and vault contents never leave this device.\n'
              '• The app does not collect analytics, telemetry, crash reports or advertising identifiers.\n'
              '• Storage permission is used solely to discover and play your local media files.\n'
              '• Biometric authentication for the Private Vault is handled entirely by the device — Luvio Player never sees your fingerprint data.\n\n'
              'Because no data is transmitted, there is nothing for us to sell, share or lose.',
            ),
          ),
          Divider(
              height: 1,
              indent: 76,
              color: Colors.white.withOpacity(0.04)),
          row(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => showDoc(
              'Terms of Service',
              'By using Luvio Player you agree to the following:\n\n'
              '1. Luvio Player is provided “as is” without warranty of any kind.\n'
              '2. You are responsible for the media files you store and play on your device, including compliance with applicable copyright law.\n'
              '3. The Private Vault hides files from the in-app library; it is a convenience feature and not a substitute for full-disk encryption.\n'
              '4. Luvio Labs is not liable for data loss resulting from file operations (delete, rename, move) you perform in the app.\n'
              '5. These terms may be updated with new releases of the application.',
            ),
          ),
          Divider(
              height: 1,
              indent: 76,
              color: Colors.white.withOpacity(0.04)),
          row(
            icon: Icons.code,
            title: 'Open Source Licenses',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Luvio Player',
              applicationVersion: '2.6.0 (Build 5100)',
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.55),
        borderRadius: AppRadius.panel,
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer.withOpacity(0.25),
              borderRadius: AppRadius.chip,
            ),
            child: Icon(Icons.terminal,
                size: 22, color: AppColors.tertiary),
          ),
          SizedBox(height: 16),
          Text('Developer', style: AppTypography.headlineMd),
          SizedBox(height: 8),
          Text(
            'Crafted with precision by the Luvio Team.',
            style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.7)),
          ),
          SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () =>
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Visit luvio.app in your browser to learn more'),
            )),
            icon: Icon(Icons.language, size: 18),
            label: Text('Visit Website'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  _FeedbackCard({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.10),
        borderRadius: AppRadius.panel,
        border:
            Border.all(color: AppColors.primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              borderRadius: AppRadius.chip,
            ),
            child: Icon(Icons.chat_bubble_outline,
                size: 22, color: AppColors.primary),
          ),
          SizedBox(height: 16),
          Text('Experiencing issues?',
              style: AppTypography.headlineMd),
          SizedBox(height: 8),
          Text(
            'Tell us what went wrong or what you’d love to see next.',
            style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.7)),
          ),
          SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onSend,
            icon: Icon(Icons.send, size: 18),
            label: Text('Send Feedback'),
          ),
        ],
      ),
    );
  }
}
