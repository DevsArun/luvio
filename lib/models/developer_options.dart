/// Part 12 — Hidden / Developer features model. Gated behind a dev-mode toggle
/// (unlocked by tapping the version row 7 times). Controls low-level decoder
/// and caching behavior for the player engine.
enum DecoderPriority {
  hardwareFirst('Hardware first'),
  softwareFirst('Software first'),
  hardwarePlus('HW+ (aggressive)'),
  softwarePlus('SW+ (quality)');

  const DecoderPriority(this.label);
  final String label;
}

class DeveloperOptions {
  const DeveloperOptions({
    this.enabled = false,
    this.decoderPriority = DecoderPriority.hardwareFirst,
    this.codecFallback = true,
    this.frameSkip = false,
    this.subtitleCacheMb = 32,
    this.thumbnailCacheMb = 128,
    this.smartResumeSeconds = 5,
    this.autoDecoderSwitch = true,
    this.showPlaybackStats = false,
    this.hardwareAcceleration = true,
  });

  final bool enabled;
  final DecoderPriority decoderPriority;
  final bool codecFallback;
  final bool frameSkip;
  final int subtitleCacheMb;
  final int thumbnailCacheMb;
  final int smartResumeSeconds;
  final bool autoDecoderSwitch;
  final bool showPlaybackStats;
  final bool hardwareAcceleration;

  DeveloperOptions copyWith({
    bool? enabled,
    DecoderPriority? decoderPriority,
    bool? codecFallback,
    bool? frameSkip,
    int? subtitleCacheMb,
    int? thumbnailCacheMb,
    int? smartResumeSeconds,
    bool? autoDecoderSwitch,
    bool? showPlaybackStats,
    bool? hardwareAcceleration,
  }) {
    return DeveloperOptions(
      enabled: enabled ?? this.enabled,
      decoderPriority: decoderPriority ?? this.decoderPriority,
      codecFallback: codecFallback ?? this.codecFallback,
      frameSkip: frameSkip ?? this.frameSkip,
      subtitleCacheMb: subtitleCacheMb ?? this.subtitleCacheMb,
      thumbnailCacheMb: thumbnailCacheMb ?? this.thumbnailCacheMb,
      smartResumeSeconds: smartResumeSeconds ?? this.smartResumeSeconds,
      autoDecoderSwitch: autoDecoderSwitch ?? this.autoDecoderSwitch,
      showPlaybackStats: showPlaybackStats ?? this.showPlaybackStats,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'decoderPriority': decoderPriority.name,
        'codecFallback': codecFallback,
        'frameSkip': frameSkip,
        'subtitleCacheMb': subtitleCacheMb,
        'thumbnailCacheMb': thumbnailCacheMb,
        'smartResumeSeconds': smartResumeSeconds,
        'autoDecoderSwitch': autoDecoderSwitch,
        'showPlaybackStats': showPlaybackStats,
        'hardwareAcceleration': hardwareAcceleration,
      };

  static DeveloperOptions fromJson(Map<String, dynamic> j) => DeveloperOptions(
        enabled: j['enabled'] as bool? ?? false,
        decoderPriority: DecoderPriority.values.firstWhere(
          (e) => e.name == j['decoderPriority'],
          orElse: () => DecoderPriority.hardwareFirst,
        ),
        codecFallback: j['codecFallback'] as bool? ?? true,
        frameSkip: j['frameSkip'] as bool? ?? false,
        subtitleCacheMb: (j['subtitleCacheMb'] as num?)?.toInt() ?? 32,
        thumbnailCacheMb: (j['thumbnailCacheMb'] as num?)?.toInt() ?? 128,
        smartResumeSeconds: (j['smartResumeSeconds'] as num?)?.toInt() ?? 5,
        autoDecoderSwitch: j['autoDecoderSwitch'] as bool? ?? true,
        showPlaybackStats: j['showPlaybackStats'] as bool? ?? false,
        hardwareAcceleration: j['hardwareAcceleration'] as bool? ?? true,
      );
}
