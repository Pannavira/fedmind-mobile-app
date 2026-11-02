class ApiConstants {
  // Server Pusat (Aggregator & Registri Model Global)
  // Gunakan 10.0.2.2 untuk Android Emulator yang mengakses localhost mesin host.
  // Ganti dengan IP LAN (misal: http://192.168.1.X:8000) jika menggunakan HP fisik.
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Local Edge Server (Microservice Ekstraksi Multimodal Riil di Komputer Konselor)
  static const String edgeBaseUrl = 'http://10.0.2.2:8001';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Timeout khusus untuk proses ekstraksi video neural (OpenFace + Whisper + MentalBERT)
  static const Duration edgeReceiveTimeout = Duration(minutes: 5);

  // Central Endpoints
  static const String health = '/health';
  static const String modelInfo = '/model/info';
  static const String screenings = '/screenings';
  static String screeningPredict(String id) => '/screenings/$id/predict';
  static String screeningDetail(String id) => '/screenings/$id';

  // Edge Endpoints
  static const String edgeProcessVideo = '/api/v1/edge/screening/process-video';
  static const String edgeHealth = '/health';
}

