package com.fedmind.fedmind_mobile_app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.SpeechRecognizer
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val channelName = "com.fedmind.edge/multimodal_extractor"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var methodChannel: MethodChannel? = null
    private var micSession: MicSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        micSession = MicSession(this) { event ->
            mainHandler.post { methodChannel?.invokeMethod("onMicEvent", event) }
        }
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMicSession" -> {
                        val err = micSession?.start()
                        if (err == null) result.success(true)
                        else result.error("MIC_SESSION_ERROR", err, null)
                    }
                    "stopMicSession" -> {
                        micSession?.stop { payload -> result.success(payload) }
                            ?: result.success(hashMapOf("transcript" to ""))
                    }
                    "isSpeechRecognitionAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        val isOnDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                        } else {
                            available
                        }
                        result.success(
                            hashMapOf(
                                "available" to available,
                                "isOnDevice" to isOnDevice,
                                "sdkInt" to Build.VERSION.SDK_INT,
                                "supportsParallelMic" to (Build.VERSION.SDK_INT >= 33)
                            )
                        )
                    }
                    "extractVideoMultimodal" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val maxFrames = call.argument<Int>("maxFrames") ?: 24
                        val targetSampleRate = call.argument<Int>("targetSampleRate") ?: 8000
                        val audioWavPath = call.argument<String>("audioWavPath")

                        if (videoPath.isNullOrBlank() || !File(videoPath).exists()) {
                            result.error("FILE_NOT_FOUND", "Video file not found: $videoPath", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            try {
                                val visualData = extractVisualFrames(videoPath, maxFrames)
                                val audioData = if (!audioWavPath.isNullOrBlank() && File(audioWavPath).exists()) {
                                    loadWavPcm(audioWavPath)
                                } else {
                                    decodeAudioTrackPcm(videoPath, targetSampleRate)
                                }

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
     * mendeteksi 478 landmark wajah + 52 ARKit Blendshapes + pose 3D menggunakan
     * MediaPipe Face Landmarker (`face_landmarker.task`), dengan fallback aman ke
     * ML Kit Face Detection + analisis regional bila runtime MediaPipe tidak tersedia.
     */
    private fun extractVisualFrames(videoPath: String, numFrames: Int): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        var faceLandmarker: FaceLandmarker? = null
        var mlkitDetector: FaceDetector? = null

        try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("face_landmarker.task")
                .build()
            val mpOptions = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setRunningMode(RunningMode.VIDEO)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.45f)
                .setMinFacePresenceConfidence(0.45f)
                .setMinTrackingConfidence(0.45f)
                .setOutputFaceBlendshapes(true)
                .setOutputFacialTransformationMatrixes(true)
                .build()
            faceLandmarker = FaceLandmarker.createFromOptions(applicationContext, mpOptions)
        } catch (_: Throwable) {
            faceLandmarker = null
        }

        if (faceLandmarker == null) {
            val mlkitOptions = FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .setMinFaceSize(0.12f)
                .build()
            mlkitDetector = FaceDetection.getClient(mlkitOptions)
        }

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
            var prevMpLandmarks: List<Pair<Double, Double>>? = null
            var prevMpBlendshapes: Map<String, Double>? = null
            var prevMpTimestampMs = -1L
            val normSize = 64

            for (i in 0 until safeFrames) {
                // Sampling merata pada titik tengah tiap segmen ((i + 0.5) / safeFrames) dari awal hingga akhir durasi video
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

                val targetW = 320
                val targetH = ((rawBitmap.height.toFloat() / rawBitmap.width.coerceAtLeast(1)) * targetW)
                    .toInt()
                    .coerceAtLeast(180)
                    .let { if (it % 2 != 0) it + 1 else it }

                val scaled = Bitmap.createScaledBitmap(rawBitmap, targetW, targetH, true)
                val argbBitmap = if (scaled.config == Bitmap.Config.ARGB_8888) {
                    scaled
                } else {
                    scaled.copy(Bitmap.Config.ARGB_8888, false)
                }

                if (faceLandmarker != null) {
                    val mpTimestampMs = max(prevMpTimestampMs + 1L, timeUs / 1000L)
                    prevMpTimestampMs = mpTimestampMs

                    var faceFound = 0.0
                    var confidence = 0.0
                    var eulerX = 0.0
                    var eulerY = 0.0
                    var eulerZ = 0.0
                    var eyeDistRatio = 0.25
                    var smilingProb = 0.0
                    var leftEyeOpenProb = 1.0
                    var rightEyeOpenProb = 1.0
                    var gazeAngleX = 0.0
                    var gazeAngleY = 0.16
                    var bboxLeft = 0.22
                    var bboxTop = 0.18
                    var bboxRight = 0.78
                    var bboxBottom = 0.82
                    var browActivation = 0.05
                    var eyeOpenness = 0.85
                    var cheekActivation = 0.05
                    var mouthActivation = 0.05
                    var mouthOpenness = 0.05
                    var asymmetry = 0.0
                    var motionEnergy = 0.0

                    val frameMap = HashMap<String, Double>(80)

                    try {
                        val mpImage = BitmapImageBuilder(argbBitmap).build()
                        val mpResult = faceLandmarker.detectForVideo(mpImage, mpTimestampMs)
                        val allLandmarks = mpResult?.faceLandmarks()
                        if (!allLandmarks.isNullOrEmpty()) {
                            val landmarks = allLandmarks[0]
                            facesDetectedCount++
                            faceFound = 1.0

                            var minX = 1.0
                            var maxX = 0.0
                            var minY = 1.0
                            var maxY = 0.0
                            for (lm in landmarks) {
                                val lx = lm.x().toDouble().coerceIn(0.0, 1.0)
                                val ly = lm.y().toDouble().coerceIn(0.0, 1.0)
                                if (lx < minX) minX = lx
                                if (lx > maxX) maxX = lx
                                if (ly < minY) minY = ly
                                if (ly > maxY) maxY = ly
                            }
                            bboxLeft = (minX - 0.03).coerceIn(0.0, 0.90)
                            bboxRight = (maxX + 0.03).coerceIn(bboxLeft + 0.08, 1.0)
                            bboxTop = (minY - 0.05).coerceIn(0.0, 0.90)
                            bboxBottom = (maxY + 0.02).coerceIn(bboxTop + 0.08, 1.0)

                            val boxAreaRatio = ((bboxRight - bboxLeft) * (bboxBottom - bboxTop)).coerceIn(0.0, 1.0)
                            confidence = (0.90 + boxAreaRatio * 0.25).coerceIn(0.86, 0.99)

                            if (landmarks.size > 362) {
                                val rEyeX = (landmarks[33].x() + landmarks[133].x()) * 0.5
                                val rEyeY = (landmarks[33].y() + landmarks[133].y()) * 0.5
                                val lEyeX = (landmarks[263].x() + landmarks[362].x()) * 0.5
                                val lEyeY = (landmarks[263].y() + landmarks[362].y()) * 0.5
                                val eyeDist = hypot(lEyeX - rEyeX, lEyeY - rEyeY)
                                    .coerceAtLeast(0.04)
                                eyeDistRatio = eyeDist.coerceIn(0.10, 0.48)

                                val fh = landmarks[10]
                                val chin = landmarks[152]
                                val nose = landmarks[1]
                                val rCheek = landmarks[234]
                                val lCheek = landmarks[454]

                                // Konvensi UI / ML Kit: menunduk -> eulerX negatif (< 0), mendongak -> positif (> 0)
                                val dyFace = max(1e-4, (chin.y() - fh.y()).toDouble())
                                val dzFace = (chin.z() - fh.z()).toDouble()
                                val landmarkPitchDeg = -(atan2(dzFace, dyFace) * 180.0 / Math.PI)
                                val landmarkYawDeg = ((nose.x() - (rCheek.x() + lCheek.x()) * 0.5) / eyeDist) * 32.0
                                val landmarkRollDeg = atan2(lEyeY - rEyeY, lEyeX - rEyeX) * 180.0 / Math.PI

                                val matrixOpt = mpResult.facialTransformationMatrixes()
                                if (matrixOpt.isPresent && matrixOpt.get().isNotEmpty()) {
                                    val m = matrixOpt.get()[0]
                                    if (m.size >= 16) {
                                        val r00 = m[0].toDouble()
                                        val r10 = m[1].toDouble()
                                        val r20 = m[2].toDouble()
                                        val r21 = m[6].toDouble()
                                        val r22 = m[10].toDouble()

                                        var matPitchDeg = -(atan2(r21, r22) * 180.0 / Math.PI)
                                        // Sinkronkan tanda terhadap geometri 3D landmark (chin.z - forehead.z > 0 saat menunduk)
                                        if (abs(landmarkPitchDeg) > 6.0 && matPitchDeg * landmarkPitchDeg < -20.0) {
                                            matPitchDeg = -matPitchDeg
                                        }
                                        eulerX = matPitchDeg.coerceIn(-45.0, 45.0)
                                        eulerY = (atan2(-r20, hypot(r21, r22)) * 180.0 / Math.PI).coerceIn(-60.0, 60.0)
                                        eulerZ = (atan2(r10, r00) * 180.0 / Math.PI).coerceIn(-45.0, 45.0)
                                    } else {
                                        eulerX = landmarkPitchDeg.coerceIn(-45.0, 45.0)
                                        eulerY = landmarkYawDeg.coerceIn(-60.0, 60.0)
                                        eulerZ = landmarkRollDeg.coerceIn(-45.0, 45.0)
                                    }
                                } else {
                                    eulerX = landmarkPitchDeg.coerceIn(-45.0, 45.0)
                                    eulerY = landmarkYawDeg.coerceIn(-60.0, 60.0)
                                    eulerZ = landmarkRollDeg.coerceIn(-45.0, 45.0)
                                }
                            }

                            val bsMap = HashMap<String, Double>(56)
                            val bsOpt = mpResult.faceBlendshapes()
                            if (bsOpt.isPresent && bsOpt.get().isNotEmpty()) {
                                for (cat in bsOpt.get()[0]) {
                                    val name = cat.categoryName()
                                    val score = cat.score().toDouble().coerceIn(0.0, 1.0)
                                    bsMap[name] = score
                                    frameMap["bs_$name"] = score
                                }
                            }

                            val pitchRad = -eulerX * Math.PI / 180.0
                            val yawRad = eulerY * Math.PI / 180.0
                            val lookRight = 0.5 * ((bsMap["eyeLookOutRight"] ?: 0.0) + (bsMap["eyeLookInLeft"] ?: 0.0))
                            val lookLeft = 0.5 * ((bsMap["eyeLookInRight"] ?: 0.0) + (bsMap["eyeLookOutLeft"] ?: 0.0))
                            val lookUp = 0.5 * ((bsMap["eyeLookUpLeft"] ?: 0.0) + (bsMap["eyeLookUpRight"] ?: 0.0))
                            val lookDown = 0.5 * ((bsMap["eyeLookDownLeft"] ?: 0.0) + (bsMap["eyeLookDownRight"] ?: 0.0))
                            gazeAngleX = yawRad * 0.65 + (lookRight - lookLeft) * 0.35
                            gazeAngleY = pitchRad * 0.75 + (lookDown - lookUp) * 0.35 + 0.16

                            val browInnerUp = bsMap["browInnerUp"] ?: 0.0
                            val browDownAvg = 0.5 * ((bsMap["browDownLeft"] ?: 0.0) + (bsMap["browDownRight"] ?: 0.0))
                            val blinkLeft = bsMap["eyeBlinkLeft"] ?: 0.0
                            val blinkRight = bsMap["eyeBlinkRight"] ?: 0.0
                            val eyeWideAvg = 0.5 * ((bsMap["eyeWideLeft"] ?: 0.0) + (bsMap["eyeWideRight"] ?: 0.0))
                            val cheekSquintAvg = 0.5 * ((bsMap["cheekSquintLeft"] ?: 0.0) + (bsMap["cheekSquintRight"] ?: 0.0))
                            val smileLeft = bsMap["mouthSmileLeft"] ?: 0.0
                            val smileRight = bsMap["mouthSmileRight"] ?: 0.0
                            val frownAvg = 0.5 * ((bsMap["mouthFrownLeft"] ?: 0.0) + (bsMap["mouthFrownRight"] ?: 0.0))
                            val jawOpen = bsMap["jawOpen"] ?: 0.0
                            val upperUpAvg = 0.5 * ((bsMap["mouthUpperUpLeft"] ?: 0.0) + (bsMap["mouthUpperUpRight"] ?: 0.0))

                            smilingProb = (0.5 * (smileLeft + smileRight)).coerceIn(0.0, 1.0)
                            leftEyeOpenProb = (1.0 - blinkLeft).coerceIn(0.0, 1.0)
                            rightEyeOpenProb = (1.0 - blinkRight).coerceIn(0.0, 1.0)

                            browActivation = (browInnerUp * 1.4 + browDownAvg * 1.8).coerceIn(0.05, 4.0)
                            eyeOpenness = ((leftEyeOpenProb + rightEyeOpenProb) * 0.55 + eyeWideAvg * 0.6).coerceIn(0.08, 2.5)
                            cheekActivation = (cheekSquintAvg * 2.0 + smilingProb * 0.4).coerceIn(0.05, 4.0)
                            mouthActivation = (smilingProb * 2.2 + upperUpAvg * 1.4).coerceIn(0.05, 4.0)
                            mouthOpenness = (jawOpen * 2.4).coerceIn(0.05, 4.0)

                            val bsAsym = 0.5 * (
                                abs(smileLeft - smileRight) +
                                    abs((bsMap["browDownLeft"] ?: 0.0) - (bsMap["browDownRight"] ?: 0.0))
                                )
                            asymmetry = (frownAvg * 0.75 + bsAsym * 0.45).coerceIn(0.0, 1.0)

                            // Aliran gerak geometris antar-frame dari 478 landmark & delta blendshapes
                            val currPts = ArrayList<Pair<Double, Double>>(128)
                            var k = 0
                            while (k < landmarks.size) {
                                currPts.add(Pair(landmarks[k].x().toDouble(), landmarks[k].y().toDouble()))
                                k += 4
                            }
                            var lmDisp = 0.0
                            val prevPts = prevMpLandmarks
                            if (prevPts != null && prevPts.size == currPts.size && currPts.isNotEmpty()) {
                                var sumDisp = 0.0
                                for (idx in currPts.indices) {
                                    sumDisp += hypot(
                                        currPts[idx].first - prevPts[idx].first,
                                        currPts[idx].second - prevPts[idx].second
                                    )
                                }
                                lmDisp = sumDisp / currPts.size
                            }
                            prevMpLandmarks = currPts

                            var bsDelta = 0.0
                            val prevBs = prevMpBlendshapes
                            if (prevBs != null && bsMap.isNotEmpty()) {
                                var bsDiffSum = 0.0
                                var bsCount = 0
                                for ((name, valCurr) in bsMap) {
                                    bsDiffSum += abs(valCurr - (prevBs[name] ?: valCurr))
                                    bsCount++
                                }
                                if (bsCount > 0) bsDelta = bsDiffSum / bsCount
                            }
                            prevMpBlendshapes = bsMap

                            motionEnergy = (lmDisp * 18.0 + bsDelta * 4.5).coerceIn(0.0, 3.0)
                        }
                    } catch (_: Throwable) {
                        faceFound = 0.0
                        confidence = 0.0
                    }

                    frameMap["usedMediaPipe"] = 1.0
                    frameMap["timeSec"] = timeUs / 1000000.0
                    frameMap["timestampMs"] = timeUs / 1000.0
                    frameMap["faceFound"] = faceFound
                    frameMap["confidence"] = confidence
                    frameMap["bboxLeft"] = bboxLeft
                    frameMap["bboxTop"] = bboxTop
                    frameMap["bboxRight"] = bboxRight
                    frameMap["bboxBottom"] = bboxBottom
                    frameMap["eulerX"] = eulerX
                    frameMap["eulerY"] = eulerY
                    frameMap["eulerZ"] = eulerZ
                    frameMap["eyeDistRatio"] = eyeDistRatio
                    frameMap["smilingProb"] = smilingProb
                    frameMap["leftEyeOpenProb"] = leftEyeOpenProb
                    frameMap["rightEyeOpenProb"] = rightEyeOpenProb
                    frameMap["gazeAngleX"] = gazeAngleX
                    frameMap["gazeAngleY"] = gazeAngleY
                    frameMap["browActivation"] = browActivation
                    frameMap["eyeOpenness"] = eyeOpenness
                    frameMap["cheekActivation"] = cheekActivation
                    frameMap["mouthActivation"] = mouthActivation
                    frameMap["mouthOpenness"] = mouthOpenness
                    frameMap["asymmetry"] = asymmetry
                    frameMap["motionEnergy"] = motionEnergy
                    frameFeatures.add(frameMap)

                    if (argbBitmap !== scaled) argbBitmap.recycle()
                    scaled.recycle()
                    rawBitmap.recycle()
                    continue
                }

                // Fallback ML Kit + luma regional bila FaceLandmarker gagal diinisialisasi
                var faceFound = 0.0
                var confidence = 0.0
                var eulerX = 0.0
                var eulerY = 0.0
                var eulerZ = 0.0
                var eyeDistRatio = 0.25
                var smilingProb = -1.0
                var leftEyeOpenProb = -1.0
                var rightEyeOpenProb = -1.0
                var gazeAngleX = 0.0
                var gazeAngleY = 0.16

                // Default bounding box tengah jika wajah tidak terdeteksi
                var cropLeft = (targetW * 0.22).toInt()
                var cropTop = (targetH * 0.18).toInt()
                var cropRight = (targetW * 0.78).toInt()
                var cropBottom = (targetH * 0.82).toInt()

                try {
                    val detector = mlkitDetector
                    if (detector != null) {
                        val inputImage = InputImage.fromBitmap(scaled, 0)
                        val faces = Tasks.await(detector.process(inputImage), 3, TimeUnit.SECONDS)

                        if (!faces.isNullOrEmpty()) {
                            // Pilih wajah dengan area bounding box terbesar sebagai subjek utama
                            val face = faces.maxByOrNull { f ->
                                f.boundingBox.width().coerceAtLeast(1) * f.boundingBox.height().coerceAtLeast(1)
                            }!!
                            val box = face.boundingBox
                            val boxAreaRatio = (box.width().coerceAtLeast(1) * box.height().coerceAtLeast(1)).toDouble() /
                                (targetW * targetH).toDouble()

                            facesDetectedCount++
                            faceFound = 1.0
                            eulerX = face.headEulerAngleX.toDouble()
                            eulerY = face.headEulerAngleY.toDouble()
                            eulerZ = face.headEulerAngleZ.toDouble()
                            smilingProb = face.smilingProbability?.toDouble()?.coerceIn(0.0, 1.0) ?: -1.0
                            leftEyeOpenProb = face.leftEyeOpenProbability?.toDouble()?.coerceIn(0.0, 1.0) ?: -1.0
                            rightEyeOpenProb = face.rightEyeOpenProbability?.toDouble()?.coerceIn(0.0, 1.0) ?: -1.0

                            val leftEye = face.getLandmark(FaceLandmark.LEFT_EYE)?.position
                            val rightEye = face.getLandmark(FaceLandmark.RIGHT_EYE)?.position
                            val noseBase = face.getLandmark(FaceLandmark.NOSE_BASE)?.position
                            val pitchRad = -eulerX * Math.PI / 180.0
                            val yawRad = eulerY * Math.PI / 180.0

                            if (leftEye != null && rightEye != null) {
                                val eyeDist = hypot(
                                    (rightEye.x - leftEye.x).toDouble(),
                                    (rightEye.y - leftEye.y).toDouble()
                                ).coerceAtLeast(16.0)
                                eyeDistRatio = (eyeDist / targetW.toDouble()).coerceIn(0.10, 0.48)
                                confidence = (0.86 + boxAreaRatio * 0.30).coerceIn(0.84, 0.99)
                                if (noseBase != null) {
                                    val midEyeX = (leftEye.x + rightEye.x) * 0.5
                                    val midEyeY = (leftEye.y + rightEye.y) * 0.5
                                    val dxNorm = ((noseBase.x - midEyeX) / eyeDist).coerceIn(-0.6, 0.6)
                                    val dyNorm = ((noseBase.y - midEyeY) / eyeDist).coerceIn(0.3, 1.2)
                                    gazeAngleX = yawRad * 0.65 + dxNorm * 0.35
                                    gazeAngleY = pitchRad * 0.75 + (dyNorm - 0.68) * 0.35 + 0.16
                                } else {
                                    gazeAngleX = yawRad
                                    gazeAngleY = pitchRad + 0.16
                                }
                            } else {
                                eyeDistRatio = (box.width().toDouble() * 0.38 / targetW.toDouble()).coerceIn(0.10, 0.48)
                                confidence = (0.78 + boxAreaRatio * 0.25).coerceIn(0.75, 0.94)
                                gazeAngleX = yawRad
                                gazeAngleY = pitchRad + 0.16
                            }

                            cropLeft = box.left.coerceIn(0, targetW - 16)
                            cropRight = box.right.coerceIn(cropLeft + 16, targetW)
                            cropTop = box.top.coerceIn(0, targetH - 16)
                            cropBottom = box.bottom.coerceIn(cropTop + 16, targetH)
                        }
                    }
                } catch (_: Throwable) {
                    faceFound = 0.0
                    confidence = 0.0
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

                val browGrad = computeRegionGradient(luma, normSize, 14, 8, 50, 22)
                val glabellaGrad = computeRegionGradient(luma, normSize, 24, 10, 40, 22)
                val foreheadMean = computeRegionMean(luma, normSize, 18, 6, 46, 15)
                val browMean = computeRegionMean(luma, normSize, 16, 15, 48, 23)
                val browContrast = (foreheadMean - browMean).coerceAtLeast(0.0)
                val browActivation = ((browGrad * 5.2) + (glabellaGrad * 4.5) + (browContrast * 3.8)).coerceIn(0.05, 4.0)

                val leftEyeVar = computeRegionVariance(luma, normSize, 12, 20, 28, 32)
                val rightEyeVar = computeRegionVariance(luma, normSize, 36, 20, 52, 32)
                val eyeGrad = (computeRegionGradient(luma, normSize, 12, 20, 28, 32) +
                        computeRegionGradient(luma, normSize, 36, 20, 52, 32)) * 0.5
                val eyeOpenness = (((leftEyeVar + rightEyeVar) * 6.5) + (eyeGrad * 3.2)).coerceIn(0.08, 2.5)

                val cheekGrad = computeRegionGradient(luma, normSize, 12, 29, 52, 44)
                val upperCheekMean = computeRegionMean(luma, normSize, 12, 28, 52, 36)
                val lowerCheekMean = computeRegionMean(luma, normSize, 14, 36, 50, 44)
                val cheekLift = (upperCheekMean - lowerCheekMean + 0.08).coerceIn(0.0, 0.5)
                val cheekActivation = ((cheekGrad * 5.8) + (cheekLift * 4.2)).coerceIn(0.05, 4.0)

                val mouthGrad = computeRegionGradient(luma, normSize, 16, 42, 48, 58)
                val mouthOpenVar = computeRegionVariance(luma, normSize, 22, 44, 42, 56)
                val upperCornerMean = (computeRegionMean(luma, normSize, 15, 43, 23, 49) +
                        computeRegionMean(luma, normSize, 41, 43, 49, 49)) * 0.5
                val lowerCornerMean = (computeRegionMean(luma, normSize, 15, 50, 23, 57) +
                        computeRegionMean(luma, normSize, 41, 50, 49, 57)) * 0.5
                val mouthCenterMean = computeRegionMean(luma, normSize, 25, 46, 39, 53)
                val cornerLift = (lowerCornerMean - upperCornerMean) + (cheekLift * 0.5) - (mouthCenterMean - lowerCornerMean) * 0.3
                val mouthActivation = ((mouthGrad * 6.5) + (cornerLift * 5.5) + 0.45).coerceIn(0.05, 4.0)
                val mouthOpenness = ((mouthOpenVar * 16.0) + (mouthGrad * 2.2)).coerceIn(0.05, 4.0)

                val symmetryDiff = computeLeftRightAsymmetry(luma, normSize)
                val depressorProxy = (symmetryDiff * 1.15 + (upperCornerMean - lowerCornerMean).coerceAtLeast(0.0) * 1.8).coerceIn(0.0, 1.0)

                if (abs(eulerX) < 1.5) {
                    val lowerJawMean = computeRegionMean(luma, normSize, 18, 46, 46, 60)
                    eulerX += ((lowerJawMean - foreheadMean) * 32.0).coerceIn(-18.0, 15.0)
                }

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
                        "usedMediaPipe" to 0.0,
                        "timeSec" to (timeUs / 1000000.0),
                        "timestampMs" to (timeUs / 1000.0),
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
                        "smilingProb" to smilingProb,
                        "leftEyeOpenProb" to leftEyeOpenProb,
                        "rightEyeOpenProb" to rightEyeOpenProb,
                        "gazeAngleX" to gazeAngleX,
                        "gazeAngleY" to gazeAngleY,
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
                if (argbBitmap !== scaled) argbBitmap.recycle()
                scaled.recycle()
                rawBitmap.recycle()
            }
        } finally {
            try {
                faceLandmarker?.close()
            } catch (_: Exception) {
            }
            try {
                mlkitDetector?.close()
            } catch (_: Exception) {
            }
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

    /** Memuat WAV PCM16 mono hasil MicSession (header 44 byte) sebagai sampel DSP. */
    private fun loadWavPcm(path: String): Map<String, Any> {
        val f = File(path)
        val rate = 16000
        val maxDspSamples = 240000
        val total = ((f.length() - 44) / 2).coerceAtLeast(0)
        val out = ArrayList<Double>(minOf(maxDspSamples.toLong(), total).toInt())
        java.io.BufferedInputStream(java.io.FileInputStream(f), 65536).use { ins ->
            ins.skip(44)
            val b = ByteArray(2)
            while (out.size < maxDspSamples && ins.read(b) == 2) {
                val v = ((b[1].toInt() shl 8) or (b[0].toInt() and 0xff)).toShort()
                out.add(v / 32768.0)
            }
        }
        if (total == 0L) {
            return hashMapOf("hasAudioTrack" to false, "sampleRate" to rate, "pcmSamples" to emptyList<Double>())
        }
        return hashMapOf(
            "hasAudioTrack" to true,
            "sampleRate" to rate,
            "wavPath" to path,
            "totalSamples" to total,
            "durationSec" to total.toDouble() / rate,
            "pcmSamples" to out
        )
    }
}
