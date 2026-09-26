import 'package:flutter/services.dart';

/// Thin bridge to the few Android platform facts Dart cannot query itself.
class NativeBridge {
  const NativeBridge();

  static const _channel = MethodChannel('com.mako.sourcecrush/native');

  /// Directory the package manager extracted the APK's native libraries to,
  /// e.g. `/data/app/~~hash/com.mako.sourcecrush-hash/lib/arm64`.
  ///
  /// Unlike the app's data directory this location is executable, which is why
  /// helper binaries are shipped as jniLibs rather than as assets.
  Future<String?> nativeLibraryDir() => _channel.invokeMethod<String>('nativeLibraryDir');
}
