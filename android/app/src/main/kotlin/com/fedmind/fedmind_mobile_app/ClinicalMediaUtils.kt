package com.fedmind.fedmind_mobile_app

import android.app.Activity
import android.media.AudioAttributes
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import kotlin.math.max

/**
 * Utilitas media native untuk:
 * 1) Menjaga layar tetap menyala selama perekaman klinis (FLAG_KEEP_SCREEN_ON).
 * 2) Menggabungkan (mux) audio WAV hasil MicSession ke berkas .mp4 secara lossless
 *    untuk video track, tanpa menyentuh file WAV sidecar yang dipakai ekstraktor model.
 * 3) Memutar ulang berkas audio (.wav / .mp4) untuk telaah klinisi pada Hasil & History.
 */
object ClinicalMediaUtils {
    private const val tag = "ClinicalMediaUtils"

    fun setKeepScreenOn(activity: Activity, enabled: Boolean) {
        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (enabled) {
            activity.window.addFlags(flag)
        } else {
            activity.window.clearFlags(flag)
        }
    }

    /** Memeriksa apakah berkas media memiliki track audio. */
    fun hasAudioTrack(mediaPath: String): Boolean {
        val file = File(mediaPath)
        if (!file.exists() || file.length() <= 0L) return false
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(mediaPath)
            for (i in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) return true
            }
            false
        } catch (e: Exception) {
            Log.w(tag, "hasAudioTrack failed: ${e.message}")
            false
        } finally {
            try { extractor.release() } catch (_: Exception) {}
        }
    }

    /**
     * Menggabungkan audio PCM16 WAV ke dalam berkas MP4 video-only menggunakan MediaMuxer.
     * Track video disalin langsung (tanpa re-encode), sehingga kualitas frame visual untuk
     * MediaPipe tetap identik, sementara berkas WAV asli juga tetap dipertahankan utuh.
     */
    fun muxWavIntoMp4(videoPath: String, wavPath: String): Boolean {
        val videoFile = File(videoPath)
        val wavFile = File(wavPath)
        if (!videoFile.exists() || !wavFile.exists() || wavFile.length() <= 44L) {
            return false
        }
        if (hasAudioTrack(videoPath)) {
            return true
        }

        val tempOut = File(videoFile.parentFile, "${videoFile.nameWithoutExtension}.muxtmp.mp4")
        if (tempOut.exists()) tempOut.delete()

        val extractor = MediaExtractor()
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var wavStream: FileInputStream? = null
        var muxerStarted = false

        try {
            extractor.setDataSource(videoPath)
            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i
                    videoFormat = fmt
                    break
                }
            }
            if (videoTrackIndex < 0 || videoFormat == null) {
                return false
            }

            val rotationDeg = resolveVideoRotation(videoPath, videoFormat)
            val videoDurationUs = if (videoFormat.containsKey(MediaFormat.KEY_DURATION)) {
                videoFormat.getLong(MediaFormat.KEY_DURATION)
            } else {
                0L
            }

            val wavInfo = readWavHeaderInfo(wavFile)
            val sampleRate = wavInfo.sampleRate
            val channels = wavInfo.channels
            val bytesPerSecond = sampleRate.toLong() * channels * 2L
            val rawPcmBytes = (wavFile.length() - 44L).coerceAtLeast(0L)
            val maxAudioBytes = if (videoDurationUs > 0L) {
                val allowedUs = videoDurationUs + 150_000L
                val maxByVideo = (allowedUs * bytesPerSecond) / 1_000_000L
                minOf(rawPcmBytes, maxByVideo).let { it - (it % (channels * 2L)) }
            } else {
                rawPcmBytes
            }
            if (maxAudioBytes <= 0L) return false

            val audioInFormat = MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                sampleRate,
                channels
            ).apply {
                setInteger(
                    MediaFormat.KEY_AAC_PROFILE,
                    MediaCodecInfo.CodecProfileLevel.AACObjectLC
                )
                setInteger(MediaFormat.KEY_BIT_RATE, 64000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }

            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            encoder.configure(audioInFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()

            val activeMuxer = MediaMuxer(
                tempOut.absolutePath,
                MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
            )
            muxer = activeMuxer
            if (rotationDeg != 0) {
                activeMuxer.setOrientationHint(rotationDeg)
            }
            val muxVideoTrack = activeMuxer.addTrack(videoFormat)
            var muxAudioTrack = -1

            wavStream = FileInputStream(wavFile)
            var skipped = 0L
            while (skipped < 44L) {
                val n = wavStream.skip(44L - skipped)
                if (n <= 0L) break
                skipped += n
            }

            var bytesFed = 0L
            var inputDone = false
            var outputDone = false
            val bufferInfo = MediaCodec.BufferInfo()
            val pcmChunk = ByteArray(4096)
            var lastAudioPtsUs = -1L

            // Buffering singkat sebelum INFO_OUTPUT_FORMAT_CHANGED agar activeMuxer.start() valid
            val pendingAudioPackets = ArrayList<Pair<ByteArray, MediaCodec.BufferInfo>>()

            fun recordAudioPacket(outBuf: ByteBuffer, info: MediaCodec.BufferInfo) {
                if ((info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0 || info.size <= 0) {
                    return
                }
                val pts = max(lastAudioPtsUs + 1L, info.presentationTimeUs)
                lastAudioPtsUs = pts
                val copyInfo = MediaCodec.BufferInfo().apply {
                    set(0, info.size, pts, info.flags)
                }
                val bytes = ByteArray(info.size)
                outBuf.position(info.offset)
                outBuf.limit(info.offset + info.size)
                outBuf.get(bytes)
                if (muxerStarted && muxAudioTrack >= 0) {
                    activeMuxer.writeSampleData(muxAudioTrack, ByteBuffer.wrap(bytes), copyInfo)
                } else {
                    pendingAudioPackets.add(bytes to copyInfo)
                }
            }

            // Encode seluruh WAV (ukuran terkompresi kecil, atau langsung tulis begitu activeMuxer mulai)
            while (!outputDone) {
                if (!inputDone) {
                    val inIdx = encoder.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = encoder.getInputBuffer(inIdx)!!
                        inBuf.clear()
                        val remaining = (maxAudioBytes - bytesFed).coerceAtLeast(0L)
                        val toRead = minOf(
                            pcmChunk.size.toLong(),
                            inBuf.capacity().toLong(),
                            remaining
                        ).toInt()
                        val readBytes = if (toRead > 0) wavStream.read(pcmChunk, 0, toRead) else -1
                        if (readBytes <= 0) {
                            val eosPts = (bytesFed * 1_000_000L) / bytesPerSecond
                            encoder.queueInputBuffer(
                                inIdx, 0, 0, eosPts, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            val samplePts = (bytesFed * 1_000_000L) / bytesPerSecond
                            inBuf.put(pcmChunk, 0, readBytes)
                            encoder.queueInputBuffer(inIdx, 0, readBytes, samplePts, 0)
                            bytesFed += readBytes
                        }
                    }
                }

                val outIdx = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (!muxerStarted) {
                            muxAudioTrack = activeMuxer.addTrack(encoder.outputFormat)
                            activeMuxer.start()
                            muxerStarted = true
                            // Salin seluruh track video terlebih dahulu sebelum sisa paket audio,
                            // atau tulis pending packet dulu lalu lanjut
                            for ((bytes, info) in pendingAudioPackets) {
                                activeMuxer.writeSampleData(muxAudioTrack, ByteBuffer.wrap(bytes), info)
                            }
                            pendingAudioPackets.clear()
                        }
                    }
                    outIdx >= 0 -> {
                        val outBuf = encoder.getOutputBuffer(outIdx)
                        if (outBuf != null) {
                            recordAudioPacket(outBuf, bufferInfo)
                        }
                        encoder.releaseOutputBuffer(outIdx, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }
                    }
                }
            }

            if (!muxerStarted || muxAudioTrack < 0) {
                return false
            }

            // Salin seluruh frame video secara lossless
            extractor.selectTrack(videoTrackIndex)
            val maxVideoBufSize = if (videoFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                max(videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE), 512 * 1024)
            } else {
                1024 * 1024
            }
            val videoBuf = ByteBuffer.allocate(maxVideoBufSize)
            val videoInfo = MediaCodec.BufferInfo()
            var firstVideoPtsUs = -1L
            var lastVideoPtsUs = -1L

            while (true) {
                videoBuf.clear()
                val sampleSize = extractor.readSampleData(videoBuf, 0)
                if (sampleSize < 0) break

                val rawPts = extractor.sampleTime
                if (firstVideoPtsUs < 0L) {
                    firstVideoPtsUs = rawPts
                }
                val normalizedPts = max(lastVideoPtsUs + 1L, (rawPts - firstVideoPtsUs).coerceAtLeast(0L))
                lastVideoPtsUs = normalizedPts

                val extractorFlags = extractor.sampleFlags
                val codecFlags =
                    if ((extractorFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) {
                        MediaCodec.BUFFER_FLAG_KEY_FRAME
                    } else {
                        0
                    }

                videoInfo.set(0, sampleSize, normalizedPts, codecFlags)
                activeMuxer.writeSampleData(muxVideoTrack, videoBuf, videoInfo)
                extractor.advance()
            }

            activeMuxer.stop()
            activeMuxer.release()
            muxer = null

            if (!tempOut.exists() || tempOut.length() <= 0L || !hasAudioTrack(tempOut.absolutePath)) {
                tempOut.delete()
                return false
            }

            val backupOld = File(videoFile.parentFile, "${videoFile.nameWithoutExtension}.nomux.bak")
            if (backupOld.exists()) backupOld.delete()
            if (!videoFile.renameTo(backupOld)) {
                tempOut.delete()
                return false
            }
            if (!tempOut.renameTo(videoFile)) {
                backupOld.renameTo(videoFile)
                tempOut.delete()
                return false
            }
            backupOld.delete()
            return true
        } catch (e: Exception) {
            Log.e(tag, "muxWavIntoMp4 failed: ${e.message}", e)
            try { tempOut.delete() } catch (_: Exception) {}
            return false
        } finally {
            try { wavStream?.close() } catch (_: Exception) {}
            try { encoder?.stop() } catch (_: Exception) {}
            try { encoder?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
            try {
                if (muxerStarted) muxer?.stop()
            } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }

    private fun resolveVideoRotation(videoPath: String, format: MediaFormat): Int {
        if (format.containsKey(MediaFormat.KEY_ROTATION)) {
            return format.getInteger(MediaFormat.KEY_ROTATION)
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(videoPath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
        } catch (_: Exception) {
            0
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    private data class WavHeaderInfo(val sampleRate: Int, val channels: Int)

    private fun readWavHeaderInfo(wavFile: File): WavHeaderInfo {
        return try {
            val h = ByteArray(44)
            FileInputStream(wavFile).use { it.read(h) }
            val ch = ((h[23].toInt() and 0xff) shl 8) or (h[22].toInt() and 0xff)
            val rate = (h[24].toInt() and 0xff) or
                ((h[25].toInt() and 0xff) shl 8) or
                ((h[26].toInt() and 0xff) shl 16) or
                ((h[27].toInt() and 0xff) shl 24)
            WavHeaderInfo(
                sampleRate = if (rate in 8000..48000) rate else 16000,
                channels = if (ch in 1..2) ch else 1
            )
        } catch (_: Exception) {
            WavHeaderInfo(16000, 1)
        }
    }
}

/**
 * Pemutar audio native menggunakan MediaPlayer (mendukung langsung WAV PCM16 & MP4 AAC)
 * agar dokter/psikolog dapat mendengarkan ulang tuturan klien di halaman Hasil & History.
 */
class ClinicalAudioPlayer(
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val main = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var currentPath: String? = null
    private var isPrepared = false

    private val ticker = object : Runnable {
        override fun run() {
            val p = player
            if (p != null && isPrepared && p.isPlaying) {
                emitState("playing", p.currentPosition, p.duration)
                main.postDelayed(this, 150L)
            }
        }
    }

    fun play(path: String, positionMs: Int? = null): Boolean {
        val file = File(path)
        if (!file.exists()) {
            emit(mapOf("type" to "error", "message" to "Berkas audio tidak ditemukan."))
            return false
        }

        if (player != null && isPrepared && currentPath == path) {
            if (positionMs != null) {
                val target = positionMs.coerceIn(0, max(0, player!!.duration))
                player!!.seekTo(target)
            } else if (!player!!.isPlaying && player!!.duration > 0 &&
                player!!.currentPosition >= player!!.duration - 250
            ) {
                player!!.seekTo(0)
            }
            player!!.start()
            main.removeCallbacks(ticker)
            emitState("playing", player!!.currentPosition, player!!.duration)
            main.postDelayed(ticker, 150L)
            return true
        }

        stop(silent = true)

        return try {
            val mp = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(path)
                setOnCompletionListener {
                    main.removeCallbacks(ticker)
                    emitState("completed", duration, duration)
                }
                setOnErrorListener { _, what, extra ->
                    main.removeCallbacks(ticker)
                    emit(
                        mapOf(
                            "type" to "error",
                            "path" to path,
                            "message" to "Gagal memutar audio ($what/$extra)"
                        )
                    )
                    true
                }
                prepare()
            }
            player = mp
            currentPath = path
            isPrepared = true
            if (positionMs != null) {
                val target = positionMs.coerceIn(0, max(0, mp.duration))
                mp.seekTo(target)
            }
            mp.start()
            emitState("playing", mp.currentPosition, mp.duration)
            main.postDelayed(ticker, 150L)
            true
        } catch (e: Exception) {
            stop(silent = true)
            emit(mapOf("type" to "error", "path" to path, "message" to "${e.message}"))
            false
        }
    }

    fun pause() {
        main.removeCallbacks(ticker)
        val p = player ?: return
        if (isPrepared && p.isPlaying) {
            p.pause()
            emitState("paused", p.currentPosition, p.duration)
        }
    }

    fun seek(positionMs: Int) {
        val p = player ?: return
        if (!isPrepared) return
        val target = positionMs.coerceIn(0, max(0, p.duration))
        p.seekTo(target)
        val state = if (p.isPlaying) "playing" else "paused"
        emitState(state, target, p.duration)
    }

    fun stop(silent: Boolean = false) {
        main.removeCallbacks(ticker)
        val prevPath = currentPath
        val p = player
        player = null
        currentPath = null
        isPrepared = false
        if (p != null) {
            try {
                if (p.isPlaying) p.stop()
            } catch (_: Exception) {}
            try { p.release() } catch (_: Exception) {}
        }
        if (!silent && prevPath != null) {
            emit(
                mapOf(
                    "type" to "state",
                    "path" to prevPath,
                    "state" to "stopped",
                    "positionMs" to 0,
                    "durationMs" to 0
                )
            )
        }
    }

    private fun emitState(state: String, positionMs: Int, durationMs: Int) {
        emit(
            mapOf(
                "type" to "state",
                "path" to currentPath,
                "state" to state,
                "positionMs" to positionMs,
                "durationMs" to durationMs
            )
        )
    }
}
