import 'package:dio/dio.dart';
import 'package:fedmind_mobile_app/core/constants/constants.dart';

import '../../core/network/api_client.dart';
import '../models/screening_models.dart';

class ScreeningRemoteDataSource {
  final ApiClient apiClient;

  ScreeningRemoteDataSource({required this.apiClient});

  /// Cek kesehatan backend dan ketersediaan CUDA
  Future<Map<String, dynamic>> checkHealth() async {
    final response = await apiClient.dio.get(ApiConstants.health);
    return response.data as Map<String, dynamic>;
  }

  /// Cek kesehatan Local Edge Server (port 8001)
  Future<Map<String, dynamic>> checkEdgeHealth() async {
    final response = await apiClient.edgeDio.get(ApiConstants.edgeHealth);
    return response.data as Map<String, dynamic>;
  }

  /// Ambil info model baseline yang sedang aktif di backend
  Future<Map<String, dynamic>> getModelInfo() async {
    final response = await apiClient.dio.get(ApiConstants.modelInfo);
    return response.data as Map<String, dynamic>;
  }

  /// Langkah 1: Buat sesi skrining baru di backend
  Future<ScreeningCreateResponse> createScreeningSession({
    required String participantId,
    Map<String, dynamic>? metadata,
  }) async {
    final request = ScreeningCreateRequest(
      participantId: participantId,
      metadata: metadata,
    );
    final response = await apiClient.dio.post(
      ApiConstants.screenings,
      data: request.toJson(),
    );
    return ScreeningCreateResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Langkah 2: Kirim fitur multimodal untuk inferensi & Exact XAI
  Future<ScreeningResponse> executeScreening({
    required String screeningId,
    required dynamic textFeatures,
    required dynamic audioFeatures,
    required dynamic visualFeatures,
    Map<String, dynamic>? metadata,
  }) async {
    final request = ScreeningExecuteRequest(
      textFeatures: textFeatures,
      audioFeatures: audioFeatures,
      visualFeatures: visualFeatures,
      metadata: metadata,
    );
    final response = await apiClient.dio.post(
      ApiConstants.screeningPredict(screeningId),
      data: request.toJson(),
    );
    return ScreeningResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Kirim video rekaman klinis langsung ke Local Edge Server (port 8001)
  /// Ekstraksi OpenFace, openSMILE, dan Whisper dijalankan on-premise
  Future<ScreeningResponse> processVideoViaEdge({
    required String videoPath,
    required String participantId,
    String? sessionId,
    ProgressCallback? onSendProgress,
  }) async {
    final fileName = videoPath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'video_file': await MultipartFile.fromFile(
        videoPath,
        filename: fileName,
      ),
      'participant_id': participantId,
      'session_id': ?sessionId,
    });

    final response = await apiClient.edgeDio.post(
      ApiConstants.edgeProcessVideo,
      data: formData,
      onSendProgress: onSendProgress,
    );

    return ScreeningResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ambil hasil skrining dan XAI yang tersimpan berdasarkan ID
  Future<ScreeningResponse> getScreeningDetail(String screeningId) async {
    final response = await apiClient.dio.get(
      ApiConstants.screeningDetail(screeningId),
    );
    return ScreeningResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ambil riwayat skrining dengan pagination
  Future<ScreeningListResponse> getScreeningHistory({
    int skip = 0,
    int limit = 20,
    String? participantId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{'skip': skip, 'limit': limit};
    if (participantId != null) queryParams['participant_id'] = participantId;
    if (status != null) queryParams['status'] = status;

    final response = await apiClient.dio.get(
      ApiConstants.screenings,
      queryParameters: queryParams,
    );
    return ScreeningListResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
