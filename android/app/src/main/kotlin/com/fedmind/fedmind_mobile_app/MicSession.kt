package com.fedmind.fedmind_mobile_app

import android.app.Activity
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.io.RandomAccessFile
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/**
 * Satu-satunya pemegang mikrofon selama perekaman observasi.
 *
 * AudioRecord (16 kHz mono PCM16) membaca mikrofon sekali, lalu audio yang sama dipakai untuk:
 *  1. berkas WAV  -> fitur akustik (pitch, MFCC, dll.)
 *  2. pipe -> SpeechRecognizer (EXTRA_AUDIO_SOURCE, Android 13+) -> transkrip live
 * Dengan demikian recognizer tidak membuka mikrofon sendiri dan tidak berebut dengan perekam.
 */
class MicSession(
    private val activity: Activity,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val tag = "MicSession"
    private val main = Handler(Looper.getMainLooper())
    private val sampleRate = 16000

    @Volatile private var running = false
    @Volatile private var stopping = false

    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    private var feederThread: Thread? = null
    private val queue = LinkedBlockingQueue<ByteArray>(400)

    private var wavFile: File? = null
    private var raf: RandomAccessFile? = null
    private var totalBytes = 0L

    @Volatile private var pipeOut: OutputStream? = null
    private var readFd: ParcelFileDescriptor? = null
    private var recognizer: SpeechRecognizer? = null

    private val finalText = StringBuilder()
    private var partialText = ""
    private var errorStreak = 0
    private var finishCallback: ((Map<String, Any?>) -> Unit)? = null
    private var finished = false

    fun start(): String? {
        if (running) return null
        if (android.os.Build.VERSION.SDK_INT < 33) {
            return "Android 13+ diperlukan untuk transkrip paralel dengan perekaman audio."
        }
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            return "Layanan pengenalan suara tidak tersedia di perangkat ini."
        }

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) return "AudioRecord tidak mendukung konfigurasi 16 kHz mono."

        val rec = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 4
            )
        } catch (e: Exception) {
            return "Gagal membuat AudioRecord: ${e.message}"
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            return "AudioRecord gagal diinisialisasi (izin mikrofon / mikrofon sedang dipakai)."
        }

        try {
            val f = File.createTempFile("mic_session_", ".wav", activity.cacheDir)
            wavFile = f
            raf = RandomAccessFile(f, "rw").also { it.write(ByteArray(44)) }
        } catch (e: Exception) {
            rec.release()
            return "Gagal membuat berkas WAV: ${e.message}"
        }

        totalBytes = 0L
        finalText.clear()
        partialText = ""
        errorStreak = 0
        finished = false
        stopping = false
        queue.clear()
        audioRecord = rec
        running = true

        rec.startRecording()

        recordThread = Thread({
            val buf = ByteArray(3200) // 100 ms
            while (running) {
                val n = rec.read(buf, 0, buf.size)
                if (n > 0) {
                    try {
                        raf?.write(buf, 0, n)
                        totalBytes += n
                    } catch (_: IOException) {}
                    queue.offer(buf.copyOf(n)) // drop bila penuh, jangan blok perekaman
                } else if (n < 0) {
                    break
                }
            }
        }, "MicSession-record").also { it.start() }

        feederThread = Thread({
            while (running || queue.isNotEmpty()) {
                val chunk = try {
                    queue.poll(200, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) { null }
                if (chunk == null) {
                    if (!running) break else continue
                }
                val out = pipeOut ?: continue
                try {
                    out.write(chunk)
                    out.flush()
                } catch (_: IOException) {
                    // pipe ditutup oleh swap sesi; abaikan
                }
            }
        }, "MicSession-feeder").also { it.start() }

        main.post { beginRecognition() }
        return null
    }

    private fun beginRecognition() {
        if (!running) return
        try {
            try { recognizer?.destroy() } catch (_: Exception) {}
            // Recognizer standar (on-device di perangkat ini tidak punya paket id-ID -> error 13)
            val r = SpeechRecognizer.createSpeechRecognizer(activity)
            recognizer = r
            r.setRecognitionListener(listener)

            val pipe = ParcelFileDescriptor.createPipe()
            val oldOut = pipeOut
            val oldRead = readFd
            queue.clear() // jangan menyuapkan ulang audio lama ke sesi baru
            readFd = pipe[0]
            pipeOut = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
            try { oldOut?.close() } catch (_: Exception) {}
            try { oldRead?.close() } catch (_: Exception) {}

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra("android.speech.extra.AUDIO_SOURCE", pipe[0])
                putExtra("android.speech.extra.AUDIO_SOURCE_CHANNEL_COUNT", 1)
                putExtra("android.speech.extra.AUDIO_SOURCE_SAMPLING_RATE", sampleRate)
                putExtra("android.speech.extra.AUDIO_SOURCE_ENCODING", AudioFormat.ENCODING_PCM_16BIT)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 4000L)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3000L)
            }
            r.startListening(intent)
            Log.d(tag, "recognition session started")
        } catch (e: Exception) {
            Log.e(tag, "beginRecognition failed", e)
            emit(mapOf("type" to "error", "message" to "Gagal memulai recognizer: ${e.message}"))
            scheduleRestart(1000)
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        if (!running || stopping) return
        main.postDelayed({ beginRecognition() }, delayMs)
    }

    private fun commitPartial() {
        val p = partialText.trim()
        if (p.isNotEmpty()) {
            if (finalText.isNotEmpty()) finalText.append(' ')
            finalText.append(p)
        }
        partialText = ""
    }

    private fun currentFullText(): String =
        listOf(finalText.toString().trim(), partialText.trim())
            .filter { it.isNotEmpty() }
            .joinToString(" ")

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            emit(mapOf("type" to "status", "message" to "ready"))
        }
        override fun onBeginningOfSpeech() {
            // Ucapan baru dimulai: simpan hipotesis ucapan sebelumnya agar tidak tertimpa
            commitPartial()
            emit(mapOf("type" to "status", "message" to "speech"))
        }
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onPartialResults(partialResults: Bundle?) {
            val t = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.trim().orEmpty()
            Log.d(tag, "partial: $t")
            if (t.isNotEmpty()) {
                partialText = t
                emit(mapOf("type" to "transcript", "text" to currentFullText()))
            }
        }

        override fun onResults(results: Bundle?) {
            val t = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()?.trim().orEmpty()
            Log.d(tag, "final: $t")
            if (t.isNotEmpty()) {
                if (finalText.isNotEmpty()) finalText.append(' ')
                finalText.append(t)
                errorStreak = 0
                partialText = ""
            } else {
                // final kosong (mis. sesi ditutup di tengah ucapan): pertahankan hipotesis terakhir
                commitPartial()
            }
            emit(mapOf("type" to "transcript", "text" to currentFullText()))
            if (stopping) finish() else scheduleRestart(150)
        }

        override fun onError(error: Int) {
            Log.d(tag, "recognizer error=$error")
            // Simpan partial terakhir bila sesi berakhir tanpa hasil final
            if (partialText.isNotBlank()) {
                if (finalText.isNotEmpty()) finalText.append(' ')
                finalText.append(partialText.trim())
                partialText = ""
                emit(mapOf("type" to "transcript", "text" to currentFullText()))
            }
            emit(mapOf("type" to "error", "code" to error))
            if (stopping) { finish(); return }
            errorStreak++
            // 6 = SPEECH_TIMEOUT, 7 = NO_MATCH (normal saat hening), 8 = BUSY
            val delay = when (error) {
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> 800L
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT, SpeechRecognizer.ERROR_NO_MATCH -> 200L
                else -> 1000L
            }
            if (errorStreak < 40) scheduleRestart(delay)
        }
    }

    /** Hentikan perekaman; kembalikan transkrip final + path WAV lewat callback (main thread). */
    fun stop(callback: (Map<String, Any?>) -> Unit) {
        if (!running) {
            callback(mapOf("transcript" to "", "wavPath" to null))
            return
        }
        finishCallback = callback
        stopping = true
        running = false

        try { recordThread?.join(500) } catch (_: Exception) {}
        try { audioRecord?.stop() } catch (_: Exception) {}
        try { audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null

        try { feederThread?.join(500) } catch (_: Exception) {}
        // Tutup pipe -> recognizer menerima EOF dan memfinalkan hasil
        try { pipeOut?.close() } catch (_: Exception) {}
        pipeOut = null

        closeWav()

        // beri waktu hasil final terakhir masuk
        main.postDelayed({ finish() }, 4000)
    }

    private fun closeWav() {
        val r = raf ?: return
        try {
            val header = wavHeader(totalBytes, sampleRate)
            r.seek(0)
            r.write(header)
        } catch (_: Exception) {
        } finally {
            try { r.close() } catch (_: Exception) {}
            raf = null
        }
    }

    @Synchronized
    private fun finish() {
        if (finished) return
        finished = true
        try { recognizer?.destroy() } catch (_: Exception) {}
        recognizer = null
        try { readFd?.close() } catch (_: Exception) {}
        readFd = null

        if (partialText.isNotBlank()) {
            if (finalText.isNotEmpty()) finalText.append(' ')
            finalText.append(partialText.trim())
            partialText = ""
        }
        val path = if (totalBytes > 0) wavFile?.absolutePath else null
        val cb = finishCallback
        finishCallback = null
        main.post {
            cb?.invoke(
                mapOf(
                    "transcript" to finalText.toString().trim(),
                    "wavPath" to path,
                    "durationSec" to totalBytes / 2.0 / sampleRate
                )
            )
        }
    }

    private fun wavHeader(dataLen: Long, rate: Int): ByteArray {
        val h = ByteArray(44)
        val totalLen = dataLen + 36
        val byteRate = rate * 2
        fun putInt(off: Int, v: Long) {
            h[off] = (v and 0xff).toByte()
            h[off + 1] = ((v shr 8) and 0xff).toByte()
            h[off + 2] = ((v shr 16) and 0xff).toByte()
            h[off + 3] = ((v shr 24) and 0xff).toByte()
        }
        "RIFF".toByteArray().copyInto(h, 0)
        putInt(4, totalLen)
        "WAVEfmt ".toByteArray().copyInto(h, 8)
        putInt(16, 16)
        h[20] = 1; h[21] = 0 // PCM
        h[22] = 1; h[23] = 0 // mono
        putInt(24, rate.toLong())
        putInt(28, byteRate.toLong())
        h[32] = 2; h[33] = 0
        h[34] = 16; h[35] = 0
        "data".toByteArray().copyInto(h, 36)
        putInt(40, dataLen)
        return h
    }
}

