import 'package:flutter/foundation.dart';
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

  ScreeningResponse? _currentScreening;
  ScreeningResponse? get currentScreening => _currentScreening;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // --- History State ---
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  List<ScreeningSummaryItem> _historyItems = [];
  List<ScreeningSummaryItem> get historyItems => _historyItems;

  int _totalHistory = 0;
  int get totalHistory => _totalHistory;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetCurrentScreening() {
    _currentScreening = null;
    notifyListeners();
  }

  /// Cek kesiapan server backend FastAPI
  Future<void> checkServerHealth() async {
    _isCheckingHealth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final healthData = await repository.checkHealth();
      _isServerHealthy = healthData['status'] == 'ok';
      _isModelLoaded = healthData['model_loaded'] == true;
      _serverDevice = healthData['device']?.toString() ?? 'cpu';

      // Ambil metadata arsitektur model
      try {
        _modelInfo = await repository.getModelInfo();
      } catch (_) {
        // Model info opsional jika endpoint model sedang loading
      }
    } catch (e) {
      _isServerHealthy = false;
      _isModelLoaded = false;
      _errorMessage = e.toString();
    } finally {
      _isCheckingHealth = false;
      notifyListeners();
    }
  }

  /// Menjalankan siklus skrining lengkap:
  /// 1. POST /screenings (Pendaftaran sesi)
  /// 2. POST /screenings/{id}/predict (Inferensi & Exact Shapley XAI)
  Future<bool> startAndExecuteScreening({
    required String participantId,
    required dynamic textFeatures,
    required dynamic audioFeatures,
    required dynamic visualFeatures,
    Map<String, dynamic>? metadata,
  }) async {
    _isExecuting = true;
    _errorMessage = null;
    _currentScreening = null;
    _executionStatusMessage = 'Mendaftarkan sesi skrining baru...';
    notifyListeners();

    try {
      // 1. Inisialisasi sesi di backend
      final session = await repository.createScreeningSession(
        participantId: participantId,
        metadata: metadata,
      );

      _executionStatusMessage =
          'Menghitung inferensi multimodal & Exact Shapley (8 koalisi)...';
      notifyListeners();

      // 2. Eksekusi inferensi dan Exact XAI
      final result = await repository.executeScreening(
        screeningId: session.screeningId,
        textFeatures: textFeatures,
        audioFeatures: audioFeatures,
        visualFeatures: visualFeatures,
        metadata: metadata,
      );

      _currentScreening = result;
      _executionStatusMessage = 'Selesai!';

      // Refresh riwayat skrining
      fetchHistory();
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

  /// Memuat riwayat skrining dari server
  Future<void> fetchHistory({int skip = 0, int limit = 30}) async {
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await repository.getScreeningHistory(
        skip: skip,
        limit: limit,
      );
      _historyItems = response.screenings;
      _totalHistory = response.total;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Memuat detail skrining berdasarkan ID
  Future<void> loadScreeningDetail(String screeningId) async {
    _isExecuting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final detail = await repository.getScreeningDetail(screeningId);
      _currentScreening = detail;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isExecuting = false;
      notifyListeners();
    }
  }
}
