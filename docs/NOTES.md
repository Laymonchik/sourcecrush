# sourcecrush — design notes

Decisions and measurements that are not obvious from the code.

## Playing audio

`just_audio` (ExoPlayer) for decoding and `audio_service` for the foreground
service, lock screen and headset buttons. Two things `audio_service` requires
that are easy to miss:

- `MainActivity` must extend `AudioServiceActivity`, not `FlutterActivity`.
  Without it the plugin throws
  `IllegalStateException: The Activity class declared in your AndroidManifest.xml
  is wrong or has not provided the correct FlutterEngine` and
  `AudioService.init` fails.
- The service + `MediaButtonReceiver` entries in the manifest, plus
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.

## Running helper binaries (ffmpeg, and anything else that is exec'd)

Measured on the test device (Xiaomi, Android 16 / API 36, arm64-v8a):

| What                                          | Result                    |
| --------------------------------------------- | ------------------------- |
| `Process.run` of a system binary              | works                     |
| script written to the app's data dir + chmod  | `Permission denied`       |
| script on `/sdcard`                           | `Permission denied`       |
| binary shipped as a jniLib, run from `nativeLibraryDir` | works            |

Android's W^X rule means the app's data directory is not executable, so helper
binaries cannot be shipped as assets and copied out. They are shipped as
jniLibs instead, and the package manager extracts them to the app's native
library directory, which *is* executable.

Enabling that extraction is the subtle part:

```kotlin
packaging {
    jniLibs {
        useLegacyPackaging = true
    }
}
```

Without it AGP stores `.so` files uncompressed and page-aligned, loads them
straight from the APK (`android:extractNativeLibs=false`) and nothing ever
reaches the filesystem, so there is no file to exec. AGP 9 injects
`extractNativeLibs` itself and ignores the manifest attribute, so setting
`android:extractNativeLibs="true"` in `AndroidManifest.xml` has no effect —
the Gradle DSL is the only thing that works.

The native library directory is read through a small `MethodChannel`
(`NativeBridge.nativeLibraryDir`), since Dart cannot discover it.

### Build flags matter

`-static-pie` produces a binary that segfaults immediately on Android
(`exit=139`), both from `/data/local/tmp` and from the extracted lib dir. A
normal dynamically linked PIE executable — the NDK default — works:

```bash
$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang \
    -O2 -fPIE -pie -o libfoo.so foo.c
```

Verified variants: dynamic PIE ok, static non-PIE ok, static-pie segfaults.

## Toolchain on this machine

Flutter SDK, JDK 17 and the Gradle cache live under `~/flutter` and
`~/toolchain`; `~/.sc-env.sh` wires up the environment and is sourced from
`~/.bashrc`. No root and no pacman required.

`sudo` needs a password here, so system packages cannot be installed. The
Android NDK came from the SDK manager as a side effect of the first Gradle
build (r28c, 28.2.13676358).

## Testing on the device

`run-as` is blocked by this device's SELinux policy, so files cannot be pushed
into the app's private storage over adb. Demo clips are therefore bundled as
assets and copied into the music directory by the app itself in debug builds.
That deliberately uses the same "write a file, then rescan" path the download
pipeline will use.

`tool/dev.sh` wraps the `flutter run` loop (see README).
