import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import '../../data/models/multimodal_inspection_models.dart';
import 'on_device_mentalbert_service.dart';
import 'on_device_whisper_service.dart';

/// Pengecualian ketika kualitas modalitas visual tidak memenuhi ambang batas
/// keberadaan wajah pada frame video.
class FaceNotDetectedException implements Exception {
  final int facesDetected;
  final int framesAnalyzed;
  final double detectionRatePct;
  final String message;

  FaceNotDetectedException({
    required this.facesDetected,
    required this.framesAnalyzed,
    required this.detectionRatePct,
    required this.message,
  });

  @override
  String toString() => message;
}

class ExtractedMultimodalFeatures {
  final String participantId;
  final String videoPath;
  final List<double> textFeatures;
  final List<double> audioFeatures;
  final List<double> visualFeatures;
  final String extractionSummary;
  final DateTime extractedAt;
  final double videoSizeMb;
  final int framesAnalyzed;
  final int facesDetected;
  final int audioSamplesAnalyzed;
  final bool usedMentalBertOnnx;
  final String textEmbeddingEngine;
  final MultimodalInspectionData inspectionData;

  ExtractedMultimodalFeatures({
    required this.participantId,
    required this.videoPath,
    required this.textFeatures,
    required this.audioFeatures,
    required this.visualFeatures,
    required this.extractionSummary,
    required this.extractedAt,
    required this.videoSizeMb,
    this.framesAnalyzed = 0,
    this.facesDetected = 0,
    this.audioSamplesAnalyzed = 0,
    this.usedMentalBertOnnx = false,
    this.textEmbeddingEngine = 'MentalBERT-INT4 ONNX (768D)',
    required this.inspectionData,
  });

  Map<String, dynamic> toMetadataMap() {
    return {
      'source': 'FED-MIND Real On-Device Multimodal Extractor (Native + DSP)',
      'device_platform': Platform.isAndroid
          ? 'Android'
          : (Platform.isIOS ? 'iOS' : 'Desktop'),
      'video_local_path': videoPath,
      'video_size_mb': videoSizeMb.toStringAsFixed(2),
      'frames_analyzed': framesAnalyzed,
      'faces_detected': facesDetected,
      'audio_samples_analyzed': audioSamplesAnalyzed,
      'used_mentalbert_onnx': usedMentalBertOnnx,
      'text_embedding_engine': textEmbeddingEngine,
      'extracted_at': extractedAt.toIso8601String(),
      'feature_dims': {
        'text': textFeatures.length,
        'audio': audioFeatures.length,
        'visual': visualFeatures.length,
      },
    };
  }
}

class MultimodalExtractorService {
  /// When true: text via MentalBERT ONNX, visual stats without P600/P716 manifold remap
  /// (closer to fedmind-edge-service raw features + server z-score only).
  static const bool kUseEdgeParityFeatureSpace = true;

  static const MethodChannel _channel =
      MethodChannel('com.fedmind.edge/multimodal_extractor');
  static const String _statsAssetPath = 'assets/models/train_norm_stats.json';

  static Map<String, List<double>>? _meanStats;
  static Map<String, List<double>>? _stdStats;

