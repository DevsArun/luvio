import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/developer_options.dart';
import '../../services/developer_options_store.dart';

/// Part 12 — Hidden / Developer options. Rendered inside the settings
/// AnimatedSwitcher (same onBack pattern as the other sub-pages). Values are
/// persisted live via [DeveloperOptionsStore] and read by the player engine.
class DeveloperOptionsPage extends StatefulWidget {
  const DeveloperOptionsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<DeveloperOptionsPage> createState() => _DeveloperOptionsPageState();
}

class _DeveloperOptionsPageState extends State<DeveloperOptionsPage> {
  final DeveloperOptionsStore _store = DeveloperOptionsStore();
  DeveloperOptions _o = const DeveloperOptions();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await _store.load();
    if (!mounted) return;
    setState(() {
      _o = o;
      _loaded = true;
    });
  }

  void _update(DeveloperOptions next) {
    setState(() => _o = next);
    _store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Text('Developer Options',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Advanced decoder and caching controls. Change these only '
                    'if playback misbehaves on your device.',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 16),
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _buildBody(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: AppColors.surfaceContainerHigh,
          child: SwitchListTile(
            title: const Text('Enable developer mode'),
            subtitle: const Text('Unlock advanced engine controls'),
            value: _o.enabled,
            onChanged: (v) => _update(_o.copyWith(enabled: v)),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _o.enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !_o.enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: AppColors.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Decoder priority')),
                        DropdownButton<DecoderPriority>(
                          value: _o.decoderPriority,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final p in DecoderPriority.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ),
                          ],
                          onChanged: (p) => p == null
                              ? null
                              : _update(_o.copyWith(decoderPriority: p)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: AppColors.surfaceContainerHigh,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Hardware acceleration'),
                        value: _o.hardwareAcceleration,
                        onChanged: (v) =>
                            _update(_o.copyWith(hardwareAcceleration: v)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Codec fallback'),
                        subtitle: const Text(
                            'Retry with software decoder on failure'),
                        value: _o.codecFallback,
                        onChanged: (v) =>
                            _update(_o.copyWith(codecFallback: v)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Auto decoder switch'),
                        subtitle:
                            const Text('Switch decoder on playback stall'),
                        value: _o.autoDecoderSwitch,
                        onChanged: (v) =>
                            _update(_o.copyWith(autoDecoderSwitch: v)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Frame skip'),
                        subtitle: const Text(
                            'Drop frames to keep audio in sync'),
                        value: _o.frameSkip,
                        onChanged: (v) =>
                            _update(_o.copyWith(frameSkip: v)),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Show playback stats'),
                        subtitle: const Text(
                            'Overlay resolution, fps and bitrate'),
                        value: _o.showPlaybackStats,
                        onChanged: (v) =>
                            _update(_o.copyWith(showPlaybackStats: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _slider(
                  label: 'Subtitle cache',
                  value: _o.subtitleCacheMb.toDouble(),
                  min: 8,
                  max: 128,
                  suffix: 'MB',
                  onChanged: (v) =>
                      _update(_o.copyWith(subtitleCacheMb: v.round())),
                ),
                _slider(
                  label: 'Thumbnail cache',
                  value: _o.thumbnailCacheMb.toDouble(),
                  min: 32,
                  max: 512,
                  suffix: 'MB',
                  onChanged: (v) =>
                      _update(_o.copyWith(thumbnailCacheMb: v.round())),
                ),
                _slider(
                  label: 'Smart resume threshold',
                  value: _o.smartResumeSeconds.toDouble(),
                  min: 0,
                  max: 30,
                  suffix: 's',
                  onChanged: (v) =>
                      _update(_o.copyWith(smartResumeSeconds: v.round())),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      color: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text('${value.round()} $suffix',
                    style: TextStyle(color: AppColors.onSurfaceVariant)),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
