import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../core/services/local_preprocessing_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/multimodal_extractor_service.dart';
import '../../data/models/multimodal_inspection_models.dart';
import '../../data/models/screening_models.dart';
import '../../data/repositories/screening_repository.dart';

class ScreeningProvider extends ChangeNotifier {
  final ScreeningRepository repository;

  ScreeningProvider({required this.repository});

  // --- Health & Diagnostic State ---
  bool _isCheckingHealth = false;
  bool get isCheckingHealth => _isCheckingHealth;

  bool _isSwitchingModel = false;
  bool get isSwitchingModel => _isSwitchingModel;

  FedMindModelVariant get selectedModelVariant =>
      repository.localInferenceService.selectedVariant;

  bool _isServerHealthy = false;
  bool get isServerHealthy => _isServerHealthy;
  bool get isServerOnline => _isServerHealthy;

  bool _isEdgeHealthy = false;
  bool get isEdgeHealthy => _isEdgeHealthy;

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  String _serverDevice = 'unknown';
  String get serverDevice => _serverDevice;

  Map<String, dynamic>? _modelInfo;
  Map<String, dynamic>? get modelInfo => _modelInfo;

  // --- Screening State ---
  bool _isExecuting = false;
  bool get isExecuting => _isExecuting;

  String _executionStatusMessage = '';
  String get executionStatusMessage => _executionStatusMessage;

  double? _executionProgress;
  double? get executionProgress => _executionProgress;

