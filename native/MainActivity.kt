package com.example.subtitle_studio_ai

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaCodec
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val audioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "subtitle_studio/audio")
            .setMethodCallHandler { call, result ->
                if (call.method != "extractChunk") {
                    result.notImplemented()
                } else {
                    val path = call.argument<String>("path")
                    val start = call.argument<Number>("startUs")?.toLong() ?: 0L
                    if (path == null || start < 0) {
                        result.error("INVALID_INPUT", "Videoja nuk është zgjedhur.", null)
                    } else {
                        audioExecutor.execute {
                            try {
                                val chunk = extractChunk(path, start)
                                runOnUiThread { result.success(chunk) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("AUDIO_EXTRACTION", error.message ?: "Nxjerrja e audios dështoi.", null)
                                }
                            }
                        }
                    }
                }
            }
    }

    private fun extractChunk(path: String, startUs: Long): Map<String, Any> {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var output: File? = null
        var completed = false
        try {
            val source = File(path)
            if (!source.isFile || !source.canRead()) throw FileNotFoundException("Videoja nuk gjendet ose nuk mund të lexohet.")
            extractor.setDataSource(source.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw IllegalArgumentException("Videoja nuk ka pistë audio.")
            val format = extractor.getTrackFormat(track)
            require(format.getString(MediaFormat.KEY_MIME) == "audio/mp4a-latm") {
                "Kjo pistë audio nuk është AAC. Përdor video MP4 me audio AAC."
            }
            extractor.selectTrack(track)
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            while (extractor.sampleTime >= 0 && extractor.sampleTime < startUs) extractor.advance()
            if (extractor.sampleTime < 0) return mapOf("done" to true, "nextUs" to startUs)
            val firstUs = extractor.sampleTime
            output = File.createTempFile("ssai_audio_", ".m4a", cacheDir)
            val writer = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = writer
            val destination = writer.addTrack(format)
            writer.start()
            val buffer = ByteBuffer.allocate(2 * 1024 * 1024)
            val info = MediaCodec.BufferInfo()
            var bytes = 0L
            while (extractor.sampleTime >= 0) {
                val timestamp = extractor.sampleTime
                if (timestamp >= firstUs + 180_000_000L || bytes >= 20L * 1024 * 1024) break
                require(extractor.sampleSize <= buffer.capacity()) { "Paketa audio është tepër e madhe." }
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                info.set(0, size, timestamp - firstUs, extractor.sampleFlags)
                writer.writeSampleData(destination, buffer, info)
                bytes += size
                extractor.advance()
            }
            require(bytes > 0L) { "Nuk u gjet audio në segmentin e kërkuar." }
            val next = extractor.sampleTime
            // Never return a cursor that cannot advance: Flutter may request chunks in a loop.
            require(next < 0 || next > startUs) { "Segmenti audio nuk përparoi; provo një video tjetër." }
            writer.stop()
            writer.release()
            muxer = null
            completed = true
            return mapOf("path" to output.absolutePath, "offsetUs" to firstUs,
                "nextUs" to if (next < 0) firstUs + 180_000_000L else next, "done" to (next < 0))
        } finally {
            try { muxer?.release() } catch (_: Exception) {}
            extractor.release()
            if (!completed) output?.delete()
        }
    }
}
