import 'package:dio/dio.dart';
import '../../core/services/local_inference_service.dart';
import '../datasources/screening_remote_datasource.dart';
import '../models/screening_models.dart';

class ScreeningRepository {
  final ScreeningRemoteDataSource remoteDataSource;
  final LocalInferenceService localInferenceService;

  ScreeningRepository({
    required this.remoteDataSource,
    LocalInferenceService? localInferenceService,
  }) : localInferenceService = localInferenceService ?? LocalInferenceService();

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

  /// Cek kesehatan Local Edge Server (port 8001)
  Future<Map<String, dynamic>> checkEdgeHealth() async {
    try {
      return await remoteDataSource.checkEdgeHealth();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to connect to Local Edge Server: $e';
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

  /// Kirim video rekaman klinis ke Local Edge Server (port 8001) untuk ekstraksi multimodal riil
  Future<ScreeningResponse> processVideoViaEdge({
    required String videoPath,
    required String participantId,
    String? sessionId,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      return await remoteDataSource.processVideoViaEdge(
        videoPath: videoPath,
        participantId: participantId,
        sessionId: sessionId,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Failed to process video on Local Edge Server: $e';
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
