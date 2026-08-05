import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';

/// Splash: glowing logo mark, wordmark, tagline and a slim loading bar
/// before routing to onboarding or the main shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1400),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: 1600), _next);
  }

  void _next() {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    if (settings.onboardingDone) {
      // Refresh volumes in the background for returning users.
      context.read<LibraryProvider>().refreshVolumes();
      Navigator.of(context).pushReplacementNamed(Routes.shell);
    } else {
      Navigator.of(context)
          .pushReplacementNamed(Routes.permissions);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(
              parent: _controller, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Logo mark --------------------------------------------
              ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1).animate(
                  CurvedAnimation(
                      parent: _controller,
                      curve: AppMotion.emphasized),
                ),
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryContainer,
                        AppColors.accentPurple,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppRadius.xxl),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer
                            .withOpacity(0.45),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 64),
                ),
              ),
              SizedBox(height: 40),
              Text('Luvio Player',
                  style: AppTypography.displayLg),
              SizedBox(height: 12),
              Text(
                'Your movies. Beautifully played.',
                style: AppTypography.bodyLg.copyWith(
                    color: AppColors.onSurfaceVariant
                        .withOpacity(0.7)),
              ),
              SizedBox(height: 56),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) =>
                        LinearProgressIndicator(
                      value: _controller.value,
                      minHeight: 3,
                      backgroundColor:
                          Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
