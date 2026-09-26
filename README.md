# sourcecrush

An Android music player built with Flutter. Playback runs through `just_audio`
(via ExoPlayer) with `audio_service` for background/lock-screen controls.
The download/transcode backend (ffmpeg + yt-dlp) is the next milestone.

## Layout

```
lib/
  main.dart                        app entry, audio_service bootstrap
  src/
    audio/sourcecrush_audio_handler.dart   owns the AudioPlayer, mirrors state
                                          into audio_service (notification,
                                          lock screen, headset buttons)
    library/library_repository.dart        scans <app docs>/music for audio
    models/track.dart                      one playable item
    player_controller.dart                 ChangeNotifier facade for the UI
    ui/home_screen.dart                    library list + mini player
    ui/now_playing_screen.dart             full screen player
android/app/src/main/kotlin/.../MainActivity.kt
                                    extends AudioServiceActivity (required by
                                    audio_service)
```

## Development

Toolchain lives in `~/toolchain` (no root needed). `~/.sc-env.sh` is sourced
from `~/.bashrc` and sets `JAVA_HOME`, `ANDROID_HOME`, `GRADLE_USER_HOME` and
`PATH`:

```bash
source ~/.sc-env.sh
flutter run -d <device>
```

Notes for this machine:

- `org.gradle.jvmargs` is trimmed to `-Xmx2G`; the Flutter template default of
  `-Xmx8G` thrashes on 8 GB of RAM.
- `GRADLE_USER_HOME` points at the pre-warmed `~/toolchain/gradle-home`, which
  already has the Gradle 9.3.1 distribution.
- Android NDK r28c is installed (pulled in by AGP).

### Hot reload without a foreground terminal

`flutter run` is driven through a FIFO so it can stay detached:

```bash
echo r > /tmp/opencode/flutter-stdin   # hot reload
echo R > /tmp/opencode/flutter-stdin   # hot restart
echo q > /tmp/opencode/flutter-stdin   # quit
```

Rebuilds are required (not just reload) after changing
`android/app/src/main/AndroidManifest.xml`, `pubspec.yaml` or Kotlin sources.

### Demo tracks

`assets/demo/` holds three generated clips. In debug builds `main()` copies them
into the app's music directory on startup (`LibraryRepository.seedDemoTracks`),
which exercises the same "write a file, then rescan" path the download pipeline
will use. Release builds skip the seeding (`kDebugMode` guard).

The device used for testing blocks `run-as` (SELinux), so files cannot be pushed
into the app's private storage from adb — hence the asset-based seeding.

## Tests

```bash
flutter test        # filename parsing in LibraryRepository
flutter analyze
```