  void setExtractionProgress(String stage, double progress) {
    _isExecuting = true;
    _executionStatusMessage = stage;
    _executionProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  ScreeningResponse? _currentScreening;
  ScreeningResponse? get currentScreening => _currentScreening;

  MultimodalInspectionData? _currentInspectionData;
  MultimodalInspectionData? get currentInspectionData => _currentInspectionData;

  void setInspectionData(MultimodalInspectionData? data) {
    _currentInspectionData = data;
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- History State ---
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  final List<ScreeningSummaryItem> _historyItems = [];
  List<ScreeningSummaryItem> get historyItems => _historyItems;

  int _totalHistory = 0;
  int get totalHistory => _totalHistory;

  // Cache hasil skrining lokal di memori
  final Map<String, ScreeningResponse> _localScreeningCache = {};
  final Map<String, MultimodalInspectionData> _localInspectionCache = {};

  MultimodalInspectionData? getInspectionForScreening(String screeningId) {
    return _localInspectionCache[screeningId] ?? _currentInspectionData;
  }

  // --- Clinical Dashboard Computed Metrics ---
  int get urgentTriageCount => _historyItems.where((item) {
    final r = item.riskCategory?.toLowerCase();
    return r == 'moderate' || r == 'high';
  }).length;

  int get pendingVerificationCount =>
      _historyItems.where((item) => !item.isVerified).length;

  int get verifiedCasesCount =>
      _historyItems.where((item) => item.isVerified).length;

  double? get modelConcordanceRatePct {
    final verified = _historyItems.where((item) => item.isVerified).toList();
    if (verified.isEmpty) return null;
    final concordant = verified.where((item) {
      final s = item.concordanceStatus?.toLowerCase();
      return s == 'valid' || s == 'concordant';
    }).length;
    return (concordant / verified.length) * 100.0;
  }

  /// Mengambil daftar lengkap ScreeningResponse terverifikasi (atau seluruh riwayat) dari SQLite untuk ekspor validasi.
  Future<List<ScreeningResponse>> loadVerifiedScreeningsForExport({
    bool includeUnverified = false,
  }) async {
    final results = <ScreeningResponse>[];
    for (final item in _historyItems) {
      if (!includeUnverified && !item.isVerified) continue;
      final detail = _localScreeningCache[item.screeningId] ??
          await repository.getLocalScreeningDetail(item.screeningId);
      if (detail != null) {
        results.add(detail);
      }
    }
    return results;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetCurrentScreening() {
    _currentScreening = null;
    notifyListeners();
  }

  bool get isMentalBertLoaded => repository.localInferenceService.isMentalBertLoaded;
  String? get mentalBertError => repository.localInferenceService.mentalBertError;

  Map<String, dynamic> _buildModelInfoMap() {
    final inference = repository.localInferenceService;
    final variant = inference.selectedVariant;
    final mentalBertReady = inference.isMentalBertLoaded;
    final mentalBertErr = inference.mentalBertError;
    final v000 = inference.v000Baseline;
    return {
      'variant': variant.shortLabel,
      'model': variant.displayName,
      'checkpoint': variant.checkpointFileName,
      'architecture': variant.architectureName,
      'text_encoder': mentalBertReady
          ? 'Multilingual-E5-Small INT4 ONNX (768D)'
          : 'Fallback Leksikal (${mentalBertErr ?? 'Belum dimuat'})',
      'parameters': variant.parameterSummary,
      'latent_dim': '${variant.latentDim}D × 3 (${variant.fusedLatentDim}D Fused)',
      'threshold': 'PHQ-8 ≥ ${inference.binaryThreshold.toStringAsFixed(1)}',
      'engine': 'ONNX Runtime Mobile v1.9.0',
      'xai_baseline':
          'E[f(X)] = ${v000.toStringAsFixed(2)} (${variant.xaiBaselineFileName})',
      'privacy': '100% On-Device (Zero-Leakage)',
    };
  }

  /// Menginisialisasi / memuat ulang varian model inferensi on-device (Model 3 Edge)
  Future<void> selectModelVariant(FedMindModelVariant variant) async {
    if (_isSwitchingModel ||
        (repository.localInferenceService.selectedVariant == variant &&
            _isModelLoaded)) {
      return;
    }

    _isSwitchingModel = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.localInferenceService.setModelVariant(variant);
      _isServerHealthy = true;
      _isModelLoaded = true;
      _isEdgeHealthy = true;
      _serverDevice = 'Mobile NPU/CPU';
      _modelInfo = _buildModelInfoMap();
    } catch (e) {
      _errorMessage = 'Gagal mengganti model inferensi: $e';
    } finally {
      _isSwitchingModel = false;
      notifyListeners();
    }
  }

  /// Cek kesiapan engine inferensi on-device (ONNX Edge Mobile)
  Future<void> checkServerHealth() async {
    _isCheckingHealth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.localInferenceService.initialize();
      _isServerHealthy = true;
      _isModelLoaded = true;
      _isEdgeHealthy = true;
      _serverDevice = 'Mobile NPU/CPU';
      _modelInfo = _buildModelInfoMap();
    } catch (e) {
      _isServerHealthy = false;
      _errorMessage = 'Failed to initialize local model: $e';
    } finally {
      _isCheckingHealth = false;
      notifyListeners();
    }
  }

  /// Menjalankan inferensi model ONNX langsung di edge mobile (On-Device Offline)
  Future<bool> executeLocalOnDeviceScreening({
    required String participantId,
    required List<double> textFeatures,
    required List<double> audioFeatures,
    required List<double> visualFeatures,
    String? sessionId,
    String? counselorNote,
    String? sessionType,
    String? transcription,
    MultimodalInspectionData? inspectionData,
    bool isSimulation = false,
  }) async {
    _isExecuting = true;
    _errorMessage = null;
    _currentScreening = null;
    _executionProgress = 0.94;
    _executionStatusMessage =
        'Menjalankan inferensi ONNX & dekomposisi Exact Shapley (8 koalisi laten) di perangkat...';
    notifyListeners();

    try {
      final rawResult = await repository.executeLocalScreening(
        participantId: participantId,
        textFeatures: textFeatures,
        audioFeatures: audioFeatures,
        visualFeatures: visualFeatures,
        sessionId: sessionId,
        counselorNote: counselorNote,
        transcription: transcription,
        disableVisualBranch: inspectionData?.isVisualBranchDisabled == true,
      );

      final effectiveSessionType =
          isSimulation ? 'simulation' : (sessionType ?? 'clinical');

      final result = ScreeningResponse(
        screeningId: rawResult.screeningId,
        participantId: rawResult.participantId,
        status: rawResult.status,
        prediction: rawResult.prediction,
        patientModalityAttribution: rawResult.patientModalityAttribution,
        globalReference: rawResult.globalReference,
        qualityFlags: rawResult.qualityFlags,
        clinicalNarrative: rawResult.clinicalNarrative,
        model: rawResult.model,
        xai: rawResult.xai,
        disclaimer: rawResult.disclaimer,
        createdAt: rawResult.createdAt,
        completedAt: rawResult.completedAt,
        clinicalVerification: rawResult.clinicalVerification,
        sessionType: effectiveSessionType,
        initialCounselorNote: counselorNote,
      );

      final baseInspection = inspectionData ??
          _currentInspectionData ??
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
            participantId: participantId,
            visualFeatures: visualFeatures,
            audioFeatures: audioFeatures,
            textFeatures: textFeatures,
            userNote: counselorNote,
            clientTranscript: transcription,
          );

      final enrichedInspection = baseInspection.copyWithCalculation(
        audioLatentNorm: repository.localInferenceService.lastAudioLatentNorm,
        visualLatentNorm: repository.localInferenceService.lastVisualLatentNorm,
        textLatentNorm: repository.localInferenceService.lastTextLatentNorm,
        coalitionScores: repository.localInferenceService.lastCoalitionScores,
      );

      _currentScreening = result;
      _currentInspectionData = enrichedInspection;
      _localScreeningCache[result.screeningId] = result;
      _localInspectionCache[result.screeningId] = enrichedInspection;
      _executionStatusMessage = 'Selesai!';

      // JIKA INI SIMULASI: Jangan simpan ke database SQLite dan jangan masukkan ke antrean riwayat verifikasi
      if (!isSimulation) {
        // Simpan ke SQLite secara persisten
        try {
          await repository.saveLocalScreeningRecord(
            screening: result,
            inspectionData: enrichedInspection,
            videoPath: inspectionData?.videoPath,
          );
        } catch (e) {
          debugPrint(
            '[SCREENING_PROVIDER] Warning: Failed to persist screening to SQLite: $e',
          );
        }

        // Catat di riwayat memori agar langsung muncul di daftar pemeriksaan
        _historyItems
            .removeWhere((item) => item.screeningId == result.screeningId);
        _historyItems.insert(
          0,
          ScreeningSummaryItem(
            screeningId: result.screeningId,
            participantId: result.participantId,
            status: result.status,
            phq8Score: result.prediction?.phq8Score ?? 0.0,
            riskCategory: result.prediction?.riskCategory ?? 'unknown',
            binaryPrediction: result.prediction?.binaryPrediction ?? 'unknown',
            createdAt: result.createdAt ?? DateTime.now().toIso8601String(),
            dominantModality:
                result.patientModalityAttribution?.dominantModality ?? 'visual',
            isVerified: result.clinicalVerification?.isVerified ?? false,
            concordanceStatus: result.clinicalVerification?.concordanceStatus,
            groundTruthPhq8: result.clinicalVerification?.groundTruthPhq8,
          ),
        );
        _totalHistory = _historyItems.length;
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isExecuting = false;
      _executionProgress = null;
      _executionStatusMessage = '';
      notifyListeners();
    }
  }

  /// Menyimpan verifikasi klinis konselor (Model Auditing & Catatan SOAP) ke SQLite dan memori
  Future<bool> saveClinicalVerification({
    required ScreeningResponse screening,
    required ClinicalVerificationData verification,
    MultimodalInspectionData? inspectionData,
    String? videoPath,
  }) async {
    try {
      final updatedScreening = screening.copyWithVerification(verification);
      _currentScreening = updatedScreening;
      _localScreeningCache[updatedScreening.screeningId] = updatedScreening;

      await repository.saveLocalScreeningRecord(
        screening: updatedScreening,
        inspectionData:
            inspectionData ?? _localInspectionCache[updatedScreening.screeningId],
        videoPath: videoPath,
      );

      final idx = _historyItems.indexWhere(
        (item) => item.screeningId == updatedScreening.screeningId,
      );
      if (idx != -1) {
        _historyItems[idx] = _historyItems[idx].copyWithVerification(
          isVerified: verification.isVerified,
          concordanceStatus: verification.concordanceStatus,
          groundTruthPhq8: verification.groundTruthPhq8,
        );
      } else {
        _historyItems.insert(
          0,
          ScreeningSummaryItem(
            screeningId: updatedScreening.screeningId,
            participantId: updatedScreening.participantId,
            status: updatedScreening.status,
            phq8Score: updatedScreening.prediction?.phq8Score ?? 0.0,
            riskCategory:
                updatedScreening.prediction?.riskCategory ?? 'unknown',
            binaryPrediction:
                updatedScreening.prediction?.binaryPrediction ?? 'unknown',
            dominantModality: updatedScreening
                    .patientModalityAttribution?.dominantModality ??
                'visual',
            createdAt:
                updatedScreening.createdAt ?? DateTime.now().toIso8601String(),
            completedAt: updatedScreening.completedAt,
            isVerified: verification.isVerified,
            concordanceStatus: verification.concordanceStatus,
            groundTruthPhq8: verification.groundTruthPhq8,
          ),
        );
        _totalHistory = _historyItems.length;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan verifikasi klinis: $e';
      notifyListeners();
      return false;
    }
  }

  /// Memuat riwayat skrining dari SQLite Local Storage
  Future<void> fetchHistory({int skip = 0, int limit = 50}) async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final items = await repository.getLocalScreeningHistory(
        skip: skip,
        limit: limit,
      );
      _historyItems
        ..clear()
        ..addAll(items);
      _totalHistory = await repository.getLocalScreeningTotalCount();
    } catch (e) {
      debugPrint('[SCREENING_PROVIDER] Error fetching local history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Memuat detail skrining berdasarkan ID (Memory cache atau SQLite Database)
  Future<void> loadScreeningDetail(String screeningId) async {
    _isExecuting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Ambil dari SQLite terlebih dahulu agar selalu sinkron dengan perubahan verifikasi terbaru
      final savedScreening =
          await repository.getLocalScreeningDetail(screeningId);
      if (savedScreening != null) {
        _currentScreening = savedScreening;
        _localScreeningCache[screeningId] = savedScreening;

        final savedInspection =
            await repository.getLocalInspectionData(screeningId);
        final savedVideoPath =
            await repository.getLocalVideoPath(screeningId);
        if (savedInspection != null) {
          final hasInspectionVideo =
              savedInspection.videoPath != null &&
              savedInspection.videoPath!.trim().isNotEmpty;
          final enriched = (!hasInspectionVideo &&
                  savedVideoPath != null &&
                  savedVideoPath.trim().isNotEmpty)
              ? savedInspection.copyWith(videoPath: savedVideoPath.trim())
              : savedInspection;
          _currentInspectionData = enriched;
          _localInspectionCache[screeningId] = enriched;
        } else {
          _currentInspectionData = _localInspectionCache[screeningId];
        }
      } else if (_localScreeningCache.containsKey(screeningId)) {
        _currentScreening = _localScreeningCache[screeningId];
        if (_localInspectionCache.containsKey(screeningId)) {
          _currentInspectionData = _localInspectionCache[screeningId];
        }
      } else if (_currentScreening?.screeningId == screeningId) {
        // Sudah ada di memory
      } else {
        throw 'Screening detail not found in local storage.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }

  /// Mengambil path video lokal tersimpan di SQLite (untuk History & Detail).
  Future<String?> resolveLocalVideoPath(String screeningId) async {
    final cached = _localInspectionCache[screeningId]?.videoPath;
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }
    try {
      final dbPath = await repository.getLocalVideoPath(screeningId);
      if (dbPath != null && dbPath.trim().isNotEmpty) {
        return dbPath.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Menghapus riwayat skrining dari SQLite dan memori
  Future<bool> deleteScreeningRecord(String screeningId) async {
    try {
      final success = await repository.deleteLocalScreening(screeningId);
      if (success) {
        _historyItems.removeWhere((item) => item.screeningId == screeningId);
        _localScreeningCache.remove(screeningId);
        _localInspectionCache.remove(screeningId);
        if (_currentScreening?.screeningId == screeningId) {
          _currentScreening = null;
          _currentInspectionData = null;
        }
        _totalHistory = _historyItems.length;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Gagal menghapus riwayat: $e';
      notifyListeners();
      return false;
    }
  }

  /// Menghapus berkas video & WAV mentah di perangkat sambil mempertahankan skor & ringkasan klinis di SQLite.
  Future<bool> removeRawVideoForScreening(
    String screeningId,
    String? videoPath,
  ) async {
    try {
      if (videoPath != null && videoPath.isNotEmpty) {
        await LocalStorageService.deleteLocalVideo(videoPath);
      }
      await repository.clearLocalVideoPath(screeningId);

      if (_currentInspectionData != null &&
          _localInspectionCache[screeningId]?.videoPath == videoPath) {
        _currentInspectionData = _currentInspectionData!.copyWith(videoPath: '');
      }
      final cached = _localInspectionCache[screeningId];
      if (cached != null) {
        _localInspectionCache[screeningId] = cached.copyWith(videoPath: '');
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus berkas video mentah: $e';
      notifyListeners();
      return false;
    }
  }

  /// Menjalankan uji kalibrasi Before vs After pada seluruh rekaman lokal di riwayat SQLite
  /// tanpa mengubah data atau skor asli yang tersimpan di database.
  Future<List<CalibrationBenchmarkEntry>> runHistoryCalibrationBenchmark({
    void Function(String message)? onStatus,
  }) async {
    final items = await repository.getLocalScreeningHistory(limit: 100);
    final results = <CalibrationBenchmarkEntry>[];
    debugPrint('[CALIB_BENCHMARK] START total_records=${items.length}');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      onStatus?.call(
        'Mengevaluasi skenario ${i + 1}/${items.length}: ${item.participantId}...',
      );

      final detail = await repository.getLocalScreeningDetail(item.screeningId);
      final insp = await repository.getLocalInspectionData(item.screeningId);
      final savedVideoPath =
          (insp?.videoPath != null && insp!.videoPath!.trim().isNotEmpty)
              ? insp.videoPath!.trim()
              : await repository.getLocalVideoPath(item.screeningId);

      final transcriptText = insp?.fullTranscript.trim() ?? '';
      final clientTranscript =
          transcriptText.isNotEmpty ? transcriptText : null;
      final savedSnap = CalibrationRunSnapshot.fromSaved(
        item: item,
        detail: detail,
        insp: insp,
      );

      if (savedVideoPath == null || !await File(savedVideoPath).exists()) {
        debugPrint(
          '[CALIB_BENCHMARK] #${i + 1} id=${item.screeningId} pid=${item.participantId} SKIP=missing_video',
        );
        results.add(
          CalibrationBenchmarkEntry(
            screeningId: item.screeningId,
            participantId: item.participantId,
            createdAt: item.createdAt,
            durationSec: insp?.videoDurationSec ?? 0.0,
            transcriptChars: transcriptText.length,
            saved: savedSnap,
            errorMessage: 'Berkas video lokal tidak ditemukan.',
          ),
        );
        continue;
      }

      try {
        final wavSidecar =
            savedVideoPath.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.wav');
        final hasSidecarWav = await File(wavSidecar).exists();
        final disableVisual = insp?.isVisualBranchDisabled == true;

        final legFeat = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: savedVideoPath,
          participantId: item.participantId,
          clientTranscript: clientTranscript,
          requireFaceDetection: false,
          audioProfile: AudioCalibrationProfile.legacyBaseline,
        );
        final legResp = await repository.executeLocalScreening(
          participantId: item.participantId,
          textFeatures: legFeat.textFeatures,
          audioFeatures: legFeat.audioFeatures,
          visualFeatures: legFeat.visualFeatures,
          sessionId: '${item.screeningId}_LEG',
          transcription: clientTranscript,
          disableVisualBranch: disableVisual,
        );
        final legSnap = CalibrationRunSnapshot.fromRun(
          response: legResp,
          features: legFeat,
          coalitions: repository.localInferenceService.lastCoalitionScores,
        );

        final calFeat = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: savedVideoPath,
          participantId: item.participantId,
          clientTranscript: clientTranscript,
          requireFaceDetection: false,
          audioProfile: AudioCalibrationProfile.phoneMicCalibrated,
        );
        final calResp = await repository.executeLocalScreening(
          participantId: item.participantId,
          textFeatures: calFeat.textFeatures,
          audioFeatures: calFeat.audioFeatures,
          visualFeatures: calFeat.visualFeatures,
          sessionId: '${item.screeningId}_CAL',
          transcription: clientTranscript,
          disableVisualBranch: disableVisual,
        );
        final calSnap = CalibrationRunSnapshot.fromRun(
          response: calResp,
          features: calFeat,
          coalitions: repository.localInferenceService.lastCoalitionScores,
        );

        debugPrint(
          '[CALIB_BENCHMARK] #${i + 1} id=${item.screeningId} pid=${item.participantId} '
          'created=${item.createdAt} dur=${calFeat.inspectionData.videoDurationSec.toStringAsFixed(1)}s '
          'txtChars=${transcriptText.length} hasWav=$hasSidecarWav '
          'faces=${calFeat.facesDetected}/${calFeat.framesAnalyzed} samples=${calFeat.audioSamplesAnalyzed}',
        );
        debugPrint('[CALIB_BENCHMARK]   SAVED  ${savedSnap.toLogSummary()}');
        debugPrint('[CALIB_BENCHMARK]   LEGACY ${legSnap.toLogSummary()}');
        debugPrint('[CALIB_BENCHMARK]   CALIB  ${calSnap.toLogSummary()}');

        results.add(
          CalibrationBenchmarkEntry(
            screeningId: item.screeningId,
            participantId: item.participantId,
            createdAt: item.createdAt,
            durationSec: calFeat.inspectionData.videoDurationSec,
            transcriptChars: transcriptText.length,
            hasSidecarWav: hasSidecarWav,
            facesDetected: calFeat.facesDetected,
            framesAnalyzed: calFeat.framesAnalyzed,
            saved: savedSnap,
            legacy: legSnap,
            calibrated: calSnap,
          ),
        );
      } catch (e) {
        debugPrint(
          '[CALIB_BENCHMARK] #${i + 1} id=${item.screeningId} ERROR=$e',
        );
        results.add(
          CalibrationBenchmarkEntry(
            screeningId: item.screeningId,
            participantId: item.participantId,
            createdAt: item.createdAt,
            durationSec: insp?.videoDurationSec ?? 0.0,
            transcriptChars: transcriptText.length,
            saved: savedSnap,
            errorMessage: e.toString(),
          ),
        );
      }
    }

    debugPrint('[CALIB_BENCHMARK] DONE evaluated=${results.length}');
    return results;
  }
}

class CalibrationRunSnapshot {
  final double phq8Score;
  final String riskCategory;
  final String dominantModality;
  final double audioPct;
  final double visualPct;
  final double textPct;
  final double rms;
  final double actRms;
  final double p90Rms;
  final double noiseFloor;
  final double pitchMean;
  final double pitchStd;
  final double pauseRatio;
  final double jitterPct;
  final double shimmerPct;
  final double audioSeverity;
  final List<double> coalitionScores;

  const CalibrationRunSnapshot({
    required this.phq8Score,
    required this.riskCategory,
    required this.dominantModality,
    this.audioPct = 0.0,
    this.visualPct = 0.0,
    this.textPct = 0.0,
    this.rms = 0.0,
    this.actRms = 0.0,
    this.p90Rms = 0.0,
    this.noiseFloor = 0.0,
    this.pitchMean = 0.0,
    this.pitchStd = 0.0,
    this.pauseRatio = 0.0,
    this.jitterPct = 0.0,
    this.shimmerPct = 0.0,
    this.audioSeverity = 0.0,
    this.coalitionScores = const [],
  });

  factory CalibrationRunSnapshot.fromSaved({
    required ScreeningSummaryItem item,
    ScreeningResponse? detail,
    MultimodalInspectionData? insp,
  }) {
    final attr = detail?.patientModalityAttribution;
    return CalibrationRunSnapshot(
      phq8Score: detail?.prediction?.phq8Score ?? item.phq8Score ?? 0.0,
      riskCategory: detail?.prediction?.riskCategory ?? item.riskCategory ?? '-',
      dominantModality: attr?.dominantModality ?? item.dominantModality ?? '-',
      audioPct: attr?.audioPct ?? 0.0,
      visualPct: attr?.visualPct ?? 0.0,
      textPct: attr?.textPct ?? 0.0,
      pitchMean: insp?.avgPitchHz ?? 0.0,
      pitchStd: insp?.pitchStdHz ?? 0.0,
      pauseRatio: (insp?.pauseRatioPct ?? 0.0) / 100.0,
      jitterPct: insp?.jitterPct ?? 0.0,
      shimmerPct: insp?.shimmerPct ?? 0.0,
      coalitionScores:
          insp?.coalitionScores.map((c) => c.predictedScore).toList() ??
              const [],
    );
  }

  factory CalibrationRunSnapshot.fromRun({
    required ScreeningResponse response,
    required ExtractedMultimodalFeatures features,
    required List<CoalitionStepScore> coalitions,
  }) {
    final stats = features.audioSummaryStats;
    final ins = features.inspectionData;
    final attr = response.patientModalityAttribution;
    return CalibrationRunSnapshot(
      phq8Score: response.prediction?.phq8Score ?? 0.0,
      riskCategory: response.prediction?.riskCategory ?? '-',
      dominantModality: attr?.dominantModality ?? '-',
      audioPct: attr?.audioPct ?? 0.0,
      visualPct: attr?.visualPct ?? 0.0,
      textPct: attr?.textPct ?? 0.0,
      rms: stats['rms'] ?? 0.0,
      actRms: stats['actRms'] ?? (stats['rms'] ?? 0.0),
      p90Rms: stats['p90Rms'] ?? 0.0,
      noiseFloor: stats['noiseFloor'] ?? 0.0,
      pitchMean: stats['pitchMean'] ?? ins.avgPitchHz,
      pitchStd: stats['pitchStd'] ?? ins.pitchStdHz,
      pauseRatio: stats['pauseRatio'] ?? (ins.pauseRatioPct / 100.0),
      jitterPct: (stats['jitter'] ?? (ins.jitterPct / 100.0)) * 100.0,
      shimmerPct: (stats['shimmer'] ?? (ins.shimmerPct / 100.0)) * 100.0,
      audioSeverity: stats['audioSeverity'] ?? 0.0,
      coalitionScores: coalitions.map((c) => c.predictedScore).toList(),
    );
  }

  String toLogSummary() {
    final sStr = coalitionScores.map((v) => v.toStringAsFixed(2)).join(',');
    return 'phq8=${phq8Score.toStringAsFixed(2)} risk=$riskCategory '
        'dom=$dominantModality(A:${audioPct.toStringAsFixed(1)}%,V:${visualPct.toStringAsFixed(1)}%,T:${textPct.toStringAsFixed(1)}%) '
        'rms=${rms.toStringAsFixed(4)} act=${actRms.toStringAsFixed(4)} '
        'p90=${p90Rms.toStringAsFixed(4)} nf=${noiseFloor.toStringAsFixed(4)} '
        'f0=${pitchMean.toStringAsFixed(1)}±${pitchStd.toStringAsFixed(1)} '
        'pause=${(pauseRatio * 100).toStringAsFixed(1)}% '
        'jit=${jitterPct.toStringAsFixed(2)}% shim=${shimmerPct.toStringAsFixed(2)}% '
        'sev=${audioSeverity.toStringAsFixed(3)} S=[$sStr]';
  }
}

class CalibrationBenchmarkEntry {
  final String screeningId;
  final String participantId;
  final String createdAt;
  final double durationSec;
  final int transcriptChars;
  final bool hasSidecarWav;
  final int facesDetected;
  final int framesAnalyzed;
  final CalibrationRunSnapshot saved;
  final CalibrationRunSnapshot? legacy;
  final CalibrationRunSnapshot? calibrated;
  final String? errorMessage;

  const CalibrationBenchmarkEntry({
    required this.screeningId,
    required this.participantId,
    required this.createdAt,
    required this.durationSec,
    required this.transcriptChars,
    this.hasSidecarWav = false,
    this.facesDetected = 0,
    this.framesAnalyzed = 0,
    required this.saved,
    this.legacy,
    this.calibrated,
    this.errorMessage,
  });
}
