package com.mako.sourcecrush

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Reads tags, cover art and waveform data straight out of audio files using
 * the platform APIs.
 *
 * Deliberately no ffmpeg here: [MediaMetadataRetriever] handles ID3/Vorbis/MP4
 * tags and embedded pictures, and [MediaExtractor] + [MediaCodec] decode to PCM
 * for the waveform. That keeps the common case working before any native
 * tooling is bundled, and a bundled ffmpeg can still be added later for
 * formats the platform decoder rejects.
 */
class MediaInfo(private val context: Context) {

    /**
     * Tags plus the dimensions of the embedded cover, if there is one.
     *
     * Artwork is returned as a JPEG in the app's cache directory rather than
     * base64 over the channel: a 1 MB cover does not belong in a method call.
     */
    fun readMetadata(uriString: String): Map<String, Any?> {
        val uri = Uri.parse(uriString)
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)

            val rawArt = retriever.embeddedPicture
            val artPath = if (rawArt != null) writeArtwork(uriString, rawArt) else null

            return mapOf(
                "title" to retriever.extract(MediaMetadataRetriever.METADATA_KEY_TITLE),
                "artist" to retriever.extract(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                "album" to retriever.extract(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                "albumArtist" to
                    retriever.extract(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST),
                "year" to retriever.extract(MediaMetadataRetriever.METADATA_KEY_YEAR),
                "trackNumber" to
                    retriever.extract(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER),
                "durationMs" to
                    retriever.extract(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toLongOrNull(),
                "hasArtwork" to (artPath != null),
                "artworkPath" to artPath,
            )
        } catch (e: Exception) {
            return mapOf("error" to e.toString())
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // Already released.
            }
        }
    }

    private fun MediaMetadataRetriever.extract(key: Int): String? =
        extractMetadata(key)?.trim()?.takeIf { it.isNotEmpty() }

    /**
     * Downsamples embedded art and caches it as JPEG.
     *
     * Embedded pictures are frequently 1000x1000 or larger; the UI only ever
     * shows a few hundred logical pixels, so the original is wasted memory
     * once decoded into a Flutter texture.
     */
    private fun writeArtwork(sourceUri: String, bytes: ByteArray): String? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)

            val longest = max(bounds.outWidth, bounds.outHeight)
            var sample = 1
            while (longest / sample > MAX_ART_EDGE) sample *= 2

            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, decodeOptions)
                ?: return null

            val dir = java.io.File(context.cacheDir, ART_DIR).apply { mkdirs() }
            val file = java.io.File(dir, "${sourceUri.hashCode().toUInt().toString(16)}.jpg")

            java.io.FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
            }
            bitmap.recycle()
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Decodes the audio to PCM and reduces it to [buckets] peak amplitudes in
     * 0..1, which is what the waveform view draws.
     *
     * Runs on a background thread and is bounded by [MAX_WAVEFORM_SECONDS] of
     * audio: a five minute track is far more than the visual needs, and
     * decoding all of it makes adding a track to the library feel slow.
     */
    fun readWaveform(uriString: String, buckets: Int): List<Float>? {
        val uri = Uri.parse(uriString)
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null
        try {
            extractor = MediaExtractor().apply { setDataSource(context, uri, null) }

            var trackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(i)
                val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    trackIndex = i
                    format = candidate
                    break
                }
            }
            if (trackIndex < 0 || format == null) return null

            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            extractor.selectTrack(trackIndex)

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val peaks = FloatArray(buckets)
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val totalSamples = sampleRate.toLong() * MAX_WAVEFORM_SECONDS
            val samplesPerBucket = max(1L, totalSamples / buckets)

            var bucketIndex = 0
            var samplesInBucket = 0L
            var bucketPeak = 0f
            var samplesRead = 0L
            var sawInputEos = false
            var sawOutputEos = false
            var sumSquares = 0.0
            var counted = 0

            val info = MediaCodec.BufferInfo()
            var bufferIndex = 0

            while (!sawOutputEos) {
                if (!sawInputEos) {
                    bufferIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (bufferIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(bufferIndex)!!
                        val size = extractor.readSampleData(inputBuffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                bufferIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(
                                bufferIndex, 0, size, extractor.sampleTime, 0,
                            )
                            extractor.advance()
                        }
                    }
                }

                when (val outputIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)) {
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        // Nothing ready; loop round.
                    }
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        // Nothing needed beyond the track format.
                    }
                    else -> {
                        if (outputIndex >= 0) {
                            val outputBuffer = codec.getOutputBuffer(outputIndex)
                            if (outputBuffer != null && info.size > 0) {
                                outputBuffer.position(info.offset)
                                outputBuffer.limit(info.offset + info.size)

                                val shorts = ShortArray(info.size / 2)
                                outputBuffer.asShortBuffer().get(shorts)

                                // Downmix to mono so a stereo track does not
                                // double the effective sample count.
                                val step = if (channelCount > 1) 2 else 1
                                var i = 0
                                while (i < shorts.size) {
                                    var sample = 0
                                    var c = 0
                                    while (c < channelCount && i + c < shorts.size) {
                                        sample += shorts[i + c]
                                        c += step
                                    }
                                    val normalised =
                                        abs(sample.toFloat() / Short.MAX_VALUE)
                                    if (normalised > bucketPeak) bucketPeak = normalised
                                    sumSquares += normalised.toDouble() * normalised
                                    counted++
                                    samplesInBucket++
                                    samplesRead++
                                    i += step
                                    if (samplesInBucket >= samplesPerBucket) {
                                        peaks[bucketIndex] = bucketPeak
                                        bucketIndex++
                                        bucketPeak = 0f
                                        samplesInBucket = 0
                                        if (bucketIndex >= buckets || samplesRead >= totalSamples) {
                                            sawOutputEos = true
                                            break
                                        }
                                    }
                                }
                            }
                            codec.releaseOutputBuffer(outputIndex, false)
                            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                sawOutputEos = true
                            }
                        }
                    }
                }
            }

            // Flush whatever the last partial bucket held.
            if (bucketIndex < buckets && bucketPeak > 0f) {
                peaks[bucketIndex] = bucketPeak
                bucketIndex++
            }
            if (bucketIndex == 0) return null

            // Normalise so quiet tracks still render a readable waveform.
            val loudest = peaks.take(bucketIndex).maxOrNull() ?: 0f
            val rms = if (counted > 0) sqrt(sumSquares / counted).toFloat() else 0f
            val reference = max(loudest, rms * 3f)
            if (reference <= 0f) return null

            return List(bucketIndex) { i ->
                min(1f, sqrt(peaks[i].toDouble()).toFloat() / reference)
            }
        } catch (e: Exception) {
            return null
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
                // Never started.
            }
            try {
                codec?.release()
            } catch (_: Exception) {
                // Already released.
            }
            try {
                extractor?.release()
            } catch (_: Exception) {
                // Already released.
            }
        }
    }

    companion object {
        private const val ART_DIR = "cover_art"
        private const val MAX_ART_EDGE = 1024

        /** Upper bound on audio decoded for the waveform. */
        private const val MAX_WAVEFORM_SECONDS = 600L
        private const val TIMEOUT_US = 10_000L
    }
}
