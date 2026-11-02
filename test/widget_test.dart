import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/main.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';

class FakeLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}
}

class FakeScreeningRepository extends ScreeningRepository {
  FakeScreeningRepository()
      : super(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
          localInferenceService: FakeLocalInferenceService(),
        );

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    return {'status': 'ok', 'model_loaded': true, 'device': 'cuda'};
  }

  @override
  Future<Map<String, dynamic>> getModelInfo() async {
    return {'architecture': 'Late-Fusion Attention', 'model': 'Baseline'};
  }

  @override
  Future<ScreeningListResponse> getScreeningHistory({
    int skip = 0,
    int limit = 20,
    String? participantId,
    String? status,
  }) async {
    return ScreeningListResponse(total: 0, screenings: []);
  }
}

void main() {
  testWidgets('FedMindApp smoke test with stub repository and disclaimer popup',
      (WidgetTester tester) async {
    await tester.pumpWidget(FedMindApp(repository: FakeScreeningRepository()));
    await tester.pumpAndSettle();

    // Verifikasi Pop-up Peringatan Klinis muncul saat awal aplikasi dibuka
    expect(find.text('Pemberitahuan Penting'), findsOneWidget);
    expect(find.text('Bukan Diagnosa Medis Mutlak'), findsOneWidget);
    expect(find.text('100% Berjalan Offline & Data Aman'), findsOneWidget);
    expect(find.text('Saya Mengerti & Lanjutkan'), findsOneWidget);

    // Tekan tombol "Saya Mengerti & Lanjutkan" untuk menutup dialog
    await tester.tap(find.text('Saya Mengerti & Lanjutkan'));
    await tester.pumpAndSettle();

    // Verifikasi Dashboard tampil bersih tanpa navbar dan tanpa kartu teknis
    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Layanan Utama'), findsOneWidget);
    expect(find.text('Cek Kondisi\nMental'), findsOneWidget);
    expect(find.text('Mengenal Pemeriksaan'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Edge Mobile AI Engine Ready'), findsNothing);
  });
}
