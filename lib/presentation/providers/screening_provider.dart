import 'package:flutter/foundation.dart';
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

  bool _isServerHealthy = false;
  bool get isServerHealthy => _isServerHealthy;

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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetCurrentScreening() {
    _currentScreening = null;
    notifyListeners();
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
      _modelInfo = {
        'model': 'FED-MIND Baseline (On-Device)',
        'architecture': 'Multimodal BiLSTM Attention Fusion',
        'parameters': '7,832,001 (Float32 ONNX)',
        'engine': 'ONNX Runtime Mobile v1.9.0',
        'privacy': '100% On-Device (Zero-Leakage)',
      };
    } catch (e) {
      _isServerHealthy = false;
      _errorMessage = 'Failed to initialize local model: $e';
    } finally {
      _isCheckingHealth = false;
      notifyListeners();
    }
  }

  /// Menjalankan inferensi dan ekstraksi riil via Local Edge Server (Port 8001)
  /// Video diproses on-premise di klinik dengan OpenFace 2.2.0, openSMILE, Whisper & MentalBERT
  Future<bool> processVideoAtEdge({
    required String videoPath,
    required String participantId,
    String? sessionId,
  }) async {
    _isExecuting = true;
    _errorMessage = null;
    _currentScreening = null;
    _executionStatusMessage = 'Connecting to Edge Node...';
    notifyListeners();

    try {
      final result = await repository.processVideoViaEdge(
        videoPath: videoPath,
        participantId: participantId,
        sessionId: sessionId,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final pct = (sent / total * 100).toInt();
            if (pct < 100) {
              _executionStatusMessage = 'Processing video on Edge: $pct%...';
            } else {
              _executionStatusMessage =
                  'Extracting multimodal features on Edge...';
            }
            notifyListeners();
          }
        },
      );

      _currentScreening = result;
      _executionStatusMessage = 'Completed!';

      // Simpan ke SQLite
      try {
        await repository.saveLocalScreeningRecord(
          screening: result,
          videoPath: videoPath,
        );
      } catch (e) {
        debugPrint('[SCREENING_PROVIDER] Warning: Failed to persist edge screening to SQLite: $e');
      }

      // Refresh riwayat skrining
      await fetchHistory();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isExecuting = false;
      _executionStatusMessage = '';
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
    String? transcription,
    MultimodalInspectionData? inspectionData,
  }) async {
    _isExecuting = true;
    _errorMessage = null;
    _currentScreening = null;
    _executionProgress = null;
    _executionStatusMessage =
        'Menjalankan model AI & perhitungan kontribusi (Exact Shapley) di perangkat...';
    notifyListeners();

    try {
      final result = await repository.executeLocalScreening(
        participantId: participantId,
        textFeatures: textFeatures,
        audioFeatures: audioFeatures,
        visualFeatures: visualFeatures,
        sessionId: sessionId,
        counselorNote: counselorNote,
        transcription: transcription,
      );

      final baseInspection = inspectionData ??
          _currentInspectionData ??
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
            participantId: participantId,
            visualFeatures: visualFeatures,
            audioFeatures: audioFeatures,
            textFeatures: textFeatures,
            userNote: counselorNote,
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

      // Simpan ke SQLite secara persisten
      try {
        await repository.saveLocalScreeningRecord(
          screening: result,
          inspectionData: enrichedInspection,
          videoPath: inspectionData?.videoPath,
        );
      } catch (e) {
        debugPrint('[SCREENING_PROVIDER] Warning: Failed to persist screening to SQLite: $e');
      }

      // Catat di riwayat memori agar langsung muncul di tab Riwayat
      _historyItems.removeWhere((item) => item.screeningId == result.screeningId);
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
        ),
      );
      _totalHistory = _historyItems.length;

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

  /// Memuat riwayat skrining dari SQLite Local Storage
  Future<void> fetchHistory({int skip = 0, int limit = 30}) async {
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
      if (_localScreeningCache.containsKey(screeningId)) {
        _currentScreening = _localScreeningCache[screeningId];
        if (_localInspectionCache.containsKey(screeningId)) {
          _currentInspectionData = _localInspectionCache[screeningId];
        }
      } else {
        // Ambil dari SQLite
        final savedScreening =
            await repository.getLocalScreeningDetail(screeningId);
        if (savedScreening != null) {
          _currentScreening = savedScreening;
          _localScreeningCache[screeningId] = savedScreening;

          final savedInspection =
              await repository.getLocalInspectionData(screeningId);
          if (savedInspection != null) {
            _currentInspectionData = savedInspection;
            _localInspectionCache[screeningId] = savedInspection;
          }
        } else if (_currentScreening?.screeningId == screeningId) {
          // Sudah ada di memory
        } else {
          throw 'Screening detail not found in local storage.';
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
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
}
