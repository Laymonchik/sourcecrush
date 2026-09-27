package com.mako.sourcecrush

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Host activity for the Flutter app.
 *
 * Extends [AudioServiceActivity] because audio_service requires it: a plain
 * FlutterActivity makes the plugin fail to attach to the engine.
 */
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null
    private var folders: MusicFolders? = null
    private var mediaInfo: MediaInfoBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val folderHandler = MusicFolders(this, ch)
        // Decoding audio for waveforms is far too slow for the platform thread.
        val mediaHandler = MediaInfoBridge(this, MediaInfo(this))

        ch.setMethodCallHandler(object : MethodChannel.MethodCallHandler {
            override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                when (call.method) {
                    // Read straight off the ApplicationInfo; no I/O needed.
                    "nativeLibraryDir" ->
                        result.success(applicationInfo.nativeLibraryDir)
                    else -> {
                        val handled = folderHandler.onMethodCall(call, result)
                        if (!handled) mediaHandler.onMethodCall(call, result)
                    }
                }
            }
        })

        channel = ch
        folders = folderHandler
        mediaInfo = mediaHandler
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Give the folder picker first refusal; anything else falls through to
        // the default handling.
        if (folders?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        folders?.dispose()
        mediaInfo?.dispose()
        folders = null
        mediaInfo = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "com.mako.sourcecrush/native"
    }
}

/**
 * Runs [MediaInfo] off the UI thread and always replies on it.
 *
 * Both metadata reads and waveform decoding can take a noticeable amount of
 * time - decoding tens of seconds of audio is real work - so neither may run
 * inline with a method call.
 */
private class MediaInfoBridge(
    private val activity: MainActivity,
    private val mediaInfo: MediaInfo,
) : MethodChannel.MethodCallHandler {

    private val io = Executors.newFixedThreadPool(2)

    fun dispose() {
        io.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readMetadata" -> {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrBlank()) {
                    result.error("bad_args", "uri is required", null)
                } else {
                    runAsync(result) { mediaInfo.readMetadata(uri) }
                }
            }
            "readWaveform" -> {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrBlank()) {
                    result.error("bad_args", "uri is required", null)
                } else {
                    val buckets = call.argument<Int>("buckets") ?: DEFAULT_BUCKETS
                    runAsync(result) {
                        val peaks = mediaInfo.readWaveform(uri, buckets)
                        mapOf("peaks" to (peaks ?: emptyList<Float>()))
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            // Catch Throwable so an Error still produces a reply rather than
            // leaving the Dart future unresolved forever.
            val outcome = try {
                Outcome.Success(block())
            } catch (t: Throwable) {
                Outcome.Failure(t.toString())
            }
            activity.runOnUiThread {
                when (outcome) {
                    is Outcome.Success -> result.success(outcome.value)
                    is Outcome.Failure ->
                        result.error("media_failed", outcome.reason, null)
                }
            }
        }
    }

    private sealed interface Outcome {
        data class Success(val value: Any?) : Outcome
        data class Failure(val reason: String) : Outcome
    }

    private companion object {
        const val DEFAULT_BUCKETS = 96
    }
}
