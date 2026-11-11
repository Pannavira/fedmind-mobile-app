import 'package:dio/dio.dart';
import '../../core/services/local_inference_service.dart';
import '../datasources/screening_local_datasource.dart';
import '../datasources/screening_remote_datasource.dart';
import '../models/multimodal_inspection_models.dart';
import '../models/screening_models.dart';

class ScreeningRepository {
  final ScreeningRemoteDataSource remoteDataSource;
  final LocalInferenceService localInferenceService;
  final ScreeningLocalDataSource localDataSource;

  ScreeningRepository({
    required this.remoteDataSource,
    LocalInferenceService? localInferenceService,
    ScreeningLocalDataSource? localDataSource,
  })  : localInferenceService = localInferenceService ?? LocalInferenceService(),
        localDataSource = localDataSource ?? ScreeningLocalDataSource();

  /// Menjalankan inferensi dan Exact Shapley XAI langsung di mobile on-device (Edge Offline)
  Future<ScreeningResponse> executeLocalScreening({
    required String participantId,
    required List<double> textFeatures,
    required List<double> audioFeatures,
    required List<double> visualFeatures,
    String? sessionId,
    String? counselorNote,
    String? transcription,
  }) async {
    try {
      return await localInferenceService.predict(
        audioFeatures: audioFeatures,
        visualFeatures: visualFeatures,
        textFeatures: textFeatures,
        participantId: participantId,
        sessionId: sessionId,
        counselorNote: counselorNote,
        transcription: transcription,
      );
    } catch (e) {
      throw 'Failed to execute local on-device inference: $e';
    }
  }

  /// Cek kesehatan backend dan status model
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      return await remoteDataSource.checkHealth();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Ambil info model
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      return await remoteDataSource.getModelInfo();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  /// Langkah 1: Daftarkan sesi skrining baru
  Future<ScreeningCreateResponse> createScreeningSession({
    required String participantId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await remoteDataSource.createScreeningSession(
        participantId: participantId,
        metadata: metadata,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to create screening session: $e';
    }
  }

  /// Langkah 2: Eksekusi inferensi multimodal & Exact XAI
  Future<ScreeningResponse> executeScreening({
    required String screeningId,
    required dynamic textFeatures,
    required dynamic audioFeatures,
    required dynamic visualFeatures,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await remoteDataSource.executeScreening(
        screeningId: screeningId,
        textFeatures: textFeatures,
        audioFeatures: audioFeatures,
        visualFeatures: visualFeatures,
        metadata: metadata,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to execute multimodal inference: $e';
    }
  }

  /// Ambil detail skrining tersimpan
  Future<ScreeningResponse> getScreeningDetail(String screeningId) async {
    try {
      return await remoteDataSource.getScreeningDetail(screeningId);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to retrieve screening detail: $e';
    }
  }

  /// Ambil riwayat skrining
  Future<ScreeningListResponse> getScreeningHistory({
    int skip = 0,
    int limit = 20,
    String? participantId,
    String? status,
  }) async {
    try {
      return await remoteDataSource.getScreeningHistory(
        skip: skip,
        limit: limit,
        participantId: participantId,
        status: status,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to load screening history: $e';
    }
  }

  // --- SQLite Local Persistence Methods ---

  /// Simpan hasil skrining dan data inspeksi ke SQLite lokal
  Future<void> saveLocalScreeningRecord({
    required ScreeningResponse screening,
    MultimodalInspectionData? inspectionData,
    String? videoPath,
  }) async {
    try {
      await localDataSource.insertOrUpdateScreening(
        screening: screening,
        inspectionData: inspectionData,
        videoPath: videoPath,
      );
    } catch (e) {
      throw 'Failed to save screening to local SQLite: $e';
    }
  }

  /// Simpan verifikasi klinis konselor (Ground Truth PHQ-8, Concordance, Audit XAI, & Catatan SOAP)
  Future<ScreeningResponse?> saveLocalClinicalVerification({
    required String screeningId,
    required ClinicalVerificationData verification,
  }) async {
    try {
      return await localDataSource.saveClinicalVerification(
        screeningId: screeningId,
        verification: verification,
      );
    } catch (e) {
      throw 'Failed to save clinical verification to local SQLite: $e';
    }
  }

  /// Ambil riwayat skrining lokal dari SQLite
  Future<List<ScreeningSummaryItem>> getLocalScreeningHistory({
    int skip = 0,
    int limit = 50,
    String? participantId,
    String? riskCategory,
  }) async {
    try {
      return await localDataSource.getScreeningHistory(
        skip: skip,
        limit: limit,
        participantId: participantId,
        riskCategory: riskCategory,
      );
    } catch (e) {
      throw 'Failed to load local screening history: $e';
    }
  }

  /// Ambil detail skrining dari SQLite
  Future<ScreeningResponse?> getLocalScreeningDetail(String screeningId) async {
    try {
      return await localDataSource.getScreeningDetail(screeningId);
    } catch (e) {
      throw 'Failed to load local screening detail: $e';
    }
  }

  /// Ambil data inspeksi multimodal dari SQLite
  Future<MultimodalInspectionData?> getLocalInspectionData(
    String screeningId,
  ) async {
    try {
      return await localDataSource.getInspectionData(screeningId);
    } catch (e) {
      throw 'Failed to load local inspection data: $e';
    }
  }

  /// Ambil path video lokal dari SQLite
  Future<String?> getLocalVideoPath(String screeningId) async {
    try {
      return await localDataSource.getVideoPath(screeningId);
    } catch (e) {
      throw 'Failed to load local video path: $e';
    }
  }

  /// Ambil total data skrining tersimpan di SQLite
  Future<int> getLocalScreeningTotalCount() async {
    try {
      return await localDataSource.getTotalCount();
    } catch (e) {
      return 0;
    }
  }

  /// Hapus satu data skrining lokal
  Future<bool> deleteLocalScreening(String screeningId) async {
    try {
      return await localDataSource.deleteScreening(screeningId);
    } catch (e) {
      throw 'Failed to delete local screening record: $e';
    }
  }

  /// Hapus seluruh riwayat skrining lokal
  Future<void> clearLocalScreenings() async {
    try {
      await localDataSource.clearAll();
    } catch (e) {
      throw 'Failed to clear local screening history: $e';
    }
  }

  /// Format error Dio menjadi pesan yang dapat dipahami user
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Server connection timed out. Neural extraction may take longer.';
      case DioExceptionType.connectionError:
        return 'Failed to connect to server (${error.requestOptions.baseUrl}).';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        if (responseData is Map && responseData.containsKey('detail')) {
          return 'Server error ($statusCode): ${responseData['detail']}';
        }
        return 'Server responded with error status $statusCode.';
      case DioExceptionType.cancel:
        return 'Request to server was canceled.';
      default:
        return 'Network error occurred: ${error.message}';
    }
  }
}
