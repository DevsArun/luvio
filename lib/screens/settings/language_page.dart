import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_enums.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/circle_icon_button.dart';

/// Language selection — radio list of supported UI languages.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

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
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back to Settings',
                        glass: true,
                        border: true,
                        onPressed: onBack,
                      ),
                      SizedBox(width: 20),
                      Text('Language', style: AppTypography.headlineLg),
                    ],
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Text(
                      'Choose the interface language for Luvio Player.',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer.withOpacity(0.55),
                      borderRadius: AppRadius.panel,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        for (final language in AppLanguage.values) ...[
                          if (language != AppLanguage.values.first)
                            Divider(
                                height: 1,
                                indent: 24,
                                color: Colors.white.withOpacity(0.04)),
                          RadioListTile<AppLanguage>(
                            value: language,
                            groupValue: settings.language,
                            onChanged: (v) {
                              if (v != null) settings.setLanguage(v);
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.panel),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            title: Text(language.displayName,
                                style: AppTypography.bodyLg),
                            subtitle: Text(
                              language.nativeName,
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant
                                      .withOpacity(0.6)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
