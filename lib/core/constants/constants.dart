class ApiConstants {
  // Gunakan 10.0.2.2 untuk Android Emulator yang mengakses localhost mesin host.
  // Ganti dengan IP LAN (misal: http://192.168.1.X:8000) jika menggunakan HP fisik.
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Endpoints
  static const String health = '/health';
  static const String modelInfo = '/model/info';
  static const String screenings = '/screenings';
  static String screeningPredict(String id) => '/screenings/$id/predict';
  static String screeningDetail(String id) => '/screenings/$id';
}
