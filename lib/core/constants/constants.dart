class ApiConstants {
  // Mode Standalone On-Device: Seluruh inferensi dan pemrosesan berjalan lokal di perangkat.
  // URL Aggregator Pusat hanya opsional untuk sinkronisasi agregasi bobot FL terfederasi (FedAvg).
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Central Endpoints (Opsional Sinkronisasi FL)
  static const String health = '/health';
  static const String modelInfo = '/model/info';
  static const String screenings = '/screenings';
  static String screeningPredict(String id) => '/screenings/$id/predict';
  static String screeningDetail(String id) => '/screenings/$id';
}

