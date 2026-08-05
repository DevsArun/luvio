import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../providers/player_provider.dart';

/// Part 3 — Developer-style overlay showing live playback stats. Rebuilds with
/// the player screen (which watches [PlayerProvider]).
class PlaybackStatsOverlay extends StatelessWidget {
  const PlaybackStatsOverlay({super.key, required this.player});

  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Resolution : ${player.resolutionLabel}',
      'Speed      : ${player.speed.toStringAsFixed(2)}x',
      'Volume     : ${player.volume.round()}%',
      'Position   : ${Formatters.duration(player.position)} / ${Formatters.duration(player.duration)}',
      'State      : ${player.buffering ? 'Buffering' : (player.playing ? 'Playing' : 'Paused')}',
      'Aspect     : ${player.aspectMode.label}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Text(
              l,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}
