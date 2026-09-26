package com.mako.sourcecrush

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Storage Access Framework plumbing for user-picked music folders.
 *
 * The app deliberately does not scan the whole device: the user grants access
 * to specific directories, that grant is persisted, and only those trees are
 * enumerated. That keeps the library free of ringtones, voice memos, podcasts
 * and duplicate rips scattered across /sdcard.
 */
class MusicFolders(
    private val activity: Activity,
    channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    private val io = Executors.newSingleThreadExecutor()
    private var pendingPick: MethodChannel.Result? = null

    /** Extensions to accept as a fallback when a provider reports no MIME type. */
    private val audioExtensions = setOf(
        "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "oga",
        "webm", "mp4", "mka", "wma", "aiff", "aif", "ape", "wv", "tta",
    )

    fun dispose() {
        io.shutdown()
        pendingPick = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickMusicFolder" -> pickFolder(result)
            "listAudioIn" -> {
                val treeUri = call.argument<String>("treeUri")
                if (treeUri.isNullOrBlank()) {
                    result.error("bad_args", "treeUri is required", null)
                } else {
                    // An empty relativeDir means the picked folder's contents.
                    val relativeDir = call.argument<String>("relativeDir") ?: ""
                    listAudio(treeUri, relativeDir, result)
                }
            }
            "hasFolderAccess" -> {
                val treeUri = call.argument<String>("treeUri")
                result.success(treeUri != null && hasAccess(treeUri))
            }
            "releaseFolder" -> {
                val treeUri = call.argument<String>("treeUri")
                if (treeUri != null) releaseAccess(treeUri)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("in_progress", "a folder picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        try {
            activity.startActivityForResult(intent, REQUEST_PICK_FOLDER)
        } catch (e: Exception) {
            pendingPick = null
            result.error("no_picker", e.message, null)
        }
    }

    /**
     * Called from the activity's onActivityResult. Returns true when the result
     * belonged to the folder picker and has been consumed.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }

        // Persist so the grant survives reboots. Without this the folder stops
        // working after the process restarts.
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Some providers do not offer persistable grants; the grant then
            // lasts until the process dies, which is still usable.
        }
        result.success(uri.toString())
        return true
    }

    private fun hasAccess(treeUri: String): Boolean {
        val uri = Uri.parse(treeUri)
        return activity.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }
    }

    private fun releaseAccess(treeUri: String) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                Uri.parse(treeUri),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: Exception) {
            // Already revoked; nothing to do.
        }
    }

    private fun listAudio(
        treeUri: String,
        relativeDir: String,
        result: MethodChannel.Result,
    ) {
        io.execute {
            // Enumerate off the UI thread but always reply on it:
            // MethodChannel.Result must be invoked on the platform thread.
            // Catch Throwable rather than Exception so an Error still produces
            // a reply instead of leaving Dart waiting forever.
            val outcome = try {
                Outcome.Success(listFolder(Uri.parse(treeUri), relativeDir))
            } catch (t: Throwable) {
                Outcome.Failure(t.toString())
            }
            activity.runOnUiThread {
                when (outcome) {
                    is Outcome.Success -> result.success(outcome.files)
                    is Outcome.Failure ->
                        result.error("scan_failed", outcome.reason, null)
                }
            }
        }
    }

    private sealed interface Outcome {
        data class Success(val files: List<Map<String, Any?>>) : Outcome
        data class Failure(val reason: String) : Outcome
    }

    /**
     * Lists one directory level inside the granted tree.
     *
     * Deliberately non-recursive. A picked folder can hold thousands of files
     * and walking it depth-first on the DocumentsProvider takes far longer than
     * a UI can wait (measured: it blew past 45s on a normal music folder).
     * One level per call keeps each round trip fast, and the Dart side decides
     * how far to descend.
     */
    private fun listFolder(treeUri: Uri, relativeDir: String): List<Map<String, Any?>> {
        val found = mutableListOf<Map<String, Any?>>()

        val childrenUri = try {
            val documentId = childDocumentId(treeUri, relativeDir)
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId)
        } catch (e: Exception) {
            return found
        }

        activity.contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val modCol = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)

            while (cursor.moveToNext()) {
                val docId = if (idCol >= 0) cursor.getString(idCol) else continue
                val name = if (nameCol >= 0) cursor.getString(nameCol) ?: "" else ""
                val mime = if (mimeCol >= 0) cursor.getString(mimeCol) ?: "" else ""
                val size = if (sizeCol >= 0 && !cursor.isNull(sizeCol)) cursor.getLong(sizeCol) else 0L
                val modified =
                    if (modCol >= 0 && !cursor.isNull(modCol)) cursor.getLong(modCol) else 0L

                val childUri =
                    DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                val relativePath =
                    if (relativeDir.isEmpty()) name else "$relativeDir/$name"
                val isDirectory = mime == DocumentsContract.Document.MIME_TYPE_DIR

                if (isDirectory || isAudio(name, mime)) {
                    found.add(
                        mapOf(
                            "uri" to childUri.toString(),
                            "name" to name,
                            "relativePath" to relativePath,
                            "isDirectory" to isDirectory,
                            "size" to if (isDirectory) 0L else size,
                            "lastModified" to modified,
                        ),
                    )
                }
            }
        }
        return found
    }

    /**
     * Resolves a path relative to the picked root into a document id.
     *
     * SAF only grants a real tree URI, so subfolders have to be addressed by
     * document id (`primary:Music/Rock`) rather than by an arbitrary child URI.
     */
    private fun childDocumentId(treeUri: Uri, relativeDir: String): String {
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        if (relativeDir.isEmpty()) return rootId
        val separator = if (rootId.endsWith("/")) "" else "/"
        return "$rootId$separator${relativeDir.trimStart('/')}"
    }

    private fun isAudio(name: String, mime: String): Boolean {
        if (mime.startsWith("audio/")) return true
        val ext = name.substringAfterLast('.', "").lowercase()
        return ext.isNotEmpty() && ext in audioExtensions
    }

    companion object {
        private const val REQUEST_PICK_FOLDER = 0x5C1
    }
}
