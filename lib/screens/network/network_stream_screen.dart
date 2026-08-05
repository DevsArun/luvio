import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/player_provider.dart';

/// "Open network stream" — play a video straight from a URL without
/// downloading it first: HTTP/HTTPS (including HLS `.m3u8` and DASH `.mpd`),
/// RTSP / RTMP live feeds, SMB Windows shares, FTP servers, UDP and SRT.
class NetworkStreamScreen extends StatefulWidget {
  const NetworkStreamScreen({super.key});

  @override
  State<NetworkStreamScreen> createState() => _NetworkStreamScreenState();
}

class _NetworkStreamScreenState extends State<NetworkStreamScreen> {
  static const String _prefsKey = 'recent_network_streams';

  final TextEditingController _controller = TextEditingController();
  List<String> _recent = <String>[];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _recent = prefs.getStringList(_prefsKey) ?? <String>[]);
    } catch (_) {
      // Recents are optional.
    }
  }

  Future<void> _remember(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = <String>[url, ..._recent.where((e) => e != url)];
      if (list.length > 15) list.removeRange(15, list.length);
      await prefs.setStringList(_prefsKey, list);
      if (!mounted) return;
      setState(() => _recent = list);
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recent = <String>[]);
  }

  Future<void> _play([String? value]) async {
    final url = (value ?? _controller.text).trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a stream address first.');
      return;
    }
    if (!PlayerProvider.isStreamUrl(url)) {
      setState(() => _error =
          'Unsupported address. Start with http://, https://, rtsp://, '
          'rtmp://, smb://, ftp://, udp:// or srt://');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    final player = context.read<PlayerProvider>();
    await _remember(url);
    await player.openNetworkStream(url);
    if (!mounted) return;
    setState(() => _busy = false);

    if (player.lastError != null) {
      setState(() => _error =
          'Could not open the stream. Check the address and your network.');
      return;
    }
    Navigator.of(context).pushNamed(Routes.player, arguments: PlayerScreenArgs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Network Stream'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_recent.isNotEmpty)
            TextButton(
              onPressed: _clearRecent,
              child: Text('Clear'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.containerPadding),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _play(),
              decoration: InputDecoration(
                labelText: 'Stream address',
                hintText: 'https://example.com/live/stream.m3u8',
                errorText: _error,
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _play(),
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.play_arrow_rounded),
                label: Text(_busy ? 'Connecting…' : 'Play stream'),
              ),
            ),
            SizedBox(height: 24),
            Text('Supported', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _Chip('HTTP / HTTPS'),
                _Chip('HLS .m3u8'),
                _Chip('DASH .mpd'),
                _Chip('RTSP'),
                _Chip('RTMP'),
                _Chip('SMB share'),
                _Chip('FTP'),
                _Chip('UDP'),
                _Chip('SRT'),
              ],
            ),
            if (_recent.isNotEmpty) ...[
              SizedBox(height: 24),
              Text('Recent', style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: 8),
              for (final url in _recent)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, size: 20),
                  title: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _busy ? null : () => _play(url),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
