import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../screens/dialogs/sleep_timer_dialog.dart';

/// 80px reference top bar: a black-to-transparent gradient strip with an
/// optional context title on the left and right-aligned circular actions
/// (search, cast, overflow) exactly like the reference screens.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.title});

  static const double height = 80;

  /// Optional left-side context title (e.g. "Local Storage").
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.isLight
                  ? AppColors.background.withOpacity(0.92)
                  : Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            if (title != null) Flexible(child: title!),
            Spacer(),
            _RoundAction(
              icon: Icons.search,
              tooltip: 'Search',
              onTap: () =>
                  Navigator.of(context).pushNamed(Routes.search),
            ),
            SizedBox(width: 8),
            _RoundAction(
              icon: Icons.link,
              tooltip: 'Network stream',
              onTap: () =>
                  Navigator.of(context).pushNamed(Routes.networkStream),
            ),
            SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'More options',
              offset: Offset(0, 52),
              color: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                switch (value) {
                  case 'scan':
                    Navigator.of(context).pushNamed(Routes.scan);
                  case 'sleep':
                    showSleepTimerDialog(context);
                  case 'about':
                    Navigator.of(context).pushNamed(Routes.about);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'scan',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.radar, size: 20),
                    title: Text('Scan Storage'),
                  ),
                ),
                PopupMenuItem(
                  value: 'sleep',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bedtime_outlined, size: 20),
                    title: Text('Sleep Timer'),
                  ),
                ),
                PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline, size: 20),
                    title: Text('About'),
                  ),
                ),
              ],
              child: _RoundActionBody(icon: Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 48, height: 48),
        ),
      ),
    ).withIcon(icon);
  }
}

/// Small helper so the InkWell keeps its ripple while showing the icon.
extension on Widget {
  Widget withIcon(IconData icon) {
    return Stack(
      alignment: Alignment.center,
      children: [
        this,
        IgnorePointer(
          child:
              Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RoundActionBody extends StatelessWidget {
  _RoundActionBody({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
    );
  }
}
