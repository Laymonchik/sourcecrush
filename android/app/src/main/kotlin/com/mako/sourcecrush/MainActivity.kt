package com.mako.sourcecrush

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity for the Flutter app.
 *
 * Extends [AudioServiceActivity] because audio_service requires it: a plain
 * FlutterActivity makes the plugin fail to attach to the engine.
 */
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var folders: MusicFolders? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val folderHandler = MusicFolders(this, ch)

        ch.setMethodCallHandler(object : MethodChannel.MethodCallHandler {
            override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                when (call.method) {
                    // Handled here rather than in MusicFolders because it needs
                    // no I/O and reads straight off the ApplicationInfo.
                    "nativeLibraryDir" ->
                        result.success(applicationInfo.nativeLibraryDir)
                    else -> folderHandler.onMethodCall(call, result)
                }
            }
        })

        channel = ch
        folders = folderHandler
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Give the folder picker first refusal; anything else falls through to
        // the default handling.
        if (folders?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        folders?.dispose()
        folders = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "com.mako.sourcecrush/native"
    }
}
