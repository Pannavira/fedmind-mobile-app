import 'package:dio/dio.dart';
import '../datasources/screening_remote_datasource.dart';
import '../models/screening_models.dart';

class ScreeningRepository {
  final ScreeningRemoteDataSource remoteDataSource;

  ScreeningRepository({required this.remoteDataSource});

  /// Cek kesehatan backend dan status model
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      return await remoteDataSource.checkHealth();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Terjadi kesalahan tidak terduga: $e';
    }
  }

  /// Cek kesehatan Local Edge Server (port 8001)
  Future<Map<String, dynamic>> checkEdgeHealth() async {
    try {
      return await remoteDataSource.checkEdgeHealth();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Gagal terhubung ke Local Edge Server: $e';
    }
  }

  /// Ambil info model
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      return await remoteDataSource.getModelInfo();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Terjadi kesalahan tidak terduga: $e';
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
      throw 'Gagal membuat sesi skrining: $e';
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
      throw 'Gagal menjalankan inferensi multimodal: $e';
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
      throw 'Gagal memproses video di Local Edge Server: $e';
    }
  }

  /// Ambil detail skrining tersimpan
  Future<ScreeningResponse> getScreeningDetail(String screeningId) async {
    try {
      return await remoteDataSource.getScreeningDetail(screeningId);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw 'Gagal mengambil detail skrining: $e';
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
      throw 'Gagal memuat riwayat skrining: $e';
    }
  }

  /// Format error Dio menjadi pesan yang dapat dipahami user
  String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi ke server timeout. Proses ekstraksi video neural mungkin memerlukan waktu lebih lama.';
      case DioExceptionType.connectionError:
        return 'Gagal terhubung ke server (${error.requestOptions.baseUrl}). Pastikan Uvicorn berjalan (Central: 8000, Edge: 8001).';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        if (responseData is Map && responseData.containsKey('detail')) {
          return 'Server error ($statusCode): ${responseData['detail']}';
        }
        return 'Server merespons dengan kode error $statusCode.';
      case DioExceptionType.cancel:
        return 'Permintaan ke server dibatalkan.';
      default:
        return 'Terjadi gangguan jaringan: ${error.message}';
    }
  }
}
