package com.fedmind.fedmind_mobile_app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PointF
import android.media.FaceDetector
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
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

    private var speechRecognizer: SpeechRecognizer? = null
    private val liveSpeechTranscript = StringBuilder()
    private var isRecognizingSpeech = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSpeechRecognitionAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        val isOnDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                        } else {
                            available
                        }
                        result.success(hashMapOf("available" to available, "isOnDevice" to isOnDevice))
                    }
                    "startLiveSpeechRecognition" -> {
                        mainHandler.post {
                            try {
                                if (speechRecognizer != null) {
                                    try { speechRecognizer?.destroy() } catch (_: Exception) {}
                                    speechRecognizer = null
                                }
                                liveSpeechTranscript.clear()

                                speechRecognizer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                    SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                                    SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                                } else {
                                    SpeechRecognizer.createSpeechRecognizer(this)
                                }

                                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                                    override fun onReadyForSpeech(params: Bundle?) {}
                                    override fun onBeginningOfSpeech() {}
                                    override fun onRmsChanged(rmsdB: Float) {}
                                    override fun onBufferReceived(buffer: ByteArray?) {}
                                    override fun onEndOfSpeech() {}
                                    override fun onError(error: Int) {
                                        // Ignore silence or network timeouts gracefully
                                    }
                                    override fun onResults(results: Bundle?) {
                                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            val text = matches[0]?.trim() ?: ""
                                            if (text.isNotBlank()) {
                                                if (liveSpeechTranscript.isNotEmpty()) liveSpeechTranscript.append(" ")
                                                liveSpeechTranscript.append(text)
                                            }
                                        }
                                    }
                                    override fun onPartialResults(partialResults: Bundle?) {
                                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                        if (!matches.isNullOrEmpty()) {
                                            val text = matches[0]?.trim() ?: ""
                                            if (text.isNotBlank() && !liveSpeechTranscript.endsWith(text)) {
                                                // Live partial update
                                            }
                                        }
                                    }
                                    override fun onEvent(eventType: Int, params: Bundle?) {}
                                })

                                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
                                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "id-ID")
                                    putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, "id-ID")
                                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                                    }
                                }

                                speechRecognizer?.startListening(intent)
                                isRecognizingSpeech = true
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SPEECH_START_ERROR", "Failed to start on-device speech recognizer: ${e.message}", null)
                            }
                        }
                    }
                    "stopLiveSpeechRecognition" -> {
                        mainHandler.post {
                            try {
                                isRecognizingSpeech = false
                                speechRecognizer?.stopListening()
                                mainHandler.postDelayed({
                                    val finalTranscript = liveSpeechTranscript.toString().trim()
                                    try { speechRecognizer?.destroy() } catch (_: Exception) {}
                                    speechRecognizer = null
                                    result.success(hashMapOf("transcript" to finalTranscript))
                                }, 350)
                            } catch (e: Exception) {
                                result.success(hashMapOf("transcript" to liveSpeechTranscript.toString().trim()))
                            }
                        }
                    }
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
            var prevLumaFrame: DoubleArray? = null
            val normSize = 64

            for (i in 0 until safeFrames) {
                // Sampling merata dari 5% hingga 95% durasi video agar tidak terjebak di frame hitam awal/akhir
                val progress = (i + 0.5) / safeFrames.toDouble()
                val timeUs = ((durationMs * 1000L) * progress).toLong().coerceAtLeast(0L)
                val rawBitmap = try {
                    retriever.getFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST
                    ) ?: retriever.getFrameAtTime(
                        timeUs,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                    )
                } catch (_: Throwable) {
                    retriever.getFrameAtTime(timeUs)
                }

                if (rawBitmap == null) continue

                // Skala ke ukuran genap agar kompatibel dengan FaceDetector RGB_565
                val targetW = 240
                val targetH = ((rawBitmap.height.toFloat() / rawBitmap.width.coerceAtLeast(1)) * targetW)
                    .toInt()
                    .coerceAtLeast(160)
                    .let { if (it % 2 != 0) it + 1 else it }

                val scaled = Bitmap.createScaledBitmap(rawBitmap, targetW, targetH, true)
                val rgb565 = try {
                    scaled.copy(Bitmap.Config.RGB_565, false)
                } catch (_: Throwable) {
                    null
                }

                var faceFound = 0.0
                var confidence = 0.0
                var eulerX = 0.0
                var eulerY = 0.0
                var eulerZ = 0.0
                var eyeDistRatio = 0.25

                // Default bounding box tengah sebelum deteksi
                var cropLeft = (targetW * 0.22).toInt()
                var cropTop = (targetH * 0.18).toInt()
                var cropRight = (targetW * 0.78).toInt()
                var cropBottom = (targetH * 0.82).toInt()

                if (rgb565 != null) {
                    try {
                        val detector = FaceDetector(targetW, targetH, 1)
                        val faces = arrayOfNulls<FaceDetector.Face>(1)
                        val found = detector.findFaces(rgb565, faces)

                        if (found > 0 && faces[0] != null) {
                            val face = faces[0]!!
                            facesDetectedCount++
                            faceFound = 1.0
                            confidence = face.confidence().toDouble().coerceIn(0.35, 0.99)
                            eulerX = face.pose(FaceDetector.Face.EULER_X).toDouble()
                            eulerY = face.pose(FaceDetector.Face.EULER_Y).toDouble()
                            eulerZ = face.pose(FaceDetector.Face.EULER_Z).toDouble()

                            val mid = PointF()
                            face.getMidPoint(mid)
                            val eyeDist = face.eyesDistance().coerceAtLeast(16f)
                            eyeDistRatio = (eyeDist / targetW.toFloat()).toDouble().coerceIn(0.12, 0.48)

                            // Jika Android FaceDetector mengembalikan 0.0 untuk pose Euler, estimasi dari posisi titik tengah mata
                            if (abs(eulerX) < 0.01) {
                                eulerX = ((0.40 - (mid.y / targetH.toDouble())) * 45.0).coerceIn(-28.0, 22.0)
                            }
                            if (abs(eulerY) < 0.01) {
                                eulerY = (((mid.x / targetW.toDouble()) - 0.50) * 45.0).coerceIn(-30.0, 30.0)
                            }

                            cropLeft = (mid.x - eyeDist * 1.15f).toInt().coerceIn(0, targetW - 16)
                            cropRight = (mid.x + eyeDist * 1.15f).toInt().coerceIn(cropLeft + 16, targetW)
                            cropTop = (mid.y - eyeDist * 0.85f).toInt().coerceIn(0, targetH - 16)
                            cropBottom = (mid.y + eyeDist * 1.65f).toInt().coerceIn(cropTop + 16, targetH)
                        }
                    } catch (_: Throwable) {
                        // Biarkan lanjut ke evaluasi heuristik krominansi kulit di bawah
                    }
                }

                // Jika FaceDetector gagal (misal wajah menunduk/miring), evaluasi distribusi piksel warna kulit
                if (faceFound < 0.5) {
                    val skinEst = estimateSkinFaceRegion(scaled, targetW, targetH)
                    if (skinEst.skinRatio >= 0.16) {
                        facesDetectedCount++
                        faceFound = 1.0
                        confidence = (0.48 + skinEst.skinRatio * 0.65).coerceIn(0.52, 0.82)
                        cropLeft = skinEst.left
                        cropTop = skinEst.top
                        cropRight = skinEst.right
                        cropBottom = skinEst.bottom
                        eulerX = ((0.44 - skinEst.centerYNorm) * 48.0).coerceIn(-28.0, 20.0)
                        eulerY = ((skinEst.centerXNorm - 0.50) * 42.0).coerceIn(-25.0, 25.0)
                    } else {
                        faceFound = 0.0
                        confidence = (skinEst.skinRatio * 2.0).coerceIn(0.05, 0.35)
                    }
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
                // 1. Area Alis & Glabella (y: 8..22, x: 14..50) -> AU01/AU02/AU04 (ketegangan dahi & kerutan antar-alis)
                val browGrad = computeRegionGradient(luma, normSize, 14, 8, 50, 22)
                val glabellaGrad = computeRegionGradient(luma, normSize, 24, 10, 40, 22)
                val foreheadMean = computeRegionMean(luma, normSize, 18, 6, 46, 15)
                val browMean = computeRegionMean(luma, normSize, 16, 15, 48, 23)
                val browContrast = (foreheadMean - browMean).coerceAtLeast(0.0)
                val browActivation = ((browGrad * 5.2) + (glabellaGrad * 4.5) + (browContrast * 3.8)).coerceIn(0.05, 4.0)

                // 2. Area Mata Kiri & Kanan (y: 20..32) -> AU05/AU07/AU45 (Eye Aperture)
                val leftEyeVar = computeRegionVariance(luma, normSize, 12, 20, 28, 32)
                val rightEyeVar = computeRegionVariance(luma, normSize, 36, 20, 52, 32)
                val eyeGrad = (computeRegionGradient(luma, normSize, 12, 20, 28, 32) +
                        computeRegionGradient(luma, normSize, 36, 20, 52, 32)) * 0.5
                val eyeOpenness = (((leftEyeVar + rightEyeVar) * 6.5) + (eyeGrad * 3.2)).coerceIn(0.08, 2.5)

                // 3. Area Pipi & Nasolabial (y: 30..44) -> AU06/AU09/AU10
                val cheekGrad = computeRegionGradient(luma, normSize, 12, 29, 52, 44)
                val upperCheekMean = computeRegionMean(luma, normSize, 12, 28, 52, 36)
                val lowerCheekMean = computeRegionMean(luma, normSize, 14, 36, 50, 44)
                val cheekLift = (upperCheekMean - lowerCheekMean + 0.08).coerceIn(0.0, 0.5)
                val cheekActivation = ((cheekGrad * 5.8) + (cheekLift * 4.2)).coerceIn(0.05, 4.0)

                // 4. Area Mulut & Sudut Bibir (y: 42..58, x: 16..48) -> AU12 (senyum) vs AU15 (depressor)
                val mouthGrad = computeRegionGradient(luma, normSize, 16, 42, 48, 58)
                val mouthOpenVar = computeRegionVariance(luma, normSize, 22, 44, 42, 56)
                // Bandingkan sudut bibir atas-luar vs bawah-luar untuk mendeteksi tarikan senyum (AU12) vs sudut turun (AU15)
                val upperCornerMean = (computeRegionMean(luma, normSize, 15, 43, 23, 49) +
                        computeRegionMean(luma, normSize, 41, 43, 49, 49)) * 0.5
                val lowerCornerMean = (computeRegionMean(luma, normSize, 15, 50, 23, 57) +
                        computeRegionMean(luma, normSize, 41, 50, 49, 57)) * 0.5
                val mouthCenterMean = computeRegionMean(luma, normSize, 25, 46, 39, 53)
                val cornerLift = (lowerCornerMean - upperCornerMean) + (cheekLift * 0.5) - (mouthCenterMean - lowerCornerMean) * 0.3
                val mouthActivation = ((mouthGrad * 6.5) + (cornerLift * 5.5) + 0.45).coerceIn(0.05, 4.0)
                val mouthOpenness = ((mouthOpenVar * 16.0) + (mouthGrad * 2.2)).coerceIn(0.05, 4.0)

                // 5. Simetri Kiri-Kanan & Ketegangan Sudut Bibir Bawah
                val symmetryDiff = computeLeftRightAsymmetry(luma, normSize)
                val depressorProxy = (symmetryDiff * 1.15 + (upperCornerMean - lowerCornerMean).coerceAtLeast(0.0) * 1.8).coerceIn(0.0, 1.0)

                // Jika eulerX masih mendekati 0, perkaya dengan rasio pencahayaan vertikal wajah (menunduk membuat dahi lebih dominan & dagu gelap)
                if (abs(eulerX) < 1.5) {
                    val lowerJawMean = computeRegionMean(luma, normSize, 18, 46, 46, 60)
                    eulerX += ((lowerJawMean - foreheadMean) * 32.0).coerceIn(-18.0, 15.0)
                }

                // 6. Aliran Gerak Antar-Frame (Optical Flow / Temporal Expression Dynamics)
                var motionEnergy = 0.0
                val prevLuma = prevLumaFrame
                if (prevLuma != null && prevLuma.size == luma.size) {
                    var diffSum = 0.0
                    for (p in luma.indices) {
                        diffSum += abs(luma[p] - prevLuma[p])
                    }
                    motionEnergy = diffSum / luma.size
                }
                prevLumaFrame = luma

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
                        "browActivation" to browActivation,
                        "eyeOpenness" to eyeOpenness,
                        "cheekActivation" to cheekActivation,
                        "mouthActivation" to mouthActivation,
                        "mouthOpenness" to mouthOpenness,
                        "asymmetry" to depressorProxy,
                        "motionEnergy" to (motionEnergy * 11.5).coerceIn(0.0, 3.0)
                    )
                )

                normFace.recycle()
                faceCrop.recycle()
                rgb565?.recycle()
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

    private fun computeRegionMean(
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
        return if (count > 0) sum / count else 0.0
    }

    private data class SkinRegionEstimate(
        val skinRatio: Double,
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
        val centerXNorm: Double,
        val centerYNorm: Double
    )

    /**
     * Heuristik krominansi kulit (YCbCr / RGB) untuk mendeteksi posisi kepala/wajah
     * ketika FaceDetector gagal (misal karena wajah tertunduk atau miring).
     */
    private fun estimateSkinFaceRegion(
        bitmap: Bitmap,
        width: Int,
        height: Int
    ): SkinRegionEstimate {
        var skinCount = 0
        var totalSampled = 0
        var sumX = 0.0
        var sumY = 0.0
        val marginX = (width * 0.10).toInt()
        val marginY = (height * 0.08).toInt()

        for (y in marginY until (height - marginY) step 3) {
            for (x in marginX until (width - marginX) step 3) {
                val c = bitmap.getPixel(x, y)
                val r = Color.red(c)
                val g = Color.green(c)
                val b = Color.blue(c)
                totalSampled++

                val maxRgb = max(r, max(g, b))
                val minRgb = min(r, min(g, b))
                val cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
                val cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b

                val isSkin = (r > 60 && g > 35 && b > 18 &&
                        (maxRgb - minRgb) > 12 &&
                        r > g && r > b &&
                        cr >= 131.0 && cr <= 178.0 &&
                        cb >= 75.0 && cb <= 132.0)

                if (isSkin) {
                    skinCount++
                    sumX += x
                    sumY += y
                }
            }
        }

        val ratio = if (totalSampled > 0) skinCount.toDouble() / totalSampled else 0.0
        if (skinCount < 12) {
            return SkinRegionEstimate(
                skinRatio = ratio,
                left = (width * 0.22).toInt(),
                top = (height * 0.18).toInt(),
                right = (width * 0.78).toInt(),
                bottom = (height * 0.82).toInt(),
                centerXNorm = 0.5,
                centerYNorm = 0.48
            )
        }

        val cx = sumX / skinCount
        val cy = sumY / skinCount
        val boxHalfW = (width * 0.27).toInt().coerceAtLeast(24)
        val boxHalfH = (height * 0.31).toInt().coerceAtLeast(28)
        val left = (cx.toInt() - boxHalfW).coerceIn(0, width - 32)
        val right = (cx.toInt() + boxHalfW).coerceIn(left + 32, width)
        val top = (cy.toInt() - boxHalfH).coerceIn(0, height - 32)
        val bottom = (cy.toInt() + boxHalfH).coerceIn(top + 32, height)

        return SkinRegionEstimate(
            skinRatio = ratio,
            left = left,
            top = top,
            right = right,
            bottom = bottom,
            centerXNorm = (cx / width.coerceAtLeast(1)).coerceIn(0.15, 0.85),
            centerYNorm = (cy / height.coerceAtLeast(1)).coerceIn(0.15, 0.85)
        )
    }

    /**
     * Menulis header WAV standar 44-byte (RIFF/WAVE 16-bit PCM Mono).
     */
    private fun writeWavHeader(raf: RandomAccessFile, totalAudioLen: Long, sampleRate: Int, channels: Int) {
        val totalDataLen = totalAudioLen + 36
        val byteRate = sampleRate * channels * 2
        val header = ByteArray(44)

        header[0] = 'R'.code.toByte()
        header[1] = 'I'.code.toByte()
        header[2] = 'F'.code.toByte()
        header[3] = 'F'.code.toByte()
        header[4] = (totalDataLen and 0xff).toByte()
        header[5] = ((totalDataLen shr 8) and 0xff).toByte()
        header[6] = ((totalDataLen shr 16) and 0xff).toByte()
        header[7] = ((totalDataLen shr 24) and 0xff).toByte()
        header[8] = 'W'.code.toByte()
        header[9] = 'A'.code.toByte()
        header[10] = 'V'.code.toByte()
        header[11] = 'E'.code.toByte()
        header[12] = 'f'.code.toByte()
        header[13] = 'm'.code.toByte()
        header[14] = 't'.code.toByte()
        header[15] = ' '.code.toByte()
        header[16] = 16
        header[17] = 0
        header[18] = 0
        header[19] = 0
        header[20] = 1 // PCM
        header[21] = 0
        header[22] = channels.toByte()
        header[23] = 0
        header[24] = (sampleRate and 0xff).toByte()
        header[25] = ((sampleRate shr 8) and 0xff).toByte()
        header[26] = ((sampleRate shr 16) and 0xff).toByte()
        header[27] = ((sampleRate shr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate shr 8) and 0xff).toByte()
        header[30] = ((byteRate shr 16) and 0xff).toByte()
        header[31] = ((byteRate shr 24) and 0xff).toByte()
        header[32] = (channels * 2).toByte()
        header[33] = 0
        header[34] = 16
        header[35] = 0
        header[36] = 'd'.code.toByte()
        header[37] = 'a'.code.toByte()
        header[38] = 't'.code.toByte()
        header[39] = 'a'.code.toByte()
        header[40] = (totalAudioLen and 0xff).toByte()
        header[41] = ((totalAudioLen shr 8) and 0xff).toByte()
        header[42] = ((totalAudioLen shr 16) and 0xff).toByte()
        header[43] = ((totalAudioLen shr 24) and 0xff).toByte()

        raf.seek(0)
        raf.write(header)
    }

    /**
     * Mendekode track audio dari file video MP4 menjadi gelombang PCM 16-bit 16kHz Mono penuh
     * secara kontinu (tanpa pemotongan jendela) langsung ke berkas WAV lokal, serta mengirimkan
     * subset sampel kontinu untuk representasi akustik DSP di Dart.
     */
    private fun decodeAudioTrackPcm(videoPath: String, targetSampleRate: Int): Map<String, Any> {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val maxDspSamples = 240000 // Hingga 15 detik sampel kontinu untuk FFT/MFCC di Dart
        val samplesOut = ArrayList<Double>(minOf(maxDspSamples, 65536))
        var sourceSampleRate = 44100
        var channelCount = 1

        val tempWavFile = File.createTempFile("extracted_16k_", ".wav", cacheDir)
        var raf: RandomAccessFile? = null
        var totalSamplesWritten = 0L

        try {
            raf = RandomAccessFile(tempWavFile, "rw")
            raf.write(ByteArray(44)) // Dummy header awal

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
                tempWavFile.delete()
                return hashMapOf(
                    "hasAudioTrack" to false,
                    "sampleRate" to targetSampleRate,
                    "pcmSamples" to emptyList<Double>()
                )
            }

            extractor.selectTrack(audioTrackIndex)
            val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.isBlank()) {
                tempWavFile.delete()
                return hashMapOf(
                    "hasAudioTrack" to false,
                    "sampleRate" to targetSampleRate,
                    "pcmSamples" to emptyList<Double>()
                )
            }
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

            var resampleRatio = sourceSampleRate.toDouble() / targetSampleRate.toDouble()
            var phase = 0.0
            var prevMono = 0.0
            val writeBuf = ByteArray(8192)
            var writeBufPos = 0

            fun flushWriteBuf() {
                if (writeBufPos > 0) {
                    raf.write(writeBuf, 0, writeBufPos)
                    writeBufPos = 0
                }
            }

            fun emit16kSample(sample: Double) {
                val clamped = sample.coerceIn(-1.0, 1.0)
                if (samplesOut.size < maxDspSamples) {
                    samplesOut.add(clamped)
                }
                val intVal = (clamped * 32767.0).toInt().coerceIn(-32768, 32767).toShort()
                writeBuf[writeBufPos++] = (intVal.toInt() and 0xff).toByte()
                writeBuf[writeBufPos++] = ((intVal.toInt() shr 8) and 0xff).toByte()
                if (writeBufPos >= writeBuf.size) {
                    flushWriteBuf()
                }
                totalSamplesWritten++
            }

            while (!isOutputEOS) {
                if (!isInputEOS) {
                    val inIndex = codec.dequeueInputBuffer(10000)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)
                        if (inputBuffer != null) {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(
                                    inIndex, 0, 0, 0L,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM
                                )
                                isInputEOS = true
                            } else {
                                val presentationTimeUs = extractor.sampleTime
                                codec.queueInputBuffer(
                                    inIndex, 0, sampleSize, presentationTimeUs, 0
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
                        while (idx < numShorts) {
                            var sumCh = 0.0
                            val chLimit = min(channelCount, numShorts - idx)
                            for (c in 0 until chLimit) {
                                sumCh += shortBuffer.get(idx + c) / 32768.0
                            }
                            val currMono = sumCh / chLimit.coerceAtLeast(1)

                            while (phase < 1.0) {
                                val interpolated = prevMono + (currMono - prevMono) * phase
                                emit16kSample(interpolated)
                                phase += resampleRatio
                            }
                            phase -= 1.0
                            prevMono = currMono

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
                        resampleRatio = sourceSampleRate.toDouble() / targetSampleRate.toDouble()
                    }
                    if (newFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channelCount = newFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
                    }
                }
            }

            flushWriteBuf()

            if (totalSamplesWritten > 0) {
                writeWavHeader(raf, totalSamplesWritten * 2, targetSampleRate, 1)
            }
        } finally {
            try { raf?.close() } catch (_: Exception) {}
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }

        if (totalSamplesWritten == 0L) {
            tempWavFile.delete()
            return hashMapOf(
                "hasAudioTrack" to false,
                "sampleRate" to targetSampleRate,
                "pcmSamples" to emptyList<Double>()
            )
        }

        val actualDurationSec = totalSamplesWritten.toDouble() / targetSampleRate.toDouble()
        return hashMapOf(
            "hasAudioTrack" to true,
            "sampleRate" to targetSampleRate,
            "wavPath" to tempWavFile.absolutePath,
            "totalSamples" to totalSamplesWritten,
            "durationSec" to actualDurationSec,
            "pcmSamples" to samplesOut
        )
    }
}
