/// Enumerations shared by settings + player.

enum DecoderMode {
  hardware('Hardware Decoder', 'Best performance & battery (MediaCodec)'),
  hardwarePlus('Hardware+ Decoder', 'Hardware with software fallback'),
  software('Software Decoder', 'Maximum compatibility (CPU decoding)');

  const DecoderMode(this.label, this.description);
  final String label;
  final String description;
}

enum AspectMode {
  fit('Fit', 'Original aspect ratio'),
  crop('Crop', 'Fill screen, crop overflow'),
  stretch('Stretch', 'Fill screen, ignore ratio'),
  ratio16x9('16:9', 'Force widescreen'),
  ratio4x3('4:3', 'Force standard');

  const AspectMode(this.label, this.description);
  final String label;
  final String description;
}

enum SubtitleBackground {
  transparent('Transparent'),
  translucent('Translucent Dark'),
  solid('Solid Black');

  const SubtitleBackground(this.label);
  final String label;
}

enum SubtitleOutline {
  none('None'),
  thin('Thin'),
  normal('Normal'),
  thick('Thick');

  const SubtitleOutline(this.label);
  final String label;
}

enum SubtitleShadow {
  none('None'),
  subtle('Subtle'),
  heavy('Heavy');

  const SubtitleShadow(this.label);
  final String label;
}

enum SortMode {
  dateAdded('Date Added'),
  name('Name'),
  size('Size'),
  duration('Duration');

  const SortMode(this.label);
  final String label;
}

enum AppLanguage {
  system('System Default (English)'),
  english('English'),
  hindi('हिन्दी (Hindi)'),
  spanish('Español (Spanish)'),
  french('Français (French)'),
  german('Deutsch (German)'),
  portuguese('Português (Portuguese)'),
  japanese('日本語 (Japanese)');

  const AppLanguage(this.label);
  final String label;

  /// English display name.
  String get displayName => switch (this) {
        AppLanguage.system => 'System Default',
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'Hindi',
        AppLanguage.spanish => 'Spanish',
        AppLanguage.french => 'French',
        AppLanguage.german => 'German',
        AppLanguage.portuguese => 'Portuguese',
        AppLanguage.japanese => 'Japanese',
      };

  /// Native-script name.
  String get nativeName => switch (this) {
        AppLanguage.system => 'Follows device language',
        AppLanguage.english => 'English',
        AppLanguage.hindi => 'हिन्दी',
        AppLanguage.spanish => 'Español',
        AppLanguage.french => 'Français',
        AppLanguage.german => 'Deutsch',
        AppLanguage.portuguese => 'Português',
        AppLanguage.japanese => '日本語',
      };
}

enum EqPreset {
  rock('Rock', [5, 4, 3, 1, -1, -1, 1, 3, 4, 5]),
  pop('Pop', [-1, 1, 3, 4, 3, 1, 0, -1, -1, -2]),
  jazz('Jazz', [3, 2, 1, 2, -2, -2, 0, 1, 2, 3]),
  movie('Movie', [4, 6, 2, -2, -4, -1, 3, 5, 7, 5]),
  voice('Voice', [-4, -3, -1, 2, 4, 5, 4, 2, 0, -2]),
  custom('Custom', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

  const EqPreset(this.label, this.gains);
  final String label;
  final List<double> gains;
}

/// 10-band frequencies displayed under the equalizer sliders.
final List<String> kEqBandLabels = [
  '31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k',
];

enum RepeatMode {
  off('Repeat off'),
  all('Repeat all'),
  one('Repeat one');

  const RepeatMode(this.label);
  final String label;
}
