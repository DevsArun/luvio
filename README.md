# Luvio Player

A premium, tablet-first offline video player for **Amazon Fire tablets** (Fire OS / Android),
built with **Flutter + Material Design 3** and the Luvio design system.

> Your movies. Beautifully played. — Version 2.4.1 (Build 4902)

---

## Features

- **Media library** — automatic storage scanning (internal + SD card), folders, search with recent
  searches, continue watching, recently added, grid/list views, sorting.
- **Premium video player** — media_kit engine (plays every major format: MP4, MKV, AVI, MOV, WEBM,
  FLV, TS, 3GP…), subtitles (embedded + external .srt/.ass/.ssa/.vtt/.sub), multiple audio tracks,
  playback speed, aspect ratio (fit/crop/stretch), mirror, AB repeat, screen lock, background
  playback, hardware/software decoder switching.
- **Gestures** — brightness (left), volume (right), horizontal seek scrubbing, double-tap seek with
  ripple feedback; every gesture individually configurable.
- **Picture-in-Picture** — draggable, resizable in-app PiP window with transport controls.
- **Equalizer** — 10-band EQ with presets (Rock, Pop, Jazz, Movie, Voice, Custom), master gain,
  bass boost, virtualizer.
- **Private Vault** — hide videos behind a 4-digit PIN (SHA-256 hashed) with fingerprint unlock
  (local_auth); auto-locks in background.
- **Playlists** — favorites + custom playlists with icons, reordering, play-all queueing.
- **Extras** — sleep timer with glowing ring dial, subtitle manager with live preview, file
  information dialog with codec probing, scan storage screen with radar animation, feedback,
  about, language selection (8 languages).

## Project structure

```
luvio_player/
├─ pubspec.yaml
├─ analysis_options.yaml
├─ android/                      # Gradle config, manifest, MainActivity (storage MethodChannel)
└─ lib/
   ├─ main.dart                  # Bootstrap (media_kit init, orientation, edge-to-edge)
   ├─ app.dart                   # MultiProvider + MaterialApp + PiP overlay host
   ├─ core/
   │  ├─ theme/                  # AppColors, AppTypography, AppTheme (M3 dark)
   │  ├─ constants/              # Spacing, radius, motion tokens
   │  ├─ utils/                  # Formatters (duration, bytes, dates, badges)
   │  └─ routes.dart             # Route table + PlayerScreenArgs
   ├─ models/                    # VideoItem, MediaFolder, Playlist, StorageVolume, enums
   ├─ services/                  # Preferences, media library scan, thumbnails, metadata probe,
   │                             # vault (PIN hashing), permissions
   ├─ providers/                 # Settings, Library, Playlist, Vault, Player (ChangeNotifier)
   ├─ widgets/
   │  ├─ common/                 # GlassPanel, CircleIconButton, BadgeChip, SectionHeader, EmptyState
   │  ├─ media/                  # VideoCard, VideoListTile, FolderCard, ContinueWatchingCard, thumbs
   │  ├─ shell/                  # SideNavBar (288px), TopBar (80px glass)
   │  └─ pip/                    # Draggable/resizable PiP overlay
   └─ screens/
      ├─ splash/  onboarding/  home/  folders/  videos/  search/
      ├─ player/                 # Fullscreen player (gestures, AB repeat, tracks, seek bar)
      ├─ playlists/  vault/  equalizer/  settings/  scan/  about/
      └─ dialogs/                # Sleep timer, file info, options sheet, playlist dialogs,
                                 # rename/delete confirms, feedback
```

## Getting started

```bash
flutter pub get
flutter run          # device/emulator connected
flutter build apk    # release APK for sideloading onto a Fire tablet
```

### Inter font (recommended)

The Luvio design system uses **Inter**. The app falls back to the system font if Inter isn't bundled.
To bundle it:

1. Download Inter from <https://rsms.me/inter/> (or Google Fonts).
2. Drop `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf` into
   `assets/fonts/`.
3. Uncomment the `fonts:` block at the bottom of `pubspec.yaml`.
4. Run `flutter pub get` again.

## Fire tablet notes

- **minSdk 21** — covers every Fire OS 5+ tablet (Fire 7, HD 8, HD 10, Max 11).
- **Storage volumes** — internal + SD card discovery via a native `MethodChannel`
  (`luvio_player/storage`) in `MainActivity.kt`; SD cards are common on Fire tablets.
- **Permissions** — `READ_MEDIA_VIDEO` on Android 13+, `READ_EXTERNAL_STORAGE` on older
  Fire OS versions (handled automatically by the permission service).
- **PiP** — implemented as an in-app overlay window (drag, resize, transport controls), since many
  Fire OS builds restrict system PiP for sideloaded apps. `supportsPictureInPicture` is also
  declared for devices that allow it.
- **Hardware acceleration** — decoder mode (HW / HW+ / SW) maps to mpv `hwdec` via media_kit,
  ideal for the MediaTek SoCs in Fire tablets.

## Key dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `media_kit` / `media_kit_video` / `media_kit_libs_video` | Playback engine (all formats, tracks, subtitles) |
| `shared_preferences` | Settings & library index persistence |
| `permission_handler` / `device_info_plus` | Media permission flow per Android version |
| `local_auth` / `crypto` | Vault fingerprint unlock + PIN hashing |
| `screen_brightness` / `wakelock_plus` | Player gestures & keep-awake |
| `video_thumbnail` | Library thumbnails |
| `file_picker` / `share_plus` | External subtitles, share & feedback |
| `intl` | Date formatting |

---

© 2026 Luvio Labs. All rights reserved.
