package com.fedmind.fedmind_mobile_app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.media.FaceDetector
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val channelName = "com.fedmind.edge/multimodal_extractor"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractVideoMultimodal" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val maxFrames = call.argument<Int>("maxFrames") ?: 16
                        val targetSampleRate = call.argument<Int>("targetSampleRate") ?: 8000

                        if (videoPath.isNullOrBlank() || !File(videoPath).exists()) {
                            result.error("FILE_NOT_FOUND", "Video file not found: $videoPath", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            try {
                                val visualData = extractVisualFrames(videoPath, maxFrames)
                                val audioData = decodeAudioTrackPcm(videoPath, targetSampleRate)

                                val payload = hashMapOf<String, Any>(
                                    "visual" to visualData,
                                    "audio" to audioData
                                )
                                mainHandler.post {
                                    result.success(payload)
                                }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error(
                                        "EXTRACTION_FAILED",
                                        "Failed to extract video multimodal signals: ${e.message}",
                                        null
                                    )
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Mengekstrak frame video secara riil menggunakan MediaMetadataRetriever,
     * mendeteksi wajah menggunakan Android native FaceDetector (RGB_565),
     * dan menghitung dinamika ekspresi sub-area wajah (Alis, Mata, Mulut, Pose Kepala, & Aliran Gerak).
     */
    private fun extractVisualFrames(videoPath: String, numFrames: Int): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        val frameFeatures = ArrayList<Map<String, Double>>()
        var durationMs = 0L
        var facesDetectedCount = 0

        try {
            retriever.setDataSource(videoPath)
            val durStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            durationMs = durStr?.toLongOrNull() ?: 5000L
            if (durationMs <= 0L) durationMs = 5000L

            val safeFrames = numFrames.coerceIn(6, 24)
            var prevFaceBitmap: IntArray? = null
            val normSize = 64

            for (i in 0 until safeFrames) {
                val timeUs = ((durationMs * 1000L * i) / safeFrames).coerceAtLeast(0L)
                val rawBitmap = retriever.getFrameAtTime(
                    timeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                ) ?: retriever.getFrameAtTime(timeUs)

                if (rawBitmap == null) continue

                // Skala ke ukuran genap agar kompatibel dengan FaceDetector RGB_565
                val targetW = 240
                val targetH = ((rawBitmap.height.toFloat() / rawBitmap.width.coerceAtLeast(1)) * targetW)
                    .toInt()
                    .coerceAtLeast(160)
                    .let { if (it % 2 != 0) it + 1 else it }

                val scaled = Bitmap.createScaledBitmap(rawBitmap, targetW, targetH, true)
                val rgb565 = scaled.copy(Bitmap.Config.RGB_565, false)

                val detector = FaceDetector(targetW, targetH, 1)
                val faces = arrayOfNulls<FaceDetector.Face>(1)
                val found = detector.findFaces(rgb565, faces)

                var faceFound = 0.0
                var confidence = 0.0
                var eulerX = 0.0
                var eulerY = 0.0
                var eulerZ = 0.0
                var eyeDistRatio = 0.25

                // Crop bounding box wajah (atau bagian tengah frame jika wajah tertunduk/miring)
                var cropLeft = (targetW * 0.22).toInt()
                var cropTop = (targetH * 0.18).toInt()
                var cropRight = (targetW * 0.78).toInt()
                var cropBottom = (targetH * 0.82).toInt()

                if (found > 0 && faces[0] != null) {
                    val face = faces[0]!!
                    facesDetectedCount++
                    faceFound = 1.0
                    confidence = face.confidence().toDouble()
                    eulerX = face.pose(FaceDetector.Face.EULER_X).toDouble()
                    eulerY = face.pose(FaceDetector.Face.EULER_Y).toDouble()
                    eulerZ = face.pose(FaceDetector.Face.EULER_Z).toDouble()

                    val mid = PointF()
                    face.getMidPoint(mid)
                    val eyeDist = face.eyesDistance()
                    eyeDistRatio = (eyeDist / targetW.toFloat()).toDouble()

                    cropLeft = (mid.x - eyeDist * 1.15f).toInt().coerceIn(0, targetW - 16)
                    cropRight = (mid.x + eyeDist * 1.15f).toInt().coerceIn(cropLeft + 16, targetW)
                    cropTop = (mid.y - eyeDist * 0.85f).toInt().coerceIn(0, targetH - 16)
                    cropBottom = (mid.y + eyeDist * 1.65f).toInt().coerceIn(cropTop + 16, targetH)
                }

                val faceCrop = Bitmap.createBitmap(
                    scaled,
                    cropLeft,
                    cropTop,
                    (cropRight - cropLeft).coerceAtLeast(16),
                    (cropBottom - cropTop).coerceAtLeast(16)
                )
                val normFace = Bitmap.createScaledBitmap(faceCrop, normSize, normSize, true)
                val pixels = IntArray(normSize * normSize)
                normFace.getPixels(pixels, 0, normSize, 0, 0, normSize, normSize)

                val luma = DoubleArray(normSize * normSize)
                for (p in pixels.indices) {
                    val c = pixels[p]
                    val r = Color.red(c)
                    val g = Color.green(c)
                    val b = Color.blue(c)
                    luma[p] = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                }

                // Analisis Sub-Area Wajah (Action Unit Proxies):
                // 1. Area Alis & Dahi (y: 8..22, x: 14..50) -> AU01/AU02/AU04
                val browGrad = computeRegionGradient(luma, normSize, 14, 8, 50, 22)
                // 2. Area Mata Kiri & Kanan (y: 20..32) -> AU05/AU07/AU45 (Eye Aperture)
                val leftEyeVar = computeRegionVariance(luma, normSize, 12, 20, 28, 32)
                val rightEyeVar = computeRegionVariance(luma, normSize, 36, 20, 52, 32)
                val eyeOpenness = ((leftEyeVar + rightEyeVar) * 0.5 * 12.0).coerceIn(0.0, 2.5)
                // 3. Area Pipi & Nasolabial (y: 30..44) -> AU06/AU09/AU10
                val cheekGrad = computeRegionGradient(luma, normSize, 14, 30, 50, 44)
                // 4. Area Mulut & Bibir (y: 42..58, x: 18..46) -> AU12/AU15/AU25/AU26
                val mouthGrad = computeRegionGradient(luma, normSize, 18, 42, 46, 58)
                val mouthOpenVar = computeRegionVariance(luma, normSize, 22, 44, 42, 56)
                // 5. Simetri Kiri-Kanan Wajah
                val symmetryDiff = computeLeftRightAsymmetry(luma, normSize)

                // 6. Aliran Gerak Antar-Frame (Optical Flow / Temporal Expression Dynamics)
                var motionEnergy = 0.0
                if (prevFaceBitmap != null) {
                    var diffSum = 0.0
                    for (p in pixels.indices) {
                        val lPrev = ((Color.red(prevFaceBitmap[p]) * 299 +
                                Color.green(prevFaceBitmap[p]) * 587 +
                                Color.blue(prevFaceBitmap[p]) * 114) / 1000.0) / 255.0
                        diffSum += abs(luma[p] - lPrev)
                    }
                    motionEnergy = diffSum / pixels.size
                }
                prevFaceBitmap = pixels

                frameFeatures.add(
                    hashMapOf(
                        "timeSec" to (timeUs / 1000000.0),
                        "faceFound" to faceFound,
                        "confidence" to confidence,
                        "bboxLeft" to (cropLeft.toDouble() / targetW.coerceAtLeast(1)),
                        "bboxTop" to (cropTop.toDouble() / targetH.coerceAtLeast(1)),
                        "bboxRight" to (cropRight.toDouble() / targetW.coerceAtLeast(1)),
                        "bboxBottom" to (cropBottom.toDouble() / targetH.coerceAtLeast(1)),
                        "eulerX" to eulerX,
                        "eulerY" to eulerY,
                        "eulerZ" to eulerZ,
                        "eyeDistRatio" to eyeDistRatio,
                        "browActivation" to (browGrad * 8.5).coerceIn(0.0, 4.0),
                        "eyeOpenness" to eyeOpenness,
                        "cheekActivation" to (cheekGrad * 7.5).coerceIn(0.0, 4.0),
                        "mouthActivation" to (mouthGrad * 9.0).coerceIn(0.0, 4.0),
                        "mouthOpenness" to (mouthOpenVar * 18.0).coerceIn(0.0, 4.0),
                        "asymmetry" to symmetryDiff,
                        "motionEnergy" to (motionEnergy * 10.0).coerceIn(0.0, 3.0)
                    )
                )

                normFace.recycle()
                faceCrop.recycle()
                rgb565.recycle()
                scaled.recycle()
                rawBitmap.recycle()
            }
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }

        return hashMapOf(
            "durationMs" to durationMs,
            "framesExtracted" to frameFeatures.size,
            "facesDetectedCount" to facesDetectedCount,
            "frames" to frameFeatures
        )
    }

    private fun computeRegionGradient(
        luma: DoubleArray,
        stride: Int,
        x0: Int,
        y0: Int,
        x1: Int,
        y1: Int
    ): Double {
        var sum = 0.0
        var count = 0
        for (y in y0 until (y1 - 1).coerceAtMost(stride - 1)) {
            for (x in x0 until (x1 - 1).coerceAtMost(stride - 1)) {
                val idx = y * stride + x
                val gx = luma[idx + 1] - luma[idx]
                val gy = luma[idx + stride] - luma[idx]
                sum += sqrt(gx * gx + gy * gy)
                count++
            }
        }
        return if (count > 0) sum / count else 0.0
    }

    private fun computeRegionVariance(
        luma: DoubleArray,
        stride: Int,
        x0: Int,
        y0: Int,
        x1: Int,
        y1: Int
    ): Double {
        var sum = 0.0
        var count = 0
        for (y in y0 until y1.coerceAtMost(stride)) {
            for (x in x0 until x1.coerceAtMost(stride)) {
                sum += luma[y * stride + x]
                count++
            }
        }
        if (count == 0) return 0.0
        val mean = sum / count
        var sqSum = 0.0
        for (y in y0 until y1.coerceAtMost(stride)) {
            for (x in x0 until x1.coerceAtMost(stride)) {
                val d = luma[y * stride + x] - mean
                sqSum += d * d
            }
        }
        return sqSum / count
    }

    private fun computeLeftRightAsymmetry(luma: DoubleArray, stride: Int): Double {
        var diff = 0.0
        var count = 0
        val half = stride / 2
        for (y in 10 until stride - 10) {
            for (x in 8 until half) {
                val left = luma[y * stride + x]
                val right = luma[y * stride + (stride - 1 - x)]
                diff += abs(left - right)
                count++
            }
        }
        return if (count > 0) diff / count else 0.0
    }

    /**
     * Mendekode track audio dari file video MP4 menjadi gelombang PCM 16-bit
     * lalu melakukan downsampling ke targetSampleRate (8000 Hz Mono) untuk analisis DSP di Dart.
     */
    private fun decodeAudioTrackPcm(videoPath: String, targetSampleRate: Int): Map<String, Any> {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val samplesOut = ArrayList<Double>(targetSampleRate * 45)
        var sourceSampleRate = 44100
        var channelCount = 1

        try {
            extractor.setDataSource(videoPath)
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex < 0 || audioFormat == null) {
                return hashMapOf(
                    "hasAudioTrack" to false,
                    "sampleRate" to targetSampleRate,
                    "pcmSamples" to emptyList<Double>()
                )
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = audioFormat.getString(MediaFormat.KEY_MIME)!!
            sourceSampleRate = if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else 44100
            channelCount = if (audioFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
            } else 1

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(audioFormat, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            var isInputEOS = false
            var isOutputEOS = false
            val maxOutputSamples = targetSampleRate * 45 // Maksimal 45 detik @ 8kHz = 360.000 sampel
            val decimationStep = max(1, sourceSampleRate / targetSampleRate)
            var sampleCounter = 0

            while (!isOutputEOS && samplesOut.size < maxOutputSamples) {
                if (!isInputEOS) {
                    val inIndex = codec.dequeueInputBuffer(10000)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)
                        if (inputBuffer != null) {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inIndex,
                                    0,
                                    0,
                                    0L,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                isInputEOS = true
                            } else {
                                val presentationTimeUs = extractor.sampleTime
                                codec.queueInputBuffer(
                                    inIndex,
                                    0,
                                    sampleSize,
                                    presentationTimeUs,
                                    0
                                )
                                extractor.advance()
                            }
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
                if (outIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val shortBuffer = outputBuffer.order(ByteOrder.nativeOrder()).asShortBuffer()
                        val numShorts = shortBuffer.remaining()

                        var idx = 0
                        while (idx < numShorts && samplesOut.size < maxOutputSamples) {
                            // Rata-rata kanal menjadi mono
                            var sumCh = 0.0
                            val chLimit = min(channelCount, numShorts - idx)
                            for (c in 0 until chLimit) {
                                sumCh += shortBuffer.get(idx + c) / 32768.0
                            }
                            val monoSample = sumCh / chLimit.coerceAtLeast(1)

                            if (sampleCounter % decimationStep == 0) {
                                samplesOut.add(monoSample)
                            }
                            sampleCounter++
                            idx += channelCount
                        }
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        isOutputEOS = true
                    }
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = codec.outputFormat
                    if (newFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sourceSampleRate = newFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
                    }
                }
            }
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            try {
                codec?.release()
            } catch (_: Exception) {
            }
            try {
                extractor.release()
            } catch (_: Exception) {
            }
        }

        val effectiveRate = max(1000, sourceSampleRate / max(1, sourceSampleRate / targetSampleRate))
        return hashMapOf(
            "hasAudioTrack" to samplesOut.isNotEmpty(),
            "sampleRate" to effectiveRate,
            "pcmSamples" to samplesOut
        )
    }
}
