package com.mako.sourcecrush

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Small bridge for the handful of platform facts Dart cannot discover itself.
 *
 * Right now that is just [applicationInfo.nativeLibraryDir]: Android does not
 * allow executing files from the app's data directory (W^X), so helper binaries
 * such as ffmpeg have to be shipped inside the APK and run from the native
 * library directory instead.
 */
class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL = "com.mako.sourcecrush/native"
    }
}