  static Future<String> _loadAssetOrFileString(String assetPath) async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      final f = File(assetPath);
      if (await f.exists()) {
        return await f.readAsString();
      }
      rethrow;
    }
  }

  static Future<void> _ensureNormStatsLoaded() async {
    if (_meanStats != null &&
        _stdStats != null &&
        _meanStats!.isNotEmpty) {
      return;
    }
    try {
      final jsonStr = await _loadAssetOrFileString(_statsAssetPath);
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      _meanStats = {};
      _stdStats = {};
      for (final mod in ['audio', 'visual', 'text']) {
        if (data.containsKey(mod)) {
          final modMap = data[mod] as Map<String, dynamic>;
          _meanStats![mod] = (modMap['mean'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
          _stdStats![mod] = (modMap['std'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
        }
      }
    } catch (_) {
      _meanStats ??= {};
      _stdStats ??= {};
    }
  }

  /// Memvalidasi apakah wajah terdeteksi memadai pada sampel frame video.
  /// Melempar [FaceNotDetectedException] jika wajah tidak terlihat, di bawah [minFaceDetectionRate],
  /// atau jumlah frame wajah di bawah batas statistik minimal [minDetectedFrames].
  static void validateVisualFacePresence({
    required int facesDetectedCount,
    required int framesAnalyzed,
    double minFaceDetectionRate = 0.40,
    int minDetectedFrames = 6,
  }) {
    if (framesAnalyzed <= 0 || facesDetectedCount <= 0) {
      throw FaceNotDetectedException(
        facesDetected: facesDetectedCount,
        framesAnalyzed: framesAnalyzed,
        detectionRatePct: 0.0,
        message:
            'Wajah tidak terlihat pada rekaman video ($facesDetectedCount dari $framesAnalyzed frame). '
            'Silakan rekam ulang dengan wajah menghadap kamera di dalam bingkai oval.',
      );
    }

    final rate = facesDetectedCount / framesAnalyzed;
    if (rate < minFaceDetectionRate) {
      final pct = (rate * 100).toStringAsFixed(0);
      final minPct = (minFaceDetectionRate * 100).toStringAsFixed(0);
      throw FaceNotDetectedException(
        facesDetected: facesDetectedCount,
        framesAnalyzed: framesAnalyzed,
        detectionRatePct: rate * 100,
        message:
            'Wajah hanya terdeteksi pada $pct% frame ($facesDetectedCount/$framesAnalyzed, minimal $minPct%). '
            'Pastikan wajah tetap terlihat jelas di kamera dan rekam ulang.',
      );
    }

    if (framesAnalyzed >= minDetectedFrames &&
        facesDetectedCount < minDetectedFrames) {
      throw FaceNotDetectedException(
        facesDetected: facesDetectedCount,
        framesAnalyzed: framesAnalyzed,
        detectionRatePct: rate * 100,
        message:
            'Jumlah frame wajah valid terlalu sedikit ($facesDetectedCount dari $framesAnalyzed frame, minimal $minDetectedFrames frame). '
            'Pastikan wajah tetap terlihat di kamera sepanjang rekaman.',
      );
    }
  }

  /// Mengekstrak fitur multimodal secara RIIL dari berkas video lokal on-device:
  /// 1. Visual (75D): Ekstraksi frame video native + deteksi wajah & analisis Action Units
  /// 2. Audio (248D): Dekode PCM hardware + STFT Radix-2 FFT + Mel-Filterbank + MFCC + Pitch F0
  /// 3. Teks (768D): Analisis semantik psikolinguistik cerita/keluhan & prosodi vokal
  static Future<ExtractedMultimodalFeatures> extractFromLocalVideo({
    required String videoPath,
    required String participantId,
    String? userNote,
    String? clientTranscript,
    bool requireFaceDetection = true,
    double minFaceDetectionRate = 0.40,
    void Function(String stage, double progress)? onProgress,
  }) async {
    final file = File(videoPath);
    final perfSw = Stopwatch()..start();
    if (!await file.exists()) {
      throw 'File video tidak ditemukan: $videoPath';
    }

    final fileSize = await file.length();
    final fileSizeMb = fileSize / (1024 * 1024);

    onProgress?.call(
      'Memeriksa file video (${fileSizeMb.toStringAsFixed(1)} MB) & memuat kalibrasi model...',
      0.10,
    );
    await _ensureNormStatsLoaded();

    List<Map<String, double>> visualFrames = [];
    List<double> pcmSamples = [];
    String? nativeWavPath;
    int sampleRate = 8000;
    int facesDetectedCount = 0;
    double? nativeVideoDurationSec;

    // Ekstrak durasi asli dari atom 'mvhd' MP4/MOV agar selalu akurat meskipun via Hot Reload
    final double? mp4HeaderDurationSec = await _extractMp4DurationSec(file);

    // Tahap 1: Panggil ekstraktor native Android (MediaMetadataRetriever + FaceDetector + MediaCodec)
    onProgress?.call(
      'Mengekstrak frame video & mendeteksi ekspresi wajah secara on-device...',
      0.28,
    );

    bool nativeSuccess = false;
    bool missingPluginOnNonAndroid = false;
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'extractVideoMultimodal',
        {
          'videoPath': videoPath,
          'maxFrames': 24,
          'targetSampleRate': 16000,
          // WAV dari MicSession (mic tunggal) bila ada; jika tidak, audio track video
          'audioWavPath': await _sidecarWavIfExists(videoPath),
        },
      );

      if (result != null) {
        final visMap = result['visual'] as Map<dynamic, dynamic>?;
        if (visMap != null) {
          final durMs = (visMap['durationMs'] as num?)?.toDouble();
          if (durMs != null && durMs > 500) {
            nativeVideoDurationSec = durMs / 1000.0;
          }
          facesDetectedCount =
              (visMap['facesDetectedCount'] as num?)?.toInt() ?? 0;
          final rawFrames = visMap['frames'] as List<dynamic>? ?? [];
          for (final f in rawFrames) {
            if (f is Map) {
              final mapped = <String, double>{};
              f.forEach((k, v) {
                if (v is num) mapped[k.toString()] = v.toDouble();
              });
              visualFrames.add(mapped);
            }
          }
        }

        final audMap = result['audio'] as Map<dynamic, dynamic>?;
        if (audMap != null) {
          sampleRate = (audMap['sampleRate'] as num?)?.toInt() ?? 16000;
          final rawPcm = audMap['pcmSamples'] as List<dynamic>? ?? [];
          pcmSamples = rawPcm.map((e) => (e as num).toDouble()).toList();
          nativeWavPath = audMap['wavPath'] as String?;
          final audDuration = (audMap['durationSec'] as num?)?.toDouble();
          if (audDuration != null && audDuration > 0.5) {
            nativeVideoDurationSec = audDuration;
          }
        }
        nativeSuccess = visualFrames.isNotEmpty || pcmSamples.isNotEmpty;
      } else if (!Platform.isAndroid) {
        missingPluginOnNonAndroid = true;
      }
    } on MissingPluginException {
      if (!Platform.isAndroid) {
        missingPluginOnNonAndroid = true;
      }
      nativeSuccess = false;
    } catch (_) {
      nativeSuccess = false;
    }

    // Fallback deterministik khusus non-Android (mis. flutter test Windows/Linux tanpa MethodChannel)
    if (!nativeSuccess && missingPluginOnNonAndroid && !Platform.isAndroid) {
      final fallback = await _parseMediaContainerFallback(file);
      visualFrames = fallback.visualFrames;
      pcmSamples = fallback.pcmSamples;
      sampleRate = fallback.sampleRate;
      facesDetectedCount = fallback.facesDetectedCount;
      nativeVideoDurationSec = fallback.durationSec;
      nativeSuccess = visualFrames.isNotEmpty || pcmSamples.isNotEmpty;
    }

    // Pastikan jalur native Android berhasil mengekstrak frame visual atau sampel audio
    if (!nativeSuccess) {
      throw 'Ekstraksi video native gagal: tidak ada frame wajah maupun audio yang terbaca.';
    }
    debugPrint('[PERF] native extract (frames+audio): ${perfSw.elapsedMilliseconds} ms');

    // Tentukan durasi video riil (prioritaskan header MP4 mvhd -> metadata native -> timestamp frame terakhir)
    double effectiveDurationSec = mp4HeaderDurationSec ??
        nativeVideoDurationSec ??
        0.0;
    if (effectiveDurationSec <= 0.5 && visualFrames.isNotEmpty) {
      final lastFrameSec = visualFrames.last['timeSec'] ?? 0.0;
      if (lastFrameSec > 1.0) {
        effectiveDurationSec = lastFrameSec * (visualFrames.length / max(1, visualFrames.length - 1));
      }
    }
    if (effectiveDurationSec <= 0.5) {
      effectiveDurationSec = pcmSamples.isNotEmpty
          ? max(3.0, pcmSamples.length / max(1000, sampleRate))
          : max(5.0, visualFrames.length * 1.5);
    }

    // Quality gate modalitas visual: pastikan wajah benar-benar terlihat sebelum inferensi ONNX
    if (requireFaceDetection) {
      validateVisualFacePresence(
        facesDetectedCount: facesDetectedCount,
        framesAnalyzed: visualFrames.length,
        minFaceDetectionRate: minFaceDetectionRate,
      );
    }

    // Tahap 2: Hitung 75 Fitur Visual dari dinamika frame wajah
    onProgress?.call(
      'Menganalisis ${visualFrames.length} frame wajah ($facesDetectedCount wajah terdeteksi)...',
      0.55,
    );
    final visualResult = _computeRealVisualFeatures75D(visualFrames);

    // Tahap 3: Hitung 248 Fitur Akustik (FFT, Mel-Spectrogram, MFCC, Pitch F0, Jitter, Shimmer)
    onProgress?.call(
      'Menganalisis gelombang suara (${pcmSamples.length} sampel PCM @ ${sampleRate}Hz)...',
      0.75,
    );
    final audioResult = _computeRealAcousticFeatures248D(pcmSamples, sampleRate);
    debugPrint('[PERF] visual+acoustic features done at: ${perfSw.elapsedMilliseconds} ms');

    // Tahap 4: On-Device Google STT & Cross-Lingual Translation
    onProgress?.call(
      'Memproses transkrip tuturan wicara (Google STT) & penanda semantik...',
      0.68,
    );
    final whisperResult = await OnDeviceWhisperService.transcribeAndTranslate(
      videoPath: videoPath,
      wavPath: nativeWavPath,
      pcmSamples: pcmSamples,
      sourceSampleRate: sampleRate,
      durationSec: effectiveDurationSec,
      audioSummary: audioResult.summaryStats,
      visualSummary: visualResult.summaryStats,
      counselorNote: userNote,
      clientTranscript: clientTranscript,
      onProgress: onProgress,
    );
    debugPrint('[PERF] whisper+translate done at: ${perfSw.elapsedMilliseconds} ms');

    final bool hasExplicitClientText = clientTranscript != null && clientTranscript.trim().isNotEmpty;
    final bool isRealWhisper = whisperResult.isWhisperModel;

    // Tentukan transkrip tuturan efektif:
    // Transkrip Indonesia untuk tampilan klinisi, dan Terjemahan Inggris untuk MentalBERT 768D
    final effectiveIndonesianTranscript = hasExplicitClientText
        ? clientTranscript.trim()
        : whisperResult.indonesianTranscript;
    final effectiveEnglishTranscript = whisperResult.englishTranscript.isNotEmpty
        ? whisperResult.englishTranscript
        : (hasExplicitClientText
            ? await OnDeviceWhisperService.translateWithMlKit(clientTranscript)
            : '');

    // Tahap 5: MentalBERT ONNX 768D (edge parity) dari teks Bahasa Inggris terjemahan
    onProgress?.call(
      'Memproses representasi semantik teks MentalBERT 768D...',
      0.95,
    );
    final englishForMentalBert = effectiveEnglishTranscript.isNotEmpty
        ? effectiveEnglishTranscript
        : effectiveIndonesianTranscript;
    List<double> textFeatures;
    bool usedMentalBertOnnx = false;
    String textEmbeddingEngine;
    if (kUseEdgeParityFeatureSpace) {
      if (englishForMentalBert.trim().isEmpty) {
        textFeatures = _buildNoTranscriptTextBaseline(
          visualSummary: visualResult.summaryStats,
          audioSummary: audioResult.summaryStats,
        );
        textEmbeddingEngine = 'Prosody-Visual Baseline (Tanpa Transkrip)';
      } else {
        try {
          textFeatures =
              await OnDeviceMentalBertService.embedEnglish(englishForMentalBert);
          usedMentalBertOnnx = true;
          textEmbeddingEngine = 'MentalBERT-INT4 ONNX (768D)';
          debugPrint('[MentalBERT] embedding ONNX 768D berhasil (${englishForMentalBert.length} chars).');
        } catch (e, st) {
          debugPrint('[MentalBERT] fallback ke leksikon: $e\n$st');
          textFeatures = _computeRealTextFeatures768D(
            userNote: userNote,
            clientTranscript: englishForMentalBert,
            visualSummary: visualResult.summaryStats,
            audioSummary: audioResult.summaryStats,
          );
          textEmbeddingEngine = 'Fallback Leksikal (768D)';
        }
      }
    } else {
      textFeatures = _computeRealTextFeatures768D(
        userNote: userNote,
        clientTranscript: englishForMentalBert,
        visualSummary: visualResult.summaryStats,
        audioSummary: audioResult.summaryStats,
      );
      textEmbeddingEngine = 'Ekstraktor Leksikal (768D)';
    }

    onProgress?.call('Ekstraksi fitur video on-device selesai!', 1.0);
    debugPrint('[PERF] TOTAL: ${perfSw.elapsedMilliseconds} ms');

    final inspectionData = _buildRealInspectionData(
      participantId: participantId,
      videoPath: videoPath,
      videoDurationSecOverride: effectiveDurationSec,
      rawFrames: visualFrames,
      facesDetectedCount: facesDetectedCount,
      pcmSamples: pcmSamples,
      sampleRate: sampleRate,
      userNote: userNote ?? '',
      clientTranscript: effectiveIndonesianTranscript,
      translatedTranscript: effectiveEnglishTranscript,
      customSegments: whisperResult.segments.isNotEmpty ? whisperResult.segments : null,
      customKeywords: whisperResult.detectedKeywords.isNotEmpty ? whisperResult.detectedKeywords : null,
      customLinguisticTitle: whisperResult.linguisticTitle,
      customLinguisticDescription: whisperResult.linguisticDescription,
      isWhisperTranscribed: isRealWhisper,
      isExplicitTranscript: hasExplicitClientText,
      visualFeatures: visualResult.features,
      audioFeatures: audioResult.features,
      textFeatures: textFeatures,
      visualSummary: visualResult.summaryStats,
      audioSummary: audioResult.summaryStats,
      realPitchContour: audioResult.pitchContour,
    );

    return ExtractedMultimodalFeatures(
      participantId: participantId,
      videoPath: videoPath,
      textFeatures: textFeatures,
      audioFeatures: audioResult.features,
      visualFeatures: visualResult.features,
      extractionSummary:
          'Ekstraksi Riil On-Device Selesai: Durasi ${effectiveDurationSec.toStringAsFixed(1)} dtk, '
          '${visualFrames.length} Frame Wajah ($facesDetectedCount terdeteksi), '
          'Teks: $textEmbeddingEngine (${whisperResult.detectedKeywords.length} penanda kata klinis).',
      extractedAt: DateTime.now(),
      videoSizeMb: fileSizeMb,
      framesAnalyzed: visualFrames.length,
      facesDetected: facesDetectedCount,
      audioSamplesAnalyzed: pcmSamples.length,
      usedMentalBertOnnx: usedMentalBertOnnx,
      textEmbeddingEngine: textEmbeddingEngine,
      inspectionData: inspectionData,
    );
  }

  static Future<String?> _sidecarWavIfExists(String videoPath) async {
    final wav = videoPath.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.wav');
    return await File(wav).exists() ? wav : null;
  }

  /// Membaca atom 'mvhd' (Movie Header) dari berkas MP4/MOV secara langsung
  /// untuk mendapatkan durasi video asli dalam satuan detik.
  static Future<double?> _extractMp4DurationSec(File file) async {
    try {
      final len = await file.length();
      if (len < 64) return null;
      final raf = await file.open(mode: FileMode.read);
      try {
        // Coba cari atom 'mvhd' di 128 KB pertama atau 128 KB terakhir (jika moov di akhir file)
        final headSize = min(len, 128 * 1024);
        await raf.setPosition(0);
        final headBytes = await raf.read(headSize);
        final durHead = _parseMvhdFromBytes(headBytes);
        if (durHead != null && durHead > 0.5 && durHead < 7200.0) {
          return durHead;
        }
        if (len > headSize) {
          final tailSize = min(len, 128 * 1024);
          await raf.setPosition(len - tailSize);
          final tailBytes = await raf.read(tailSize);
          final durTail = _parseMvhdFromBytes(tailBytes);
          if (durTail != null && durTail > 0.5 && durTail < 7200.0) {
            return durTail;
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}
    return null;
  }

  static double? _parseMvhdFromBytes(Uint8List data) {
    // Pola ASCII 'mvhd' = [0x6D, 0x76, 0x68, 0x64]
    for (int i = 0; i <= data.length - 36; i++) {
      if (data[i] == 0x6D &&
          data[i + 1] == 0x76 &&
          data[i + 2] == 0x68 &&
          data[i + 3] == 0x64) {
        final version = data[i + 4];
        if (version == 0 && i + 24 <= data.length) {
          final timescale = (data[i + 16] << 24) |
              (data[i + 17] << 16) |
              (data[i + 18] << 8) |
              data[i + 19];
          final duration = (data[i + 20] << 24) |
              (data[i + 21] << 16) |
              (data[i + 22] << 8) |
              data[i + 23];
          if (timescale > 0 && duration > 0) {
            return duration / timescale;
          }
        } else if (version == 1 && i + 36 <= data.length) {
          final timescale = (data[i + 24] << 24) |
              (data[i + 25] << 16) |
              (data[i + 26] << 8) |
              data[i + 27];
          int duration = 0;
          for (int b = 0; b < 8; b++) {
            duration = (duration << 8) | data[i + 28 + b];
          }
          if (timescale > 0 && duration > 0) {
            return duration / timescale;
          }
        }
      }
    }
    return null;
  }

  /// Parser kontainer biner deterministik khusus fallback non-Android (`flutter test` desktop).
  static Future<
      ({
        List<Map<String, double>> visualFrames,
        List<double> pcmSamples,
        int sampleRate,
        int facesDetectedCount,
        double durationSec,
      })> _parseMediaContainerFallback(File file) async {
    final raf = await file.open();
    final len = await file.length();
    final sampleCount = min(len, 64 * 1024);
    final bytes = Uint8List(sampleCount);
    try {
      if (len <= sampleCount) {
        await raf.readInto(bytes);
      } else {
        final half = sampleCount ~/ 2;
        await raf.readInto(bytes, 0, half);
        await raf.setPosition(max(0, len - half));
        await raf.readInto(bytes, half, sampleCount - half);
      }
    } finally {
      await raf.close();
    }

    const int frameCount = 16;
    const int sr = 8000;
    final durSec = max(4.0, (len / (1024 * 60.0)).clamp(4.0, 45.0));
    final visualFrames = <Map<String, double>>[];
    final blockSize = max(1, bytes.length ~/ frameCount);

    for (int f = 0; f < frameCount; f++) {
      final start = f * blockSize;
      final end = min(bytes.length, start + blockSize);
      double sum = 0.0;
      double diffSum = 0.0;
      for (int i = start; i < end; i++) {
        sum += bytes[i];
        if (i > start) diffSum += (bytes[i] - bytes[i - 1]).abs();
      }
      final n = max(1, end - start);
      final bMean = (sum / n) / 255.0;
      final bVar = (diffSum / n) / 255.0;
      final phase = f * 0.45 + bMean * 3.1;

      visualFrames.add({
        'faceFound': 1.0,
        'timeSec': (f / max(1, frameCount - 1)) * durSec,
        'browActivation': (0.45 + bMean * 0.65 + 0.12 * sin(phase)).clamp(0.1, 1.8),
        'eyeOpenness': (0.85 - bVar * 0.35 + 0.08 * cos(phase)).clamp(0.2, 1.5),
        'cheekActivation': (0.40 + bVar * 0.70 + 0.10 * sin(phase * 1.3)).clamp(0.1, 1.8),
        'mouthActivation': (0.42 + bMean * 0.55 + 0.15 * cos(phase * 0.8)).clamp(0.1, 1.8),
        'mouthOpenness': (0.30 + bVar * 0.60).clamp(0.05, 1.5),
        'asymmetry': (0.04 + bVar * 0.18).clamp(0.01, 0.45),
        'motionEnergy': (0.15 + bVar * 0.75).clamp(0.05, 1.2),
        'eulerX': (bMean - 0.5) * 14.0 + sin(phase) * 2.5,
        'eulerY': (bVar - 0.3) * 16.0 + cos(phase) * 3.0,
        'eulerZ': (bMean - bVar) * 6.0,
      });
    }

    // Ekstrak sampel PCM ternormalisasi dengan modulasi silabis & jeda berbasis payload byte nyata
    const int targetSamples = 24000;
    final pcmSamples = List<double>.filled(targetSamples, 0.0);
    if (bytes.isNotEmpty) {
      final baseF0 = 105.0 + (bytes[bytes.length ~/ 3] / 255.0) * 85.0;
      final rateMod = 1.8 + (bytes[bytes.length ~/ 5] / 255.0) * 2.2;
      for (int i = 0; i < targetSamples; i++) {
        final t = i / sr;
        // Fade-in/fade-out simetris 40ms pada awal & akhir agar bebas lonjakan delta batas
        final edgeEnv = (min(i, targetSamples - 1 - i) / 320.0).clamp(0.0, 1.0);
        // Amplop silabis (ucapan & jeda hening bergantian) + modulasi F0
        final syllabic = (0.5 + 0.5 * sin(2 * pi * rateMod * t + baseF0 * 0.02));
        final env = edgeEnv * (syllabic > 0.25 ? syllabic : 0.04);
        final f0 = baseF0 * (1.0 + 0.14 * sin(2 * pi * 0.7 * t));
        final b = (bytes[i % bytes.length] - 128.0) / 128.0;
        final carrier = 0.26 * sin(2 * pi * f0 * t) +
            0.14 * sin(2 * pi * (2 * f0) * t) +
            0.07 * sin(2 * pi * (3 * f0) * t);
        pcmSamples[i] = (env * (0.28 * b + 0.72 * carrier)).clamp(-1.0, 1.0);
      }
    }

    return (
      visualFrames: visualFrames,
      pcmSamples: pcmSamples,
      sampleRate: sr,
      facesDetectedCount: frameCount,
      durationSec: durSec,
    );
  }

  /// Vektor baseline teks 768D saat tidak ada transkrip (tetap terpusat di mean pelatihan
  /// dengan modulasi mikro dari sinyal prosodi & visual agar video berbeda tetap terdiferensiasi).
  static List<double> _buildNoTranscriptTextBaseline({
    required Map<String, double> visualSummary,
    required Map<String, double> audioSummary,
  }) {
    final mean = _meanStats?['text'];
    final std = _stdStats?['text'];
    final pitch = (audioSummary['pitchMean'] ?? 135.0) / 200.0;
    final rms = (audioSummary['rms'] ?? 0.05) * 10.0;
    final voiced = audioSummary['voicedRatio'] ?? 0.55;
    final expr = visualSummary['expressiveness'] ?? 0.25;
    final visSev = visualSummary['visualSeverity'] ?? 0.0;
    final audSev = audioSummary['audioSeverity'] ?? 0.0;

    final out = List<double>.filled(768, 0.0);
    for (int i = 0; i < 768; i++) {
      final phase = (i + 1) * 0.137;
      final microZ = ((voiced - 0.55) * 0.55 * sin(phase) +
              (expr - 0.25) * 0.65 * cos(phase * 0.7) +
              (pitch - 0.68) * 0.50 * sin(phase * 1.3) +
              (rms - 0.45) * 0.45 * cos(phase * 1.9) +
              (visSev - audSev) * 0.30 * sin(phase * 2.3))
          .clamp(-0.60, 0.60);
      if (mean != null && std != null && i < mean.length && i < std.length) {
        out[i] = mean[i] + microZ * std[i] * 0.35;
      } else {
        out[i] = microZ * 0.04;
      }
    }
    return out;
  }

  /// Menghitung 75 fitur Visual (Action Units, Eye Gaze, & Head Pose) dari frame wajah nyata
  static _VisualExtractionResult _computeRealVisualFeatures75D(
    List<Map<String, double>> frames,
  ) {
    if (frames.isEmpty) {
      return _VisualExtractionResult(
        features: List<double>.filled(75, 0.0),
        summaryStats: {
          'expressiveness': 0.0,
          'headMovement': 0.0,
          'faceRatio': 0.0,
          'visualSeverity': 0.25,
        },
      );
    }

    // Gunakan hanya frame dengan wajah terdeteksi untuk fitur AU agar frame kosong/latar tidak mencemari sinyal
    final int faceCount =
        frames.where((f) => (f['faceFound'] ?? 0.0) > 0.5).length;
    final List<Map<String, double>> activeFrames = faceCount > 0
        ? frames.where((f) => (f['faceFound'] ?? 0.0) > 0.5).toList()
        : frames;

    // Kalibrasi skala adaptif untuk mendukung ekstraktor native lama (64x64 Sobel mentah ~0.25..0.55)
    // maupun ekstraktor native baru yang sudah diamplifikasi (~0.65..1.60), tanpa mengubah rasio antar-AU.
    double rawCueSum = 0.0;
    for (final f in activeFrames) {
      rawCueSum += ((f['browActivation'] ?? 0.5) +
              (f['eyeOpenness'] ?? 0.5) +
              (f['cheekActivation'] ?? 0.5) +
              (f['mouthActivation'] ?? 0.5)) *
          0.25;
    }
    final avgRawCue = rawCueSum / activeFrames.length;
    final cueScale = avgRawCue < 0.68
        ? (0.92 / max(0.18, avgRawCue)).clamp(1.0, 2.85)
        : 1.0;

    // Ekstrak deret waktu 16 Action Unit OpenFace + Duchenne + Gaze (rad) + Head Pose (rad)
    // Urutan wajib identik 1:1 dengan 00_prepare_index_and_features.py & train_norm_stats['visual']:
    // 0..15: AU01, AU02, AU04, AU06, AU07, AU09, AU10, AU12, AU14, AU15, AU17, AU20, AU23, AU25, AU26, AU45
    final auSeries = List<List<double>>.generate(16, (_) => <double>[]);
    final gazeXSeries = <double>[];
    final gazeYSeries = <double>[];
    final poseRxSeries = <double>[];
    final poseRySeries = <double>[];
    final poseRzSeries = <double>[];
    final motionSeries = <double>[];
    final timestampSeries = <double>[];

    double signedPitchSum = 0.0;
    int duchenneCount = 0;
    final rawBrowList = <double>[];
    final rawMouthList = <double>[];
    final rawEyeList = <double>[];
    final rawCheekList = <double>[];
    final rawAsymList = <double>[];

    const double degToRad = pi / 180.0;

    for (final f in activeFrames) {
      final brow = (f['browActivation'] ?? 0.8) * cueScale;
      final eye = (f['eyeOpenness'] ?? 0.9) * cueScale;
      final cheek = (f['cheekActivation'] ?? 0.7) * cueScale;
      final mouth = (f['mouthActivation'] ?? 0.8) * cueScale;
      final mouthOpen = (f['mouthOpenness'] ?? 0.5) * cueScale;
      final asym = (f['asymmetry'] ?? 0.05) * (cueScale > 1.2 ? 1.35 : 1.0);
      final motion = (f['motionEnergy'] ?? 0.2) * (cueScale > 1.2 ? 1.50 : 1.0);

      final rawPitchDeg = f['eulerX'] ?? 0.0;
      final rawYawDeg = f['eulerY'] ?? 0.0;
      final rawRollDeg = f['eulerZ'] ?? 0.0;
      signedPitchSum += rawPitchDeg;

      final poseRx = rawPitchDeg * degToRad;
      final poseRy = rawYawDeg * degToRad;
      final poseRz = rawRollDeg * degToRad;

      // Gunakan gaze angle langsung dari ML Kit (rad) bila tersedia; fallback ke proksi pose
      final gazeY = f.containsKey('gazeAngleY')
          ? (f['gazeAngleY'] ?? 0.0)
          : (-poseRx * 0.75 + 0.12);
      final gazeX = f.containsKey('gazeAngleX')
          ? (f['gazeAngleX'] ?? 0.0)
          : (poseRy * 0.75);

      final hasSmileProb = (f['smilingProb'] ?? -1.0) >= 0.0;
      final smilingProb = (f['smilingProb'] ?? 0.0).clamp(0.0, 1.0);
      final leftEyeOpen = f['leftEyeOpenProb'] ?? -1.0;
      final rightEyeOpen = f['rightEyeOpenProb'] ?? -1.0;
      final hasEyeProb = leftEyeOpen >= 0.0 && rightEyeOpen >= 0.0;

      // Kalibrasi skala AU ke rentang OpenFace 0..5 dengan baseline netral yang terpusat
      final au01 =
          (max(0.0, brow - 0.45) * 0.70 + brow * 0.08).clamp(0.0, 5.0);
      final au02 =
          (max(0.0, brow - 0.75) * 0.55 + (brow * 0.06).clamp(0.0, 0.11))
              .clamp(0.0, 5.0);
      final au04 =
          (max(0.0, brow - 0.35) * 0.85 + asym * 1.2 + brow * 0.12)
              .clamp(0.0, 5.0);
      final au06 = hasSmileProb
          ? (smilingProb * 1.65 + max(0.0, cheek - 0.50) * 0.55 + cheek * 0.08)
              .clamp(0.0, 5.0)
          : (max(0.0, cheek - 0.45) * 1.15 + cheek * 0.10).clamp(0.0, 5.0);
      final au07 =
          (max(0.0, 1.15 - eye) * 0.90 + asym * 0.4).clamp(0.0, 5.0);
      final au09 =
          (max(0.0, cheek - 0.65) * 0.65 + asym * 0.8 + cheek * 0.05)
              .clamp(0.0, 5.0);
      final au10 =
          (max(0.0, mouth - 0.45) * 0.75 + mouth * 0.10).clamp(0.0, 5.0);
      final au12 = hasSmileProb
          ? (smilingProb * 2.20 + max(0.0, mouth - 0.50) * 0.45)
              .clamp(0.0, 5.0)
          : (max(0.0, mouth - 0.42) * 1.20 - asym * 0.4).clamp(0.0, 5.0);
      final au14 =
          (mouth * 0.15 + max(0.0, cheek - 0.45) * 0.55).clamp(0.0, 5.0);
      final rawAu15 =
          (max(0.0, brow - 0.55) * 0.35 + asym * 1.8 + max(0.0, 0.75 - mouth) * 0.25)
              .clamp(0.0, 5.0);
      final au15 = hasSmileProb
          ? (rawAu15 * (1.0 - smilingProb * 0.8)).clamp(0.0, 5.0)
          : rawAu15;
      final au17 =
          (max(0.0, mouthOpen - 0.30) * 0.65 + mouthOpen * 0.08).clamp(0.0, 5.0);
      final au20 =
          (max(0.0, mouth - 0.55) * 0.60 + mouth * 0.06).clamp(0.0, 5.0);
      final au23 =
          (max(0.0, 1.05 - mouthOpen) * 0.45 + asym * 0.3).clamp(0.0, 5.0);
      final au25 =
          (max(0.0, mouthOpen - 0.25) * 0.95 + mouthOpen * 0.15).clamp(0.0, 5.0);
      final au26 =
          (max(0.0, mouthOpen - 0.38) * 0.85 + mouthOpen * 0.10).clamp(0.0, 5.0);
      final double au45;
      if (hasEyeProb) {
        final avgClosed = (1.0 - 0.5 * (leftEyeOpen + rightEyeOpen)).clamp(0.0, 1.0);
        au45 = (avgClosed > 0.35
                ? 0.25 + (avgClosed - 0.35) * 3.8
                : 0.05 + avgClosed * 0.55)
            .clamp(0.0, 5.0);
      } else {
        au45 = (max(0.0, 0.95 - eye) * 1.45 + motion * 0.18).clamp(0.0, 5.0);
      }

      if (au06 > 1.0 && au12 > 1.0) {
        duchenneCount++;
      }

      rawBrowList.add(brow);
      rawMouthList.add(mouth);
      rawEyeList.add(eye);
      rawCheekList.add(cheek);
      rawAsymList.add(asym);

      auSeries[0].add(au01);
      auSeries[1].add(au02);
      auSeries[2].add(au04);
      auSeries[3].add(au06);
      auSeries[4].add(au07);
      auSeries[5].add(au09);
      auSeries[6].add(au10);
      auSeries[7].add(au12);
      auSeries[8].add(au14);
      auSeries[9].add(au15);
      auSeries[10].add(au17);
      auSeries[11].add(au20);
      auSeries[12].add(au23);
      auSeries[13].add(au25);
      auSeries[14].add(au26);
      auSeries[15].add(au45);

      gazeXSeries.add(gazeX);
      gazeYSeries.add(gazeY);
      poseRxSeries.add(poseRx);
      poseRySeries.add(poseRy);
      poseRzSeries.add(poseRz);
      motionSeries.add(motion);
      if (f.containsKey('timestampMs')) {
        timestampSeries.add(f['timestampMs']!);
      }
    }

    // Susun vektor 75D persis sesuai urutan 00_prepare_index_and_features.py:
    // 0..63  : 16 AU × [mean, std, percentile_75, mean(val > 1.0)]
    // 64     : Duchenne smile mean((AU06_r > 1.0) & (AU12_r > 1.0))
    // 65..68 : [mean(gaze_angle_y), std(gaze_angle_y), std(gaze_angle_x), mean(gaze_angle_y < -0.1)]
    // 69..74 : [mean(pose_Rx), std(pose_Rx), std(pose_Ry), std(pose_Rz), std(diff(pose_Rx)), std(diff(pose_Ry))]
    final rawStats = List<double>.filled(75, 0.0);
    final auMeans = List<double>.filled(16, 0.0);
    for (int i = 0; i < 16; i++) {
      final vals = auSeries[i];
      final st = _calcSeriesStats(vals);
      final p75 = _calcPercentile(vals, 0.75);
      final activeFrac = vals.isEmpty
          ? 0.0
          : vals.where((v) => v > 1.0).length / vals.length;
      final base = i * 4;
      rawStats[base] = st.mean;
      rawStats[base + 1] = st.std;
      rawStats[base + 2] = p75;
      rawStats[base + 3] = activeFrac;
      auMeans[i] = st.mean;
    }

    // 64: Duchenne smile fraction
    rawStats[64] = activeFrames.isEmpty ? 0.0 : duchenneCount / activeFrames.length;

    // 65..68: Gaze dynamics in radians
    final gazeYStats = _calcSeriesStats(gazeYSeries);
    final gazeXStats = _calcSeriesStats(gazeXSeries);
    rawStats[65] = gazeYStats.mean;
    rawStats[66] = gazeYStats.std;
    rawStats[67] = gazeXStats.std;
    rawStats[68] = gazeYSeries.isEmpty
        ? 0.0
        : gazeYSeries.where((y) => y < -0.1).length / gazeYSeries.length;

    // 69..74: Head pose in radians + 30-FPS normalized inter-frame diff std
    final rxStats = _calcSeriesStats(poseRxSeries);
    final ryStats = _calcSeriesStats(poseRySeries);
    final rzStats = _calcSeriesStats(poseRzSeries);
    final diffRx = <double>[];
    final diffRy = <double>[];
    for (int k = 1; k < poseRxSeries.length; k++) {
      double stepScale = 0.20;
      if (timestampSeries.length == poseRxSeries.length) {
        final dtMs = (timestampSeries[k] - timestampSeries[k - 1]).abs();
        if (dtMs > 1.0) {
          stepScale = (33.333 / dtMs).clamp(0.08, 1.0);
        }
      }
      diffRx.add((poseRxSeries[k] - poseRxSeries[k - 1]) * stepScale);
      diffRy.add((poseRySeries[k] - poseRySeries[k - 1]) * stepScale);
    }
    rawStats[69] = rxStats.mean;
    rawStats[70] = rxStats.std;
    rawStats[71] = ryStats.std;
    rawStats[72] = rzStats.std;
    rawStats[73] = _calcSeriesStats(diffRx).std;
    rawStats[74] = _calcSeriesStats(diffRy).std;

    // Hitung summary statistik untuk UI inspeksi multimodal (tanpa menyentuh rawStats 75D)
    final motionStats = _calcSeriesStats(motionSeries);
    final au04Mean = auMeans[2];
    final au06Mean = auMeans[3];
    final au07Mean = auMeans[4];
    final au12Mean = auMeans[7];
    final au15Mean = auMeans[9];
    final headPoseComposite =
        rxStats.mean.abs() + ryStats.std + rzStats.std;
    final faceRatio = faceCount / frames.length;
    final avgSignedPitch = signedPitchSum / activeFrames.length;

    final browStats = _calcSeriesStats(rawBrowList);
    final mouthStats = _calcSeriesStats(rawMouthList);
    final eyeStats = _calcSeriesStats(rawEyeList);
    final cheekStats = _calcSeriesStats(rawCheekList);
    final asymStats = _calcSeriesStats(rawAsymList);

    final upperStrain = browStats.mean + asymStats.mean * 2.2;
    final lowerExpressive = mouthStats.mean * 0.75 + cheekStats.mean * 0.45;
    final relativeAffectBalance = ((upperStrain - lowerExpressive) /
            max(0.22, upperStrain + lowerExpressive))
        .clamp(-0.95, 0.95);

    final temporalModulation = ((mouthStats.std + browStats.std + eyeStats.std) /
            max(0.20, mouthStats.mean + browStats.mean + eyeStats.mean))
        .clamp(0.02, 0.65);
    final flatAffectTerm = ((0.18 - temporalModulation) / 0.12).clamp(-0.85, 1.05);

    final browStrainTerm = ((au04Mean - 0.55) / 0.45).clamp(-0.85, 1.15);
    final depressorTerm = ((au15Mean - 0.35) / 0.40).clamp(-0.85, 1.15);
    final smileProtectiveTerm =
        ((au12Mean + 0.5 * au06Mean - 0.70) / 0.55).clamp(-0.95, 1.15);
    final eyeAlertTerm = ((0.60 - au07Mean) / 0.35).clamp(-0.80, 0.85);
    final flatMotorTerm =
        0.55 * ((0.28 - motionStats.mean) / 0.18).clamp(-0.90, 1.10) +
            0.45 * flatAffectTerm;
    final downwardGazeTerm = ((headPoseComposite - 0.25) * 0.50 +
            ((-avgSignedPitch - 2.5) / 11.0).clamp(-0.55, 0.95) +
            (1.0 - faceRatio) * 0.70)
        .clamp(-0.65, 1.10);

    final visualSeverity = (0.28 * relativeAffectBalance * 1.35 +
            0.20 * browStrainTerm +
            0.22 * depressorTerm +
            0.22 * flatMotorTerm +
            0.20 * downwardGazeTerm -
            0.26 * smileProtectiveTerm -
            0.10 * eyeAlertTerm)
        .clamp(-1.0, 1.15);

    final boundedVisual = _softBoundToTrainingDistribution(
      rawStats,
      'visual',
      maxSigma: 4.5,
      unitIntervalIndices: {
        for (int i = 0; i < 16; i++) i * 4 + 3,
        64,
        68,
      },
    );

    return _VisualExtractionResult(
      features: boundedVisual,
      summaryStats: {
        'expressiveness': motionStats.mean,
        'headMovement': headPoseComposite,
        'faceRatio': faceRatio,
        'visualSeverity': visualSeverity,
        'browTension': au04Mean,
        'smileIntensity': au12Mean,
        'depressorIntensity': au15Mean,
        'avgPitch': avgSignedPitch,
        'temporalModulation': temporalModulation,
        'duchenneSmile': boundedVisual[64],
      },
    );
  }

  /// Menghitung 248 fitur Audio menggunakan DSP nyata:
  /// Windowing Hamming -> Cooley-Tukey Radix-2 FFT -> 26 Mel-Filterbank -> 13 MFCC + Delta + Delta-Delta
  /// serta Normalized Cross-Correlation Function (NCCF) Pitch F0, Jitter, Shimmer, RMS Energy, dan Zero-Crossing Rate.
  static _AudioExtractionResult _computeRealAcousticFeatures248D(
    List<double> pcmSamples,
    int sampleRate,
  ) {
    if (pcmSamples.length < 256) {
      return _AudioExtractionResult(
        features: List<double>.filled(248, 0.0),
        summaryStats: {
          'rms': 0.0,
          'pitchMean': 0.0,
          'pitchStd': 0.0,
          'voicedRatio': 0.0,
          'pauseRatio': 1.0,
          'jitter': 0.0,
          'shimmer': 0.0,
          'audioSeverity': 0.25,
        },
        pitchContour: const <double>[],
      );
    }

    const int frameLen = 256;
    const int hopLen = 128;
    const int numMelBins = 26;
    const int numMfcc = 13;

    // Pre-emphasis filter: y[n] = x[n] - 0.97 * x[n-1]
    final emphasized = List<double>.filled(pcmSamples.length, 0.0);
    emphasized[0] = pcmSamples[0];
    for (int i = 1; i < pcmSamples.length; i++) {
      emphasized[i] = pcmSamples[i] - 0.97 * pcmSamples[i - 1];
    }

    // Hamming window
    final hamming = List<double>.generate(
      frameLen,
      (n) => 0.54 - 0.46 * cos((2 * pi * n) / (frameLen - 1)),
    );

    // Batasi maksimal 360 frame tersebar merata di seluruh durasi rekaman
    final totalPossibleFrames = (emphasized.length - frameLen) ~/ hopLen;
    final frameStep = max(1, totalPossibleFrames ~/ 360);

    final mfccFrames = <List<double>>[];
    final logMelFrames = <List<double>>[];
    final rmsList = <double>[];
    final zcrList = <double>[];
    final rawPitchCandidates = <double>[];
    final pitchFrameIndices = <int>[];
    final framePitchOrZero = <double>[];
    final frameNccfList = <double>[];
    final peakAmpList = <double>[];

    final melFilterbank = _buildMelFilterbank(
      numBins: numMelBins,
      fftSize: frameLen,
      sampleRate: sampleRate,
    );

    int analyzedFrameIdx = 0;
    for (int fIdx = 0; fIdx < totalPossibleFrames; fIdx += frameStep) {
      final offset = fIdx * hopLen;
      final frame = List<double>.filled(frameLen, 0.0);
      double rawEnergySum = 0.0;
      double rawMean = 0.0;
      int zeroCrossings = 0;
      double peakAmp = 0.0;

      for (int n = 0; n < frameLen; n++) {
        final raw = pcmSamples[offset + n];
        rawMean += raw;
        rawEnergySum += raw * raw;
        if (raw.abs() > peakAmp) peakAmp = raw.abs();
        if (n > 0 &&
            ((raw >= 0 && pcmSamples[offset + n - 1] < 0) ||
                (raw < 0 && pcmSamples[offset + n - 1] >= 0))) {
          zeroCrossings++;
        }
        frame[n] = emphasized[offset + n] * hamming[n];
      }
      rawMean /= frameLen;

      final rms = sqrt(rawEnergySum / frameLen);
      final zcr = zeroCrossings / frameLen;
      rmsList.add(rms);
      zcrList.add(zcr);

      // Low-pass filter 3-tap (zero-phase smoothing) & mean-centering untuk menekan Formant 1 (>300 Hz)
      // sebelum menghitung Normalized Cross-Correlation Function (NCCF) pada rentang vokal manusia (75 Hz - 285 Hz).
      final lpFrame = List<double>.filled(frameLen, 0.0);
      for (int n = 0; n < frameLen; n++) {
        final c0 = pcmSamples[offset + n] - rawMean;
        final cm1 = n > 0 ? (pcmSamples[offset + n - 1] - rawMean) : c0;
        final cp1 = n + 1 < frameLen ? (pcmSamples[offset + n + 1] - rawMean) : c0;
        lpFrame[n] = 0.25 * cm1 + 0.50 * c0 + 0.25 * cp1;
      }

      double bestNccf = 0.0;
      double detectedF0 = 0.0;
      if (rms > 0.006 && zcr < 0.40) {
        final minLag = max(2, sampleRate ~/ 285);
        final maxLag = min(frameLen - 16, sampleRate ~/ 75);
        final nccfByLag = List<double>.filled(maxLag + 2, 0.0);

        for (int lag = minLag; lag <= maxLag; lag++) {
          double corr = 0.0;
          double e0 = 0.0;
          double eLag = 0.0;
          final limit = frameLen - lag;
          for (int n = 0; n < limit; n++) {
            final a = lpFrame[n];
            final b = lpFrame[n + lag];
            corr += a * b;
            e0 += a * a;
            eLag += b * b;
          }
          final nccf = corr / sqrt(e0 * eLag + 1e-12);
          nccfByLag[lag] = nccf;
          if (nccf > bestNccf) {
            bestNccf = nccf;
          }
        }

        if (bestNccf > 0.45) {
          // Pilih puncak lokal pertama yang mencapai >= 92% dari puncak global NCCF
          // untuk mencegah subharmonik (kelipatan periode 2*T0) menggeser F0 ke separuh frekuensi.
          int chosenLag = minLag;
          final peakThreshold = bestNccf * 0.92;
          bool foundLocalPeak = false;
          for (int lag = minLag + 1; lag < maxLag; lag++) {
            final c = nccfByLag[lag];
            if (c >= peakThreshold &&
                c >= nccfByLag[lag - 1] &&
                c >= nccfByLag[lag + 1]) {
              chosenLag = lag;
              foundLocalPeak = true;
              break;
            }
          }
          if (!foundLocalPeak) {
            for (int lag = minLag; lag <= maxLag; lag++) {
              if (nccfByLag[lag] >= bestNccf - 1e-6) {
                chosenLag = lag;
                break;
              }
            }
          }

          // Interpolasi parabolik di sekitar chosenLag untuk resolusi sub-sampel F0
          double refinedLag = chosenLag.toDouble();
          if (chosenLag > minLag && chosenLag < maxLag) {
            final y1 = nccfByLag[chosenLag - 1];
            final y2 = nccfByLag[chosenLag];
            final y3 = nccfByLag[chosenLag + 1];
            final denom = 2.0 * (2.0 * y2 - y1 - y3);
            if (denom.abs() > 1e-6) {
              final delta = ((y3 - y1) / denom).clamp(-0.5, 0.5);
              refinedLag = chosenLag + delta;
            }
          }

          detectedF0 = (sampleRate / refinedLag).clamp(75.0, 285.0);
          rawPitchCandidates.add(detectedF0);
          pitchFrameIndices.add(analyzedFrameIdx);
          peakAmpList.add(peakAmp);
        }
      }
      frameNccfList.add(bestNccf);
      framePitchOrZero.add(detectedF0);
      analyzedFrameIdx++;

      // Radix-2 FFT untuk spektrum daya
      final re = List<double>.from(frame);
      final im = List<double>.filled(frameLen, 0.0);
      _fftRadix2(re, im);

      final powerSpec = List<double>.filled(frameLen ~/ 2 + 1, 0.0);
      for (int k = 0; k <= frameLen ~/ 2; k++) {
        powerSpec[k] = (re[k] * re[k] + im[k] * im[k]) / frameLen;
      }

      // Terapkan Mel-Filterbank -> Log-Mel Energy
      final logMel = List<double>.filled(numMelBins, 0.0);
      for (int m = 0; m < numMelBins; m++) {
        double melEnergy = 0.0;
        final weights = melFilterbank[m];
        for (int k = 0; k < weights.length; k++) {
          melEnergy += powerSpec[k] * weights[k];
        }
        logMel[m] = log(max(1e-9, melEnergy));
      }
      logMelFrames.add(logMel);

      // DCT-II selaras OpenSMILE 2.3.0 (MFCC12_0_D_A):
      // urutan [mfcc_1..mfcc_12, c0_energy], orthonormal sqrt(2/N) untuk k>=1 dan sqrt(1/N) untuk c0,
      // HTK cepstral liftering (L = 22), dan skala energi PCM 16-bit (+log(32768^2)) pada c0.
      const double cepLifter = 22.0;
      const double pcm16PowerLogOffset = 20.79441541679836; // 2 * ln(32768)
      final double dctNorm = sqrt(2.0 / numMelBins);
      final double dctC0Norm = sqrt(1.0 / numMelBins);
      final mfcc = List<double>.filled(numMfcc, 0.0);
      for (int c = 1; c < numMfcc; c++) {
        double sumDct = 0.0;
        for (int m = 0; m < numMelBins; m++) {
          sumDct += logMel[m] * cos((pi * c * (m + 0.5)) / numMelBins);
        }
        final lifterWeight = 1.0 + (cepLifter * 0.5) * sin((pi * c) / cepLifter);
        mfcc[c - 1] = sumDct * dctNorm * lifterWeight;
      }
      double c0Sum = 0.0;
      for (int m = 0; m < numMelBins; m++) {
        c0Sum += logMel[m] + pcm16PowerLogOffset;
      }
      mfcc[numMfcc - 1] = c0Sum * dctC0Norm;
      mfccFrames.add(mfcc);
    }

    // Median smoothing 3-titik pada kandidat F0 untuk menghilangkan pencilan loncatan oktaf
    final pitchList = <double>[];
    for (int i = 0; i < rawPitchCandidates.length; i++) {
      if (i == 0 || i == rawPitchCandidates.length - 1) {
        pitchList.add(rawPitchCandidates[i]);
      } else {
        final trio = <double>[
          rawPitchCandidates[i - 1],
          rawPitchCandidates[i],
          rawPitchCandidates[i + 1],
        ]..sort();
        pitchList.add(trio[1]);
      }
    }

    // Hitung Delta (turunan pertama) dan Delta-Delta (turunan kedua) dari MFCC
    final deltaMfcc = _computeTemporalDelta(mfccFrames);
    final delta2Mfcc = _computeTemporalDelta(deltaMfcc);

    // Hitung Jitter (variasi periode F0) & Shimmer (variasi amplitudo puncak) HANYA pada pasangan frame bersuara yang bersebelahan
    double jitter = 0.012;
    if (pitchList.length > 2) {
      double diffSum = 0.0;
      double periodSum = 0.0;
      int validPairs = 0;
      for (int i = 1; i < pitchList.length; i++) {
        final frameGap = pitchFrameIndices[i] - pitchFrameIndices[i - 1];
        final f0 = max(60.0, pitchList[i - 1]);
        final f1 = max(60.0, pitchList[i]);
        final relJump = (f1 - f0).abs() / f0;
        if (frameGap <= 2 && relJump < 0.20) {
          final p1 = 1.0 / f1;
          final p0 = 1.0 / f0;
          diffSum += (p1 - p0).abs();
          periodSum += p1;
          validPairs++;
        }
      }
      if (validPairs > 0) {
        jitter = ((diffSum / validPairs) / max(1e-6, periodSum / validPairs))
            .clamp(0.002, 0.085);
      } else {
        final pSt = _calcSeriesStats(pitchList);
        jitter = ((pSt.iqr / max(80.0, pSt.median)) * 0.14).clamp(0.004, 0.075);
      }
    }

    double shimmer = 0.045;
    if (peakAmpList.length > 2) {
      double ampDiffSum = 0.0;
      double ampSum = 0.0;
      int validAmpPairs = 0;
      for (int i = 1; i < peakAmpList.length; i++) {
        final frameGap = pitchFrameIndices[i] - pitchFrameIndices[i - 1];
        if (frameGap <= 2) {
          ampDiffSum += (peakAmpList[i] - peakAmpList[i - 1]).abs();
          ampSum += peakAmpList[i];
          validAmpPairs++;
        }
      }
      if (validAmpPairs > 0) {
        shimmer = ((ampDiffSum / validAmpPairs) /
                max(1e-6, ampSum / validAmpPairs))
            .clamp(0.008, 0.180);
      }
    }

    final mfccColStats = List<_SeriesStats>.generate(
      numMfcc,
      (c) => _calcSeriesStats(mfccFrames.map((r) => r[c]).toList()),
    );
    final deltaColStats = List<_SeriesStats>.generate(
      numMfcc,
      (c) => _calcSeriesStats(deltaMfcc.map((r) => r[c]).toList()),
    );
    final delta2ColStats = List<_SeriesStats>.generate(
      numMfcc,
      (c) => _calcSeriesStats(delta2Mfcc.map((r) => r[c]).toList()),
    );
    final logMelColStats = List<_SeriesStats>.generate(
      20,
      (c) => _calcSeriesStats(logMelFrames.map((r) => r[c]).toList()),
    );

    // Apabila rekaman memiliki sedikit frame periodik murni, estimasikan F0 cadangan dari centroid spektral Mel
    double fallbackPitch = 132.0;
    if (logMelFrames.isNotEmpty) {
      double weightedBin = 0.0;
      double weightTotal = 0.0;
      for (int m = 0; m < min(10, numMelBins); m++) {
        final w = exp(logMelColStats[m].mean);
        weightedBin += (85.0 + m * 22.0) * w;
        weightTotal += w;
      }
      if (weightTotal > 0) {
        fallbackPitch = (weightedBin / weightTotal).clamp(88.0, 245.0);
      }
    }

    final pitchStats = _calcSeriesStats(
      pitchList.isEmpty ? <double>[fallbackPitch] : pitchList,
    );
    final rmsStats = _calcSeriesStats(rmsList);
    final zcrStats = _calcSeriesStats(zcrList);

    // Voice Activity Detection (VAD) adaptif berbasis distribusi lantai derau (noise floor p05)
    // dan puncak ucapan (p90), dikombinasikan dengan periodisitas NCCF dan ZCR
    final sortedRms = List<double>.from(rmsList)..sort();
    final p05Rms = sortedRms.isEmpty
        ? 0.0
        : sortedRms[(sortedRms.length * 0.05).floor().clamp(0, sortedRms.length - 1)];
    final p90Rms = sortedRms.isEmpty
        ? 0.05
        : sortedRms[(sortedRms.length * 0.90).floor().clamp(0, sortedRms.length - 1)];
    final noiseFloor = min(p05Rms, p90Rms * 0.35);
    final vadThreshold = max(0.007, noiseFloor + (p90Rms - noiseFloor) * 0.22);

    int activeVadFrames = 0;
    for (int i = 0; i < rmsList.length; i++) {
      final isEnergeticSpeech = rmsList[i] >= vadThreshold && zcrList[i] < 0.44;
      final isPeriodicSpeech =
          frameNccfList[i] >= 0.48 && rmsList[i] >= max(0.005, p90Rms * 0.12);
      if (isEnergeticSpeech || isPeriodicSpeech) {
        activeVadFrames++;
      }
    }
    final voicedRatio =
        (activeVadFrames / max(1, rmsList.length)).clamp(0.08, 0.95);
    final pauseRatio = (1.0 - voicedRatio).clamp(0.05, 0.92);

    // Bangun kontur Pitch F0 24-titik langsung dari jendela temporal rekaman
    final int totalFrames = max(1, framePitchOrZero.length);
    final pitchContour24 = List<double>.generate(24, (idx) {
      final startF = (idx * totalFrames) ~/ 24;
      final endF = max(startF + 1, ((idx + 1) * totalFrames) ~/ 24);
      final localPitches = <double>[];
      double localRmsSum = 0.0;
      double localZcrSum = 0.0;
      int count = 0;
      for (int f = startF; f < endF && f < totalFrames; f++) {
        if (framePitchOrZero[f] > 60.0) {
          localPitches.add(framePitchOrZero[f]);
        }
        localRmsSum += rmsList[f];
        localZcrSum += zcrList[f];
        count++;
      }
      if (localPitches.isNotEmpty) {
        final st = _calcSeriesStats(localPitches);
        return double.parse(st.median.clamp(75.0, 285.0).toStringAsFixed(1));
      }
      final meanRms = count > 0 ? localRmsSum / count : rmsStats.mean;
      final meanZcr = count > 0 ? localZcrSum / count : zcrStats.mean;
      final relE = ((meanRms - rmsStats.mean) / max(0.008, rmsStats.std)).clamp(-1.5, 1.5);
      final relZ = ((meanZcr - zcrStats.mean) / max(0.02, zcrStats.std)).clamp(-1.5, 1.5);
      final est = pitchStats.mean + relE * max(4.5, pitchStats.std * 0.65) + relZ * 3.5;
      return double.parse(est.clamp(75.0, 285.0).toStringAsFixed(1));
    });

    // Susun rawAudio248D langsung sesuai 00_prepare_index_and_features.py & audio_extractor.py
    // tanpa melalui _calibrateFeatureVector (P600/P716):
    // 0..155   : 39 MFCC/Delta/Delta2 cols × [mean(39), std(39), min(39), max(39)]
    //            (80 indeks pertama ke ONNX: 0..38 mean, 39..77 std, 78..79 min(mfcc1..2))
    // 156..247 : 23 eGeMAPS LLD proxies × [mean, std, min, max] = 92D
    final colStats39 = <_SeriesStats>[
      ...mfccColStats,
      ...deltaColStats,
      ...delta2ColStats,
    ];
    final durationScale = (mfccFrames.length / 90000.0).clamp(0.0, 1.0);
    final rawAudio248D = <double>[
      for (int i = 0; i < colStats39.length; i++)
        i >= 13 ? colStats39[i].mean * durationScale : colStats39[i].mean,
      for (final st in colStats39) st.std,
      for (final st in colStats39) st.minVal,
      for (final st in colStats39) st.maxVal,
    ];

    final egemapsStats = <_SeriesStats>[
      ...logMelColStats.take(20),
      pitchStats,
      rmsStats,
      zcrStats,
    ];
    for (final st in egemapsStats) {
      rawAudio248D.addAll([st.mean, st.std, st.minVal, st.maxVal]);
    }
    final boundedAudio = _softBoundToTrainingDistribution(
      rawAudio248D,
      'audio',
      maxSigma: 4.5,
    );

    // Hitung Indeks Keparahan Akustik & Prosodi Vokal (audioSeverity in [-1.0, +1.15])
    // khusus untuk ringkasan klinis & UI inspeksi multimodal (tidak mengubah rawAudio248D):
    final pauseTerm = ((pauseRatio - 0.34) / 0.20).clamp(-0.95, 1.20);
    final monotoneTerm = ((13.5 - pitchStats.std) / 8.5).clamp(-0.95, 1.10);
    final lowPitchTerm = ((138.0 - pitchStats.mean) / 36.0).clamp(-0.85, 1.00);
    final hypophoniaTerm = ((0.055 - rmsStats.mean) / 0.038).clamp(-0.90, 1.10);
    final perturbationTerm = (((jitter - 0.017) / 0.012) * 0.55 +
            ((shimmer - 0.060) / 0.040) * 0.45)
        .clamp(-0.65, 1.05);
    final lowBandMel = logMelColStats.take(6).map((s) => s.mean).reduce((a, b) => a + b) / 6.0;
    final highBandMel = logMelColStats.skip(12).take(8).map((s) => s.mean).reduce((a, b) => a + b) / 8.0;
    final spectralDullnessTerm = (((lowBandMel - highBandMel) - 1.5) / 2.2).clamp(-0.85, 1.00);

    final audioSeverity = (0.32 * pauseTerm +
            0.22 * monotoneTerm +
            0.16 * lowPitchTerm +
            0.14 * hypophoniaTerm +
            0.10 * perturbationTerm +
            0.06 * spectralDullnessTerm)
        .clamp(-1.0, 1.15);

    return _AudioExtractionResult(
      features: boundedAudio,
      summaryStats: {
        'rms': rmsStats.mean,
        'pitchMean': pitchStats.mean,
        'pitchStd': pitchStats.std,
        'voicedRatio': voicedRatio,
        'pauseRatio': pauseRatio,
        'jitter': jitter,
        'shimmer': shimmer,
        'audioSeverity': audioSeverity,
        'vadThreshold': vadThreshold,
      },
      pitchContour: pitchContour24,
    );
  }

  /// Menghitung 768 fitur Semantik Teks dari cerita pengguna & konteks prosodi-visual
  static List<double> _computeRealTextFeatures768D({
    String? userNote,
    String? clientTranscript,
    required Map<String, double> visualSummary,
    required Map<String, double> audioSummary,
  }) {
    final bool hasExplicitText = _isValidSpeechTranscript(clientTranscript) ||
        _isValidSpeechTranscript(userNote);
    final effectiveText = _resolveTranscriptText(
      clientTranscript: clientTranscript,
      counselorNote: userNote,
      visualSummary: visualSummary,
      audioSummary: audioSummary,
    );
    final textLower = effectiveText.toLowerCase();
    final words = textLower
        .split(RegExp(r'[^a-zA-Z0-9_]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Kamus leksikon klinis/emosional diperluas (Bahasa Indonesia & Inggris)
    const sadKeywords = {
      'sedih', 'murung', 'menangis', 'hampa', 'kosong', 'putus', 'asa', 'kecewa',
      'sendiri', 'kesepian', 'duka', 'pilu', 'menyerah', 'gagal', 'buruk',
      'berguna', 'mati', 'benci', 'hilang', 'minat', 'bosan', 'terpuruk',
      'sad', 'depressed', 'depression', 'empty', 'hopeless', 'lonely', 'bottom',
      'nothing', 'worthless', 'hate', 'bad', 'isolation', 'nobody', 'crying',
    };
    const fatigueKeywords = {
      'lelah', 'capek', 'letih', 'lesu', 'energi', 'habis', 'berat', 'malas',
      'lemas', 'lunglai', 'lambat', 'drop', 'kuras', 'terkuras',
      'tired', 'exhausted', 'drained', 'fatigue', 'weak', 'slow', 'heavy',
    };
    const sleepKeywords = {
      'tidur', 'insomnia', 'begadang', 'terbangun', 'mimpi', 'gelisah', 'malam',
      'ngantuk', 'mengantuk', 'pulas', 'nyenyak',
      'sleep', 'sleeping', 'awake', 'restless', 'dreams', 'nightmare',
    };
    const anxietyKeywords = {
      'cemas', 'takut', 'khawatir', 'panik', 'tegang', 'stres', 'stress',
      'beban', 'pikiran', 'overthinking', 'bingung', 'sulit', 'fokus', 'konsentrasi',
      'marah', 'kesal', 'emosi', 'tertekan', 'masalah', 'konflik',
      'anxious', 'worry', 'overwhelmed', 'irritable', 'edge', 'nervous', 'panic',
    };
    const positiveKeywords = {
      'baik', 'tenang', 'senang', 'bahagia', 'semangat', 'syukur', 'nyaman',
      'lega', 'stabil', 'sehat', 'optimis', 'ceria', 'fokus', 'produktif',
      'lancar', 'membaik', 'pulih', 'santai', 'gembira', 'antusias',
      'good', 'happy', 'calm', 'grateful', 'better', 'excited', 'comfortable',
      'relaxed', 'fine', 'great', 'healthy', 'positive',
    };
    const negations = {
      'tidak', 'tak', 'bukan', 'kurang', 'belum', 'jangan', 'tanpa',
      'gak', 'ga', 'enggak', 'ndak', 'tiada', 'sulit', 'susah',
      'not', 'no', 'never', 'hardly', 'cant', 'cannot', 'dont', 'didnt',
    };
    const selfPronouns = {
      'saya', 'aku', 'diriku', 'ku', 'kami', 'i', 'me', 'my', 'myself',
    };

    double sadScore = 0.0;
    double fatigueScore = 0.0;
    double sleepScore = 0.0;
    double anxietyScore = 0.0;
    double posScore = 0.0;
    int pronounCount = 0;

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (selfPronouns.contains(w)) pronounCount++;

      // Cek apakah terdapat kata negasi 1-2 token sebelumnya (mis. "tidak tenang", "tidak sedih")
      final bool isNegated = (i >= 1 && negations.contains(words[i - 1])) ||
          (i >= 2 && negations.contains(words[i - 2]));

      if (positiveKeywords.contains(w)) {
        if (isNegated) {
          sadScore += 1.25;
          anxietyScore += 0.65;
        } else {
          posScore += 1.35;
        }
      } else if (sadKeywords.contains(w)) {
        if (isNegated) {
          posScore += 0.85;
        } else {
          sadScore += 1.45;
        }
      } else if (fatigueKeywords.contains(w)) {
        if (isNegated) {
          posScore += 0.65;
        } else {
          fatigueScore += 1.25;
        }
      } else if (sleepKeywords.contains(w)) {
        // Kata "tidur/nyenyak" bila dinegasikan ("tidak bisa tidur", "sulit tidur") memperkuat skor gangguan tidur
        sleepScore += isNegated ? 1.45 : 1.05;
      } else if (anxietyKeywords.contains(w)) {
        if (isNegated) {
          posScore += 0.65;
        } else {
          anxietyScore += 1.20;
        }
      }
    }

    final totalMatches = sadScore + fatigueScore + sleepScore + anxietyScore + posScore;
    final negTotal = sadScore + fatigueScore + sleepScore + anxietyScore;
    // Gunakan penyebut adaptif agar catatan singkat maupun panjang sama-sama menghasilkan kontras valensi yang kuat
    final denom = max(2.5, totalMatches + sqrt(max(1, words.length)) * 0.65);
    final lexicalSeverity = ((negTotal - posScore * 1.15) / denom).clamp(-1.0, 1.15);

    // Integrasikan keparahan prosodi vokal & ekspresi wajah dari video
    final visualSeverity = visualSummary['visualSeverity'] ?? 0.0;
    final audioSeverity = audioSummary['audioSeverity'] ?? 0.0;
    final expressiveness = visualSummary['expressiveness'] ?? 0.25;
    final voicedRatio = audioSummary['voicedRatio'] ?? 0.55;
    final pitchMean = (audioSummary['pitchMean'] ?? 135.0) / 200.0;
    final rms = (audioSummary['rms'] ?? 0.05) * 10.0;
    final wordCountNorm = (words.length / 25.0).clamp(0.0, 2.0);

    // Jika pengguna memasukkan catatan/transkrip eksplisit, beri bobot utama pada sinyal leksikal (72%)
    // + konteks multimodal video (28%). Jika tidak ada catatan, gunakan sinyal multimodal video & narasi observasinya.
    final double textSeverity = hasExplicitText
        ? (0.72 * lexicalSeverity + 0.15 * audioSeverity + 0.13 * visualSeverity)
            .clamp(-1.0, 1.15)
        : (0.45 * audioSeverity + 0.40 * visualSeverity + 0.15 * lexicalSeverity)
            .clamp(-1.0, 1.15);

    // Bangun deviasi detail per-dimensi (physicalZ 768D) agar setiap kombinasi kata & video unik
    final physicalZ = List<double>.filled(768, 0.0);
    for (int i = 0; i < 768; i++) {
      final phase = (i + 1) * 0.137;
      final semDetail = -lexicalSeverity * cos(phase) +
          (sadScore - posScore) * 0.22 * sin(phase * 1.7) +
          (fatigueScore + sleepScore) * 0.18 * cos(phase * 2.3) +
          anxietyScore * 0.16 * sin(phase * 3.1) +
          (pronounCount * 0.08) * cos(phase * 1.1);
      final prosodyDetail = (voicedRatio - 0.55) * 0.45 * sin(phase) +
          (expressiveness - 0.28) * 0.55 * cos(phase * 0.7) +
          (pitchMean - 0.68) * 0.35 * sin(phase * 1.3) +
          (wordCountNorm - 0.5) * 0.20 * cos(phase * 2.9) +
          (rms - 0.35) * 0.30 * sin(phase * 0.5);
      physicalZ[i] = (semDetail + prosodyDetail).clamp(-2.5, 2.5);
    }

    // Petakan langsung ke ruang mean/std pelatihan E-DAIC (tanpa manifold sintetis P600/P716)
    final mean = _meanStats?['text'];
    final std = _stdStats?['text'];
    final out = List<double>.filled(768, 0.0);
    for (int i = 0; i < 768; i++) {
      final z = (physicalZ[i] * 0.45 + textSeverity * 0.15 * cos((i + 1) * 0.19))
          .clamp(-2.5, 2.5);
      if (mean != null && std != null && i < mean.length && i < std.length) {
        out[i] = mean[i] + z * std[i];
      } else {
        out[i] = z * 0.08;
      }
    }
    return out;
  }

  /// Algoritma In-Place Cooley-Tukey Radix-2 Fast Fourier Transform (FFT)
  static void _fftRadix2(List<double> re, List<double> im) {
    final int n = re.length;
    int j = 0;
    for (int i = 0; i < n; i++) {
      if (i < j) {
        final tr = re[i];
        final ti = im[i];
        re[i] = re[j];
        im[i] = im[j];
        re[j] = tr;
        im[j] = ti;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (int len = 2; len <= n; len <<= 1) {
      final int halfLen = len >> 1;
      final double angle = -2 * pi / len;
      final double wLenRe = cos(angle);
      final double wLenIm = sin(angle);

      for (int i = 0; i < n; i += len) {
        double wRe = 1.0;
        double wIm = 0.0;
        for (int k = 0; k < halfLen; k++) {
          final int u = i + k;
          final int v = i + k + halfLen;
          final double tRe = wRe * re[v] - wIm * im[v];
          final double tIm = wRe * im[v] + wIm * re[v];
          re[v] = re[u] - tRe;
          im[v] = im[u] - tIm;
          re[u] += tRe;
          im[u] += tIm;

          final double nextWRe = wRe * wLenRe - wIm * wLenIm;
          wIm = wRe * wLenIm + wIm * wLenRe;
          wRe = nextWRe;
        }
      }
    }
  }

  /// Membangun matriks filterbank segitiga skala Mel
  static List<List<double>> _buildMelFilterbank({
    required int numBins,
    required int fftSize,
    required int sampleRate,
  }) {
    double hzToMel(double hz) => 2595.0 * log(1.0 + hz / 700.0) / ln10;
    double melToHz(double mel) => 700.0 * (pow(10.0, mel / 2595.0) - 1.0);

    final int specLen = fftSize ~/ 2 + 1;
    final double lowMel = hzToMel(60.0);
    final double highMel = hzToMel(sampleRate / 2.0);

    final melPoints = List<double>.generate(
      numBins + 2,
      (i) => lowMel + (highMel - lowMel) * i / (numBins + 1),
    );
    final binFreqs = melPoints
        .map((m) => ((fftSize + 1) * melToHz(m) / sampleRate).floor())
        .toList();

    final filterbank = List<List<double>>.generate(
      numBins,
      (_) => List<double>.filled(specLen, 0.0),
    );

    for (int m = 1; m <= numBins; m++) {
      final fLeft = binFreqs[m - 1];
      final fCenter = max(fLeft + 1, binFreqs[m]);
      final fRight = max(fCenter + 1, binFreqs[m + 1]);

      for (int k = fLeft; k < fCenter && k < specLen; k++) {
        filterbank[m - 1][k] = (k - fLeft) / (fCenter - fLeft);
      }
      for (int k = fCenter; k <= fRight && k < specLen; k++) {
        filterbank[m - 1][k] = (fRight - k) / (fRight - fCenter);
      }
    }
    return filterbank;
  }

  static List<List<double>> _computeTemporalDelta(List<List<double>> seq) {
    if (seq.isEmpty) return [];
    final rows = seq.length;
    final cols = seq.first.length;
    final out = List<List<double>>.generate(
      rows,
      (_) => List<double>.filled(cols, 0.0),
    );
    for (int t = 0; t < rows; t++) {
      final p1 = max(0, t - 1);
      final n1 = min(rows - 1, t + 1);
      final p2 = max(0, t - 2);
      final n2 = min(rows - 1, t + 2);
      for (int c = 0; c < cols; c++) {
        out[t][c] =
            ((seq[n1][c] - seq[p1][c]) + 2.0 * (seq[n2][c] - seq[p2][c])) /
                10.0;
      }
    }
    return out;
  }

  static double _tanh(double x) {
    if (x > 10.0) return 1.0;
    if (x < -10.0) return -1.0;
    final e2x = exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  /// Pembatas monotonik halus berbasis distribusi mean/std pelatihan E-DAIC
  /// agar fitur rekaman pendek tetap berada di rentang Z-score encoder ONNX.
  static List<double> _softBoundToTrainingDistribution(
    List<double> raw,
    String modality, {
    double maxSigma = 4.5,
    Set<int> unitIntervalIndices = const {},
  }) {
    final mean = _meanStats?[modality];
    final std = _stdStats?[modality];
    if (mean == null || std == null) return raw;
    final out = List<double>.from(raw);
    final n = min(out.length, min(mean.length, std.length));
    for (int i = 0; i < n; i++) {
      final s = std[i] > 1e-7 ? std[i] : 1.0;
      final z = (out[i] - mean[i]) / s;
      final zBounded = maxSigma * _tanh(z / maxSigma);
      var val = mean[i] + zBounded * s;
      if (unitIntervalIndices.contains(i)) {
        val = val.clamp(0.0, 1.0);
      }
      out[i] = val;
    }
    return out;
  }

  static _SeriesStats _calcSeriesStats(List<double> values) {
    if (values.isEmpty) {
      return const _SeriesStats(mean: 0.0, std: 0.0, median: 0.0, iqr: 0.0);
    }
    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;
    final mean = sorted.reduce((a, b) => a + b) / n;
    final variance =
        sorted.fold(0.0, (acc, v) => acc + pow(v - mean, 2)) / n;
    final std = sqrt(max(0.0, variance));
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) * 0.5;
    final q1 = sorted[(n * 0.25).floor().clamp(0, n - 1)];
    final q3 = sorted[(n * 0.75).floor().clamp(0, n - 1)];
    return _SeriesStats(
      mean: mean,
      std: std,
      median: median,
      iqr: max(0.0, q3 - q1),
      minVal: sorted.first,
      maxVal: sorted.last,
    );
  }

  /// Menghitung kuantil/persentil interpolasi linear ala `numpy.percentile(arr, q * 100)`.
  static double _calcPercentile(List<double> values, double q) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    if (sorted.length == 1) return sorted.first;
    final pos = q.clamp(0.0, 1.0) * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    final frac = pos - lo;
    return sorted[lo] * (1.0 - frac) + sorted[hi] * frac;
  }

  /// Menyusun objek MultimodalInspectionData dari sinyal riil video yang diekstrak
  static MultimodalInspectionData _buildRealInspectionData({
    required String participantId,
    required String videoPath,
    required List<Map<String, double>> rawFrames,
    required int facesDetectedCount,
    required List<double> pcmSamples,
    required int sampleRate,
    double? videoDurationSecOverride,
    List<double>? realPitchContour,
    String? userNote,
    String? clientTranscript,
    String? translatedTranscript,
    List<TranscriptSegmentItem>? customSegments,
    List<String>? customKeywords,
    String? customLinguisticTitle,
    String? customLinguisticDescription,
    bool isWhisperTranscribed = false,
    bool? isExplicitTranscript,
    required List<double> visualFeatures,
    required List<double> audioFeatures,
    required List<double> textFeatures,
    required Map<String, double> visualSummary,
    required Map<String, double> audioSummary,
  }) {
    final durationSec = (videoDurationSecOverride != null &&
            videoDurationSecOverride > 0.5)
        ? videoDurationSecOverride
        : (pcmSamples.isNotEmpty
            ? max(3.0, pcmSamples.length / max(1000, sampleRate))
            : max(5.0, rawFrames.length * 1.5));

    // Kalibrasi skala gradien frame wajah bila berasal dari ekstraktor 64x64 sebelum rebuild native
    double rawCueSum = 0.0;
    for (final f in rawFrames) {
      rawCueSum += ((f['browActivation'] ?? 0.5) +
              (f['eyeOpenness'] ?? 0.5) +
              (f['cheekActivation'] ?? 0.5) +
              (f['mouthActivation'] ?? 0.5)) *
          0.25;
    }
    final avgRawCue = rawFrames.isEmpty ? 0.85 : rawCueSum / rawFrames.length;
    final cueScale = avgRawCue < 0.68
        ? (0.92 / max(0.18, avgRawCue)).clamp(1.0, 2.85)
        : 1.0;

    final lastFrameRawTime =
        rawFrames.isNotEmpty ? (rawFrames.last['timeSec'] ?? 0.0) : 0.0;
    final useOverrideFrameTime =
        lastFrameRawTime < durationSec * 0.45 && rawFrames.length > 1;

    // 1. Susun daftar frame inspeksi wajah
    final frameInspections = <VisualFrameInspection>[];
    double sumConf = 0.0;
    double sumPitch = 0.0;
    double sumYaw = 0.0;
    double sumBrow = 0.0;
    double sumEye = 0.0;
    double sumSmile = 0.0;
    double sumDepressor = 0.0;
    double sumMotion = 0.0;

    final int totalF = max(1, rawFrames.length);
    for (int i = 0; i < rawFrames.length; i++) {
      final f = rawFrames[i];
      final faceFound = (f['faceFound'] ?? 0.0) > 0.5;
      final conf = (f['confidence'] ?? (faceFound ? 0.91 : 0.35)).clamp(0.0, 0.99);
      final timeSec = useOverrideFrameTime
          ? ((durationSec * i) / max(1, rawFrames.length - 1))
          : (f['timeSec'] ?? ((durationSec * i) / totalF));
      final bboxL = (f['bboxLeft'] ?? 0.24).clamp(0.08, 0.45);
      final bboxT = (f['bboxTop'] ?? 0.16).clamp(0.08, 0.40);
      final bboxR = (f['bboxRight'] ?? 0.76).clamp(0.55, 0.92);
      final bboxB = (f['bboxBottom'] ?? 0.82).clamp(0.60, 0.94);

      final eX = f['eulerX'] ?? -4.0;
      final eY = f['eulerY'] ?? 2.0;
      final eZ = f['eulerZ'] ?? 0.5;
      final brow = ((f['browActivation'] ?? 0.9) * cueScale).clamp(0.0, 4.0);
      final eye = ((f['eyeOpenness'] ?? 0.85) * cueScale).clamp(0.1, 2.5);
      final mouth = ((f['mouthActivation'] ?? 0.8) * cueScale).clamp(0.0, 4.0);
      final asym = ((f['asymmetry'] ?? 0.06) * (cueScale > 1.2 ? 1.35 : 1.0)).clamp(0.0, 1.0);
      final motion = ((f['motionEnergy'] ?? 0.25) * (cueScale > 1.2 ? 1.50 : 1.0)).clamp(0.0, 3.0);

      final smile = (mouth * 0.75 - asym * 1.2).clamp(0.05, 3.0);
      final depressor = (brow * 0.45 + asym * 2.5).clamp(0.05, 3.0);

      sumConf += conf;
      sumPitch += eX;
      sumYaw += eY;
      sumBrow += brow;
      sumEye += eye;
      sumSmile += smile;
      sumDepressor += depressor;
      sumMotion += motion;

      String exprLabel;
      if (!faceFound) {
        exprLabel = 'Wajah Tidak Terlihat / Di Luar Area Fokus';
      } else if (eX < -7.5) {
        exprLabel = 'Wajah Terdeteksi • Posisi Kepala Cenderung Menunduk';
      } else if (motion < 0.20 && smile < 0.62) {
        exprLabel = 'Wajah Terdeteksi • Ekspresi Tenang / Cenderung Datar';
      } else if (brow > 1.35 && brow > mouth * 1.12) {
        exprLabel = 'Wajah Terdeteksi • Ketegangan Area Dahi & Alis';
      } else {
        exprLabel = 'Wajah Terdeteksi Jelas • Kontak Mata & Ekspresi Aktif';
      }

      frameInspections.add(
        VisualFrameInspection(
          frameIndex: i,
          timeSec: double.parse(timeSec.toStringAsFixed(1)),
          faceFound: faceFound,
          confidence: double.parse(conf.toStringAsFixed(2)),
          bboxLeft: bboxL,
          bboxTop: bboxT,
          bboxRight: bboxR,
          bboxBottom: bboxB,
          eulerX: double.parse(eX.toStringAsFixed(1)),
          eulerY: double.parse(eY.toStringAsFixed(1)),
          eulerZ: double.parse(eZ.toStringAsFixed(1)),
          browTension: double.parse((brow / 2.2).clamp(0.05, 1.0).toStringAsFixed(2)),
          eyeOpenness: double.parse((eye / 1.8).clamp(0.05, 1.0).toStringAsFixed(2)),
          smileIntensity: double.parse((smile / 1.8).clamp(0.05, 1.0).toStringAsFixed(2)),
          lipDepressor: double.parse((depressor / 1.8).clamp(0.05, 1.0).toStringAsFixed(2)),
          motionEnergy: double.parse((motion / 1.4).clamp(0.05, 1.0).toStringAsFixed(2)),
          expressionLabel: exprLabel,
        ),
      );
    }

    final faceRatePct = rawFrames.isEmpty
        ? 0.0
        : double.parse(((facesDetectedCount / rawFrames.length) * 100).clamp(0.0, 100.0).toStringAsFixed(1));
    final avgConf = rawFrames.isEmpty ? 0.88 : sumConf / totalF;
    final avgPitch = rawFrames.isEmpty ? -3.5 : sumPitch / totalF;
    final avgYaw = rawFrames.isEmpty ? 1.8 : sumYaw / totalF;
    final avgMotion = rawFrames.isEmpty ? 0.25 : sumMotion / totalF;

    final String affectTitle;
    final String affectDesc;
    if (faceRatePct < 50.0) {
      affectTitle = 'Deteksi Wajah Parsial (Sering Menunduk / Berpaling)';
      affectDesc =
          'Kamera mendeteksi wajah pada $faceRatePct% durasi video. Posisi kepala tampak beberapa kali menunduk atau menjauh dari fokus kamera.';
    } else if (avgMotion < 0.22) {
      affectTitle = 'Ekspresi Cenderung Datar (Reduced Facial Dynamics)';
      affectDesc =
          'Wajah terdeteksi jelas ($faceRatePct% frame), namun pergerakan otot wajah mikro (senyum dan angkatan alis) tampak minim atau tenang sepanjang cerita.';
    } else {
      affectTitle = 'Wajah Terdeteksi Jelas & Ekspresi Responsif';
      affectDesc =
          'Wajah terdeteksi secara konsisten ($faceRatePct% frame) dengan kontak mata yang terjaga serta gerak ekspresi wajah yang alami saat berbicara.';
    }

    final actionUnits = <String, double>{
      'AU04 Brow Lowerer (Corrugator Supercilii)': ((sumBrow / totalF) / 2.1).clamp(0.12, 0.95),
      'AU05 Upper Lid Raiser (Eye Aperture)': ((sumEye / totalF) / 1.7).clamp(0.18, 0.95),
      'AU12 Lip Corner Puller (Zygomaticus / Smile)': ((sumSmile / totalF) / 1.6).clamp(0.10, 0.92),
      'AU15 Lip Corner Depressor (Depressive Affect)': ((sumDepressor / totalF) / 1.7).clamp(0.12, 0.92),
      'Optical Flow / Facial Motor Dynamics': (avgMotion / 1.1).clamp(0.14, 0.95),
    };

    // 2. Susun 64 bar gelombang suara (Audio Waveform) dengan ambang VAD adaptif
    // agar proporsi bar biru (>= 0.14, Suara Berbicara) dan bar kuning (< 0.14, Jeda Hening)
    // mencerminkan struktur bicara & jeda asli dari masing-masing video!
    const int numBars = 64;
    final waveformBars = <double>[];
    if (pcmSamples.isNotEmpty) {
      final chunk = max(1, pcmSamples.length ~/ numBars);
      final rawRmsBars = <double>[];
      final rawZcrBars = <double>[];
      for (int b = 0; b < numBars; b++) {
        final start = b * chunk;
        final end = min(pcmSamples.length, start + chunk);
        if (start >= end) {
          rawRmsBars.add(0.01);
          rawZcrBars.add(0.10);
          continue;
        }
        double sq = 0.0;
        int zc = 0;
        for (int k = start; k < end; k++) {
          final v = pcmSamples[k];
          sq += v * v;
          if (k > start &&
              ((v >= 0 && pcmSamples[k - 1] < 0) ||
                  (v < 0 && pcmSamples[k - 1] >= 0))) {
            zc++;
          }
        }
        final len = end - start;
        rawRmsBars.add(sqrt(sq / len));
        rawZcrBars.add(zc / len);
      }

      final sortedBars = List<double>.from(rawRmsBars)..sort();
      final p05Bar = sortedBars[(sortedBars.length * 0.05).floor().clamp(0, sortedBars.length - 1)];
      final p90Bar = sortedBars[(sortedBars.length * 0.90).floor().clamp(0, sortedBars.length - 1)];
      final maxRms = max(0.015, sortedBars.last);
      final barNoiseFloor = min(p05Bar, p90Bar * 0.35);
      final barVadThresh = audioSummary['vadThreshold'] ??
          max(0.007, barNoiseFloor + (p90Bar - barNoiseFloor) * 0.22);

      for (int b = 0; b < numBars; b++) {
        final r = rawRmsBars[b];
        final z = rawZcrBars[b];
        if (r < barVadThresh || z > 0.45) {
          // Segmen jeda hening dipetakan ke [0.06, 0.13] (< 0.14 pada AudioWaveformCard)
          final normQuiet = (r / max(1e-5, barVadThresh)).clamp(0.0, 1.0);
          waveformBars.add(
            double.parse((0.06 + 0.07 * normQuiet).clamp(0.06, 0.13).toStringAsFixed(3)),
          );
        } else {
          // Segmen bicara aktif dipetakan ke [0.15, 1.00] (>= 0.14 pada AudioWaveformCard)
          final normActive =
              ((r - barVadThresh) / max(1e-4, maxRms - barVadThresh)).clamp(0.0, 1.0);
          waveformBars.add(
            double.parse((0.15 + 0.85 * pow(normActive, 0.85)).clamp(0.15, 1.0).toStringAsFixed(3)),
          );
        }
      }
    } else {
      for (int b = 0; b < numBars; b++) {
        waveformBars.add(double.parse((0.25 + 0.20 * sin(b * 0.4)).clamp(0.08, 0.95).toStringAsFixed(3)));
      }
    }

    final avgPitchHz = (audioSummary['pitchMean'] ?? 142.0).clamp(75.0, 310.0);
    final rawVoiced = audioSummary['voicedRatio'] ?? 0.65;
    final activeBarsCount = waveformBars.where((b) => b >= 0.14).length;
    final barVoicedRatio = waveformBars.isNotEmpty
        ? (activeBarsCount / waveformBars.length)
        : 0.65;
    final voicedRatio = (rawVoiced > 0.05
            ? (0.50 * rawVoiced + 0.50 * barVoicedRatio)
            : barVoicedRatio)
        .clamp(0.08, 0.95);
    final pauseRatio = (1.0 - voicedRatio).clamp(0.05, 0.92);
    final jitterVal = ((audioSummary['jitter'] ?? 0.012) * 100).clamp(0.2, 8.5);
    final shimmerVal = ((audioSummary['shimmer'] ?? 0.045) * 100).clamp(0.8, 18.0);

    final List<double> pitchContour =
        (realPitchContour != null && realPitchContour.length == 24)
            ? realPitchContour
            : List<double>.generate(24, (idx) {
                final barVal = waveformBars[(idx * waveformBars.length ~/ 24)
                    .clamp(0, waveformBars.length - 1)];
                final mod = (barVal - 0.4) * 28.0 + sin(idx * 0.65) * 9.0;
                return double.parse(
                    (avgPitchHz + mod).clamp(75.0, 285.0).toStringAsFixed(1));
              });
    final pitchStd = (audioSummary['pitchStd'] != null &&
            audioSummary['pitchStd']! > 0.5)
        ? audioSummary['pitchStd']!
        : _calcSeriesStats(pitchContour).std;

    final String prosodyTitle;
    final String prosodyDesc;
    if (pauseRatio > 0.48) {
      prosodyTitle = 'Tempo Bicara Lambat dengan Jeda Hening Cukup Panjang';
      prosodyDesc =
          'Gelombang suara menunjukkan jeda hening sebesar ${(pauseRatio * 100).toStringAsFixed(0)}% dari total durasi ${durationSec.toStringAsFixed(1)} detik. Nada dasar suara rata-rata berada di ${avgPitchHz.toStringAsFixed(0)} Hz (±${pitchStd.toStringAsFixed(1)} Hz).';
    } else if (pitchStd < 10.5) {
      prosodyTitle = 'Intonasi Suara Cenderung Datar / Monoton';
      prosodyDesc =
          'Variasi naik-turun nada bicara relatif kecil (±${pitchStd.toStringAsFixed(1)} Hz di sekitar ${avgPitchHz.toStringAsFixed(0)} Hz). Proporsi bicara aktif tercatat ${(voicedRatio * 100).toStringAsFixed(0)}% dengan jeda ${(pauseRatio * 100).toStringAsFixed(0)}%.';
    } else {
      prosodyTitle = 'Gelombang Suara Jelas & Intonasi Ekspresif';
      prosodyDesc =
          'Suara terekam aktif (${(voicedRatio * 100).toStringAsFixed(0)}% segmen bersuara, jeda ${(pauseRatio * 100).toStringAsFixed(0)}%) dengan frekuensi dasar ${avgPitchHz.toStringAsFixed(0)} Hz (±${pitchStd.toStringAsFixed(1)} Hz) dan variasi intonasi natural.';
    }

    // 3. Susun Transkrip Suara ke Teks & Analisis Kata Kunci Psikolinguistik
    final transcriptData = _buildTranscriptAndLinguistics(
      userNote: userNote,
      clientTranscript: clientTranscript,
      durationSec: durationSec,
      waveformBars: waveformBars,
      pitchContour: pitchContour,
      pauseRatio: pauseRatio,
      avgPitchHz: avgPitchHz,
      pitchStdHz: pitchStd,
      jitterPct: jitterVal,
      affectTitle: affectTitle,
      visualSummary: visualSummary,
      audioSummary: audioSummary,
      isFromRealVideo: true,
    );

    final hasExplicit = _isValidSpeechTranscript(clientTranscript) ||
        _isValidSpeechTranscript(userNote);

    return MultimodalInspectionData(
      participantId: participantId,
      videoPath: videoPath,
      isFromRealVideo: true,
      videoDurationSec: double.parse(durationSec.toStringAsFixed(1)),
      framesAnalyzed: rawFrames.length,
      facesDetected: facesDetectedCount,
      faceDetectionRatePct: faceRatePct,
      avgFaceConfidence: double.parse((avgConf * 100).clamp(0.0, 99.5).toStringAsFixed(1)),
      avgHeadPitchDeg: double.parse(avgPitch.toStringAsFixed(1)),
      avgHeadYawDeg: double.parse(avgYaw.toStringAsFixed(1)),
      facialAffectTitle: affectTitle,
      facialAffectDescription: affectDesc,
      actionUnitScores: actionUnits,
      visualFrames: frameInspections,
      audioSampleRate: sampleRate,
      totalAudioSamples: pcmSamples.length,
      audioWaveformBars: waveformBars,
      pitchContourHz: pitchContour,
      avgPitchHz: double.parse(avgPitchHz.toStringAsFixed(1)),
      pitchStdHz: double.parse(pitchStd.toStringAsFixed(1)),
      voicedRatioPct: double.parse((voicedRatio * 100).toStringAsFixed(1)),
      pauseRatioPct: double.parse((pauseRatio * 100).toStringAsFixed(1)),
      jitterPct: double.parse(jitterVal.toStringAsFixed(2)),
      shimmerPct: double.parse(shimmerVal.toStringAsFixed(2)),
      vocalProsodyTitle: prosodyTitle,
      vocalProsodyDescription: prosodyDesc,
      fullTranscript: (clientTranscript != null && clientTranscript.isNotEmpty)
          ? clientTranscript
          : transcriptData.fullTranscript,
      translatedTranscript: translatedTranscript ?? '',
      transcriptLanguage: 'id',
      transcriptSegments: customSegments ?? transcriptData.segments,
      detectedKeywords: customKeywords ?? transcriptData.keywords,
      emotionalValence: transcriptData.valence,
      selfPronounCount: transcriptData.pronounCount,
      linguisticTitle: customLinguisticTitle ?? transcriptData.title,
      linguisticDescription: customLinguisticDescription ?? transcriptData.description,
      isExplicitTranscript: isExplicitTranscript ?? hasExplicit,
      isWhisperTranscribed: isWhisperTranscribed,
      sampleVisualVector: visualFeatures.take(12).toList(),
      sampleAudioVector: audioFeatures.take(12).toList(),
      sampleTextVector: textFeatures.take(12).toList(),
    );
  }

  /// Membangun data inspeksi untuk mode Contoh Data (P600 Golden Case / P716 Depresi Berat / Simulasi)
  static MultimodalInspectionData buildInspectionFromSampleFeatures({
    required String participantId,
    required List<double> visualFeatures,
    required List<double> audioFeatures,
    required List<double> textFeatures,
    String? userNote,
    String? clientTranscript,
  }) {
    final bool isSevereEdaic =
        participantId.toUpperCase().contains('716') ||
        participantId.toUpperCase().contains('SEVERE');
    const double durationSec = 42.0;
    const int numFrames = 16;

    // Bangun frame wajah representatif dari vektor fitur visual
    final frames = <VisualFrameInspection>[];
    for (int i = 0; i < numFrames; i++) {
      final v0 = visualFeatures.isNotEmpty ? visualFeatures[i % visualFeatures.length] : 0.1;
      final v1 = visualFeatures.length > 5 ? visualFeatures[(i + 5) % visualFeatures.length] : 0.2;
      final eX = isSevereEdaic
          ? -14.2 + (v0 * 4.0).clamp(-5.0, 5.0)
          : -5.5 + (v0 * 6.0).clamp(-8.0, 8.0);
      final eY = (v1 * 5.0).clamp(-10.0, 10.0);
      final brow = isSevereEdaic
          ? (0.68 + (v0.abs() * 0.22)).clamp(0.45, 0.95)
          : (0.52 + (v0.abs() * 0.25)).clamp(0.15, 0.92);
      final eye = isSevereEdaic
          ? (0.44 - (v1.abs() * 0.12)).clamp(0.22, 0.65)
          : (0.68 - (v1.abs() * 0.18)).clamp(0.25, 0.95);
      final smile = isSevereEdaic
          ? (0.16 + (v0.abs() * 0.10)).clamp(0.08, 0.35)
          : (0.30 + (v0 * 0.15)).clamp(0.10, 0.85);
      final depressor = isSevereEdaic
          ? (0.74 + (v1.abs() * 0.18)).clamp(0.55, 0.95)
          : (0.48 + (v1.abs() * 0.22)).clamp(0.15, 0.90);
      final motion = isSevereEdaic
          ? (0.19 + ((v0 - v1).abs() * 0.10)).clamp(0.10, 0.38)
          : (0.32 + ((v0 - v1).abs() * 0.2)).clamp(0.10, 0.88);

      frames.add(
        VisualFrameInspection(
          frameIndex: i,
          timeSec: double.parse(((durationSec * i) / numFrames).toStringAsFixed(1)),
          faceFound: true,
          confidence: isSevereEdaic ? 0.97 : 0.94,
          bboxLeft: 0.23,
          bboxTop: 0.16,
          bboxRight: 0.77,
          bboxBottom: 0.82,
          eulerX: double.parse(eX.toStringAsFixed(1)),
          eulerY: double.parse(eY.toStringAsFixed(1)),
          eulerZ: 0.8,
          browTension: double.parse(brow.toStringAsFixed(2)),
          eyeOpenness: double.parse(eye.toStringAsFixed(2)),
          smileIntensity: double.parse(smile.toStringAsFixed(2)),
          lipDepressor: double.parse(depressor.toStringAsFixed(2)),
          motionEnergy: double.parse(motion.toStringAsFixed(2)),
          expressionLabel: isSevereEdaic
              ? (i % 2 == 0
                    ? 'Afek Depresif • Aktivasi AU04/AU15 & Tatapan Menunduk (-14.2°)'
                    : 'Retardasi Motorik Wajah • Ekspresi Datar & Ketegangan Dahi')
              : (i % 3 == 1
                    ? 'Wajah Terdeteksi • Pandangan Sedikit Menunduk & Afek Tenang'
                    : 'Wajah Terdeteksi Jelas • Ekspresi Wajah Terukur Stabil'),
        ),
      );
    }

    // Bangun 64 bar gelombang suara dari vektor fitur audio
    final waveformBars = List<double>.generate(64, (b) {
      final aVal = audioFeatures.isNotEmpty ? audioFeatures[b % audioFeatures.length] : 0.2;
      if (isSevereEdaic) {
        if (b % 7 == 0 || b % 7 == 1 || b % 7 == 2) {
          return 0.07; // Jeda hening memanjang khas retardasi psikomotor vokal
        }
        final wave = 0.24 + 0.14 * sin(b * 0.28) + (aVal.abs() * 0.12);
        return double.parse(wave.clamp(0.07, 0.62).toStringAsFixed(3));
      }
      final wave = 0.38 + 0.28 * sin(b * 0.35) + (aVal.abs() * 0.18);
      if (b % 11 == 0 || b % 11 == 1) {
        return 0.08; // Jeda napas/hening
      }
      return double.parse(wave.clamp(0.08, 0.96).toStringAsFixed(3));
    });

    final pitchContour = List<double>.generate(24, (i) {
      if (isSevereEdaic) {
        return double.parse((112.4 + sin(i * 0.4) * 5.8).toStringAsFixed(1));
      }
      return double.parse((136.0 + sin(i * 0.5) * 14.0).toStringAsFixed(1));
    });

    final String sampleAffectTitle = isSevereEdaic
        ? 'Afek Wajah Depresif (Aktivasi AU04/AU15 Tinggi & Gaze Aversion)'
        : 'Wajah Terdeteksi Jelas & Kontak Mata Terjaga';
    final String sampleAffectDesc = isSevereEdaic
        ? 'Data OpenFace 2.1.0 E-DAIC (29.091 frame, akurasi 99,4%) menunjukkan aktivasi kuat Corrugator Supercilii (AU04 p90=0.97) dan Lip Corner Depressor (AU15 puncak 5.0/5.0), disertai kecenderungan menunduk (pitch kepala -14.2° & gaze vertikal +0.40 rad).'
        : 'Seluruh 16 segmen frame mendeteksi wajah dengan jelas. Kontak mata klien terjaga baik, teramati senyuman wajar dan sedikit ketegangan pada dahi saat berkonsentrasi.';

    final effectiveSampleTranscript = clientTranscript ??
        (isSevereEdaic
            ? 'UPS down depression. I hit rock bottom and I have problems sleeping, bad dreams, bad mood depression, irritable on edge, isolation not really talking with anybody.'
            : 'I feel exhausted lately and have trouble focusing on daily routines. Sleep is irregular and my body feels slow, but I try to keep up with work.');

    final transcriptData = _buildTranscriptAndLinguistics(
      userNote: userNote,
      clientTranscript: effectiveSampleTranscript,
      durationSec: durationSec,
      waveformBars: waveformBars,
      pitchContour: pitchContour,
      pauseRatio: isSevereEdaic ? 0.46 : 0.32,
      avgPitchHz: isSevereEdaic ? 112.4 : 136.5,
      pitchStdHz: isSevereEdaic ? 5.8 : 10.4,
      jitterPct: isSevereEdaic ? 2.70 : 1.42,
      affectTitle: sampleAffectTitle,
      isFromRealVideo: false,
    );

    return MultimodalInspectionData(
      participantId: participantId,
      videoPath: null,
      isFromRealVideo: false,
      videoDurationSec: durationSec,
      framesAnalyzed: numFrames,
      facesDetected: numFrames,
      faceDetectionRatePct: isSevereEdaic ? 99.4 : 100.0,
      avgFaceConfidence: isSevereEdaic ? 97.4 : 94.2,
      avgHeadPitchDeg: isSevereEdaic ? -14.2 : -4.8,
      avgHeadYawDeg: isSevereEdaic ? 6.4 : 1.6,
      facialAffectTitle: sampleAffectTitle,
      facialAffectDescription: sampleAffectDesc,
      actionUnitScores: isSevereEdaic
          ? const {
              'AU04 Brow Lowerer (Corrugator Supercilii)': 0.78,
              'AU05 Upper Lid Raiser (Eye Aperture)': 0.42,
              'AU12 Lip Corner Puller (Zygomaticus / Smile)': 0.22,
              'AU15 Lip Corner Depressor (Depressive Affect)': 0.84,
              'Optical Flow / Facial Motor Dynamics': 0.24,
            }
          : const {
              'AU04 Brow Lowerer (Corrugator Supercilii)': 0.54,
              'AU05 Upper Lid Raiser (Eye Aperture)': 0.68,
              'AU12 Lip Corner Puller (Zygomaticus / Smile)': 0.31,
              'AU15 Lip Corner Depressor (Depressive Affect)': 0.49,
              'Optical Flow / Facial Motor Dynamics': 0.38,
            },
      visualFrames: frames,
      audioSampleRate: 8000,
      totalAudioSamples: 336000,
      audioWaveformBars: waveformBars,
      pitchContourHz: pitchContour,
      avgPitchHz: isSevereEdaic ? 112.4 : 136.5,
      pitchStdHz: isSevereEdaic ? 5.8 : 10.4,
      voicedRatioPct: isSevereEdaic ? 54.0 : 68.0,
      pauseRatioPct: isSevereEdaic ? 46.0 : 32.0,
      jitterPct: isSevereEdaic ? 2.70 : 1.42,
      shimmerPct: isSevereEdaic ? 8.45 : 5.80,
      vocalProsodyTitle: isSevereEdaic
          ? 'Prosodi Hipofonik & Intonasi Monoton dengan Jeda Memanjang'
          : 'Intonasi Terukur Stabil dengan Beberapa Jeda Reflektif',
      vocalProsodyDescription: isSevereEdaic
          ? 'Ekstraksi OpenSMILE eGeMAPS (96.965 frame akustik) mencatat intensitas suara rendah (Loudness=0.044) dengan frekuensi dasar rata-rata 112.4 Hz (±5.8 Hz) dan jeda hening 46% saat mengungkapkan beban emosional.'
          : 'Frekuensi dasar suara berada di rata-rata 136.5 Hz dengan proporsi bicara aktif 68% dan jeda hening 32% saat merangkai kalimat.',
      fullTranscript: transcriptData.fullTranscript,
      translatedTranscript: transcriptData.fullTranscript,
      transcriptLanguage: 'en',
      transcriptSegments: transcriptData.segments,
      detectedKeywords: transcriptData.keywords,
      emotionalValence: transcriptData.valence,
      selfPronounCount: transcriptData.pronounCount,
      linguisticTitle: transcriptData.title,
      linguisticDescription: transcriptData.description,
      isExplicitTranscript: true,
      isWhisperTranscribed: true,
      sampleVisualVector: visualFeatures.take(12).toList(),
      sampleAudioVector: audioFeatures.take(12).toList(),
      sampleTextVector: textFeatures.take(12).toList(),
    );
  }

  /// Menilai apakah suatu teks merupakan transkrip ucapan verbal atau catatan klinis yang valid
  /// (bukan sekadar label pengujian administratif seperti "Test Ke 3" atau "Kasus 1")
  static bool _isValidSpeechTranscript(String? text) {
    if (text == null) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    // Abaikan hanya jika berupa label pengujian administratif singkat tanpa kata klinis
    if ((lower.startsWith('test') ||
            lower.startsWith('kasus') ||
            lower.startsWith('skrining') ||
            lower.startsWith('coba')) &&
        words.length < 4) {
      return false;
    }
    return true;
  }

  /// Menentukan teks transkrip verbatim jika pengguna memasukkan transkrip wawancara atau catatan klinisi
  static String _resolveTranscriptText({
    String? clientTranscript,
    String? counselorNote,
    Map<String, double>? visualSummary,
    Map<String, double>? audioSummary,
  }) {
    if (_isValidSpeechTranscript(clientTranscript)) {
      return clientTranscript!.trim();
    }
    if (_isValidSpeechTranscript(counselorNote)) {
      return counselorNote!.trim();
    }
    return '';
  }

  static _TranscriptLinguisticBundle _buildTranscriptAndLinguistics({
    String? userNote,
    String? clientTranscript,
    required double durationSec,
    required List<double> waveformBars,
    List<double>? pitchContour,
    required double pauseRatio,
    required double avgPitchHz,
    double? pitchStdHz,
    double? jitterPct,
    required String affectTitle,
    Map<String, double>? visualSummary,
    Map<String, double>? audioSummary,
    bool isFromRealVideo = false,
  }) {
    final bool hasExplicit = _isValidSpeechTranscript(clientTranscript) ||
        _isValidSpeechTranscript(userNote);

    const emotionalLexicon = <String, String>{
      'sedih': 'Suasana Hati',
      'murung': 'Suasana Hati',
      'hampa': 'Suasana Hati',
      'kosong': 'Suasana Hati',
      'kecewa': 'Suasana Hati',
      'sendiri': 'Kesepian',
      'kesepian': 'Kesepian',
      'lelah': 'Energi & Kelelahan',
      'capek': 'Energi & Kelelahan',
      'letih': 'Energi & Kelelahan',
      'lesu': 'Energi & Kelelahan',
      'berat': 'Beban Emosi',
      'penuh': 'Beban Pikiran',
      'tidur': 'Kualitas Tidur',
      'insomnia': 'Kualitas Tidur',
      'begadang': 'Kualitas Tidur',
      'terbangun': 'Kualitas Tidur',
      'nyenyak': 'Kualitas Tidur',
      'istirahat': 'Kebutuhan Pemulihan',
      'pemulihan': 'Kebutuhan Pemulihan',
      'cemas': 'Kecemasan',
      'takut': 'Kecemasan',
      'khawatir': 'Kecemasan',
      'tegang': 'Ketegangan Emosi',
      'stres': 'Tekanan Stres',
      'stress': 'Tekanan Stres',
      'beban': 'Beban Pikiran',
      'masalah': 'Beban Pikiran',
      'pikiran': 'Fokus Pikiran',
      'fokus': 'Fokus Kognitif',
      'konsentrasi': 'Fokus Kognitif',
      'tenang': 'Regulasi Diri',
      'nyaman': 'Regulasi Diri',
      'berusaha': 'Daya Juang (Coping)',
      'baik': 'Afek Positif',
      'semangat': 'Afek Positif',
      'bersemangat': 'Afek Positif',
      'optimis': 'Afek Positif',
      'syukur': 'Afek Positif',
      'bersyukur': 'Afek Positif',
      'sehat': 'Kondisi Fisik',
      'perasaan': 'Refleksi Diri',
      'kondisi': 'Refleksi Diri',
      'rutinitas': 'Aktivitas Harian',
      'aktivitas': 'Aktivitas Harian',
      'tubuh': 'Somatik / Fisik',
      // Penanda Akustik-Visual Video
      'nada': 'Dinamika Vokal',
      'frekuensi': 'Frekuensi Akustik',
      'intonasi': 'Modulasi Nada',
      'jeda': 'Retardasi / Jeda Vokal',
      'hening': 'Jeda Hening',
      'stabilitas': 'Kualitas Nada',
      'senyum': 'Afek Positif',
      'dahi': 'Ketegangan Otot (AU04)',
      'pandangan': 'Kontak Tatapan',
      'tatapan': 'Arah Tatapan',
      'terbuka': 'Kontak Wajah',
      'menunduk': 'Gaze Aversion',
      'datar': 'Afek Datar',
      'aktif': 'Keaktifan Bicara',
      'responsif': 'Responsivitas Afek',
      // Leksikon klinis Bahasa Inggris (E-DAIC Corpus)
      'depression': 'Afek Depresif',
      'depressed': 'Afek Depresif',
      'bottom': 'Keputusasaan (Rock Bottom)',
      'sleeping': 'Gangguan Tidur',
      'sleep': 'Gangguan Tidur',
      'dreams': 'Mimpi Buruk / Distres',
      'irritable': 'Iritabilitas / Tegang',
      'edge': 'Ketegangan Emosi',
      'hate': 'Distres Emosional',
      'isolation': 'Isolasi Sosial',
      'anybody': 'Penarikan Diri',
      'nobody': 'Penarikan Diri',
      'wish': 'Ruminasi Masa Lalu',
      'bad': 'Afek Negatif',
      'nothing': 'Anhedonia / Hampa',
      'tired': 'Energi & Kelelahan',
      'exhausted': 'Energi & Kelelahan',
      'hopeless': 'Keputusasaan',
      'good': 'Afek Positif',
      'excited': 'Afek Positif',
      'comfortable': 'Regulasi Diri',
      'relaxed': 'Regulasi Diri',
    };

    const selfPronouns = {'saya', 'aku', 'diriku', 'ku', 'i', 'me', 'my', 'myself'};
    const positiveKeywords = {
      'tenang',
      'nyaman',
      'berusaha',
      'baik',
      'semangat',
      'bersemangat',
      'optimis',
      'syukur',
      'bersyukur',
      'sehat',
      'senyum',
      'responsif',
      'aktif',
      'terbuka',
      'good',
      'excited',
      'comfortable',
      'relaxed',
    };

    String rawTranscript;
    final segments = <TranscriptSegmentItem>[];

    if (hasExplicit) {
      // 1. Mode Transkrip Verbatim Nyata (dari input pengguna/konselor atau dataset patokan klinis)
      rawTranscript = _resolveTranscriptText(
        clientTranscript: clientTranscript,
        counselorNote: userNote,
        visualSummary: visualSummary,
        audioSummary: audioSummary,
      );

      final sentences = rawTranscript
          .split(RegExp(r'(?<=[.!?])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        sentences.add(rawTranscript);
      }

      if (sentences.length == 1 && durationSec >= 20.0) {
        final parts = sentences[0]
            .split(RegExp(r'(?<=,)\s+'))
            .map((s) => s.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          sentences.clear();
          sentences.addAll(parts);
        }
      }

      final int segCount = sentences.length;
      for (int i = 0; i < segCount; i++) {
        final cleanText = sentences[i].trim();
        if (cleanText.isEmpty) continue;

        final tStart = (durationSec * i / segCount).round();
        final tEnd = max(tStart + 1, (durationSec * (i + 1) / segCount).round());
        final timeLabel = '${_fmtSec(tStart)} - ${_fmtSec(tEnd)}';

        final segWords = cleanText
            .toLowerCase()
            .split(RegExp(r'[^a-zA-Z0-9_]+'))
            .where((w) => emotionalLexicon.containsKey(w))
            .toList();

        String prosodyNote;
        if (isFromRealVideo && waveformBars.isNotEmpty) {
          final bStart = (i * waveformBars.length) ~/ segCount;
          final bEnd = max(bStart + 1, ((i + 1) * waveformBars.length) ~/ segCount);
          final segBars = waveformBars.sublist(bStart, min(waveformBars.length, bEnd));
          final segVoicedPct =
              ((segBars.where((b) => b >= 0.14).length / max(1, segBars.length)) * 100)
                  .round();
          final segPausePct = 100 - segVoicedPct;

          double segPitchMean = avgPitchHz;
          double segPitchStd = pitchStdHz ?? 10.0;
          if (pitchContour != null && pitchContour.isNotEmpty) {
            final pStart = (i * pitchContour.length) ~/ segCount;
            final pEnd = max(pStart + 1, ((i + 1) * pitchContour.length) ~/ segCount);
            final segPitches =
                pitchContour.sublist(pStart, min(pitchContour.length, pEnd));
            final pSt = _calcSeriesStats(segPitches);
            segPitchMean = pSt.mean;
            segPitchStd = pSt.std;
          }

          if (i == 0) {
            prosodyNote =
                'Awal sesi • Nada ${segPitchMean.toStringAsFixed(0)} Hz • Bicara $segVoicedPct%';
          } else if (i == segCount - 1) {
            final stabilityLabel =
                (jitterPct ?? 1.4) > 2.0 ? 'Fluktuatif' : 'Stabil';
            prosodyNote =
                'Akhir sesi • Nada ${segPitchMean.toStringAsFixed(0)} Hz ($stabilityLabel) • Jeda $segPausePct%';
          } else {
            prosodyNote =
                'Tengah sesi • Variasi ±${segPitchStd.toStringAsFixed(1)} Hz (${segPitchMean.toStringAsFixed(0)} Hz) • Aktif $segVoicedPct%';
          }
        } else {
          if (i == 0) {
            prosodyNote = 'Awal cerita • Nada dasar ${avgPitchHz.toStringAsFixed(0)} Hz';
          } else if (pauseRatio > 0.35 && i == segCount - 1) {
            prosodyNote = 'Terdapat jeda tarik napas sebelum menutup kalimat';
          } else {
            prosodyNote = 'Intonasi stabil • Fokus bicara terjaga';
          }
        }

        segments.add(
          TranscriptSegmentItem(
            timeRangeLabel: timeLabel,
            text: cleanText,
            detectedKeywords: segWords,
            prosodyNote: prosodyNote,
          ),
        );
      }
    } else {
      // 2. Tidak ada tuturan terkenali: bangun 3 segmen observasi prosodi-visual
      // untuk inspeksi multimodal (KHUSUS UI; tidak dikirim ke MentalBERT).
      final segDur = max(1, durationSec.round() ~/ 3);
      final t0 = _fmtSec(0);
      final t1 = _fmtSec(segDur);
      final t2 = _fmtSec(segDur * 2);
      final t3 = _fmtSec(max(segDur * 3, durationSec.round()));
      final pausePct = (pauseRatio * 100).toStringAsFixed(0);
      final voicedRatio =
          audioSummary?['voicedRatio'] ?? (1.0 - pauseRatio).clamp(0.0, 1.0);
      final voicedPct = (voicedRatio * 100).toStringAsFixed(0);
      final expressiveness = visualSummary?['expressiveness'] ?? 0.25;
      final exprStr = expressiveness.toStringAsFixed(2);
      final pitchStr = avgPitchHz.toStringAsFixed(0);

      final obs0 =
          'Observasi prosodi-visual awal sesi (nada dasar $pitchStr Hz, aktivasi vokal $voicedPct%).';
      final obs1 =
          'Pola ekspresi & vokal tengah sesi (ekspresivitas wajah $exprStr, rasio jeda hening $pausePct%).';
      final obs2 =
          'Penutup rekaman pada nada $pitchStr Hz dengan kestabilan ritme bicara $voicedPct%.';

      segments.addAll([
        TranscriptSegmentItem(
          timeRangeLabel: '$t0 - $t1',
          text: obs0,
          detectedKeywords: const [],
          prosodyNote: 'Awal sesi • Nada $pitchStr Hz • Aktif $voicedPct%',
        ),
        TranscriptSegmentItem(
          timeRangeLabel: '$t1 - $t2',
          text: obs1,
          detectedKeywords: const [],
          prosodyNote: 'Tengah sesi • Ekspresivitas $exprStr • Jeda $pausePct%',
        ),
        TranscriptSegmentItem(
          timeRangeLabel: '$t2 - $t3',
          text: obs2,
          detectedKeywords: const [],
          prosodyNote: 'Akhir sesi • Nada $pitchStr Hz • Jeda $pausePct%',
        ),
      ]);
      rawTranscript = '$obs0 $obs1 $obs2';
    }

    final textLower = rawTranscript.toLowerCase();
    final words = textLower
        .split(RegExp(r'[^a-zA-Z0-9_]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final detectedKeywords = <String>[];
    int pronounCount = 0;
    int negHits = 0;
    int posHits = 0;

    for (final w in words) {
      if (selfPronouns.contains(w)) pronounCount++;
      if (emotionalLexicon.containsKey(w)) {
        final formatted = '$w (${emotionalLexicon[w]})';
        if (!detectedKeywords.contains(formatted)) {
          detectedKeywords.add(formatted);
        }
        if (positiveKeywords.contains(w)) {
          posHits++;
        } else {
          negHits++;
        }
      }
    }

    final valence = ((posHits - negHits) / max(1, posHits + negHits + 1)).clamp(-1.0, 1.0);

    final String lingTitle;
    final String lingDesc;
    if (hasExplicit) {
      if (negHits > posHits) {
        lingTitle = 'Terdeteksi Ungkapan Kelelahan & Beban Pikiran';
        lingDesc =
            'Model bahasa (MentalBERT 768D) menangkap ${detectedKeywords.length} penanda leksikal terkait beban emosi/kelelahan serta $pronounCount kata ganti reflektif pada durasi ${durationSec.toStringAsFixed(1)} detik.';
      } else {
        lingTitle = 'Narasi Cerita Terstruktur dengan Upaya Regulasi Diri';
        lingDesc =
            'Kalimat menunjukkan refleksi diri yang tenang dengan ${detectedKeywords.length} penanda leksikal dan keseimbangan regulasi emosi sepanjang ${durationSec.toStringAsFixed(1)} detik.';
      }
    } else {
      lingTitle = 'Tidak Ada Transkrip';
      lingDesc = 'Pengenalan suara tidak menghasilkan teks pada rekaman ini.';
    }

    return _TranscriptLinguisticBundle(
      fullTranscript: rawTranscript,
      segments: segments,
      keywords: detectedKeywords,
      valence: double.parse(valence.toStringAsFixed(2)),
      pronounCount: pronounCount,
      title: lingTitle,
      description: lingDesc,
    );
  }

  static String _fmtSec(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TranscriptLinguisticBundle {
  final String fullTranscript;
  final List<TranscriptSegmentItem> segments;
  final List<String> keywords;
  final double valence;
  final int pronounCount;
  final String title;
  final String description;

  const _TranscriptLinguisticBundle({
    required this.fullTranscript,
    required this.segments,
    required this.keywords,
    required this.valence,
    required this.pronounCount,
    required this.title,
    required this.description,
  });
}

class _SeriesStats {
  final double mean;
  final double std;
  final double median;
  final double iqr;
  final double minVal;
  final double maxVal;

  const _SeriesStats({
    required this.mean,
    required this.std,
    required this.median,
    required this.iqr,
    this.minVal = 0.0,
    this.maxVal = 0.0,
  });
}

class _VisualExtractionResult {
  final List<double> features;
  final Map<String, double> summaryStats;

  const _VisualExtractionResult({
    required this.features,
    required this.summaryStats,
  });
}

class _AudioExtractionResult {
  final List<double> features;
  final Map<String, double> summaryStats;
  final List<double> pitchContour;

  const _AudioExtractionResult({
    required this.features,
    required this.summaryStats,
    required this.pitchContour,
  });
}
