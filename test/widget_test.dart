import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/main.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/verification/clinical_verification_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_bottom_nav_bar.dart';

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

  @override
  Future<List<ScreeningSummaryItem>> getLocalScreeningHistory({
    int skip = 0,
    int limit = 50,
    String? participantId,
    String? riskCategory,
  }) async {
    return [];
  }

  @override
  Future<int> getLocalScreeningTotalCount() async {
    return 0;
  }

  @override
  Future<ScreeningResponse?> saveLocalClinicalVerification({
    required String screeningId,
    required ClinicalVerificationData verification,
  }) async {
    return null;
  }

  @override
  Future<void> saveLocalScreeningRecord({
    required ScreeningResponse screening,
    dynamic inspectionData,
    String? videoPath,
  }) async {}
}

void main() {
  testWidgets(
      'FedMindApp CDSS Clinical Dashboard & Authorization Dialog smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(FedMindApp(repository: FakeScreeningRepository()));
    await tester.pumpAndSettle();

    // Verifikasi Dialog Otorisasi Konsol CDSS muncul saat awal aplikasi dibuka
    expect(
      find.text('Otorisasi Konsol CDSS & Audit Model'),
      findsOneWidget,
    );
    expect(
      find.text('Instrumen Pendukung Keputusan Klinis (Human-in-the-Loop)'),
      findsOneWidget,
    );
    expect(
      find.text('Konfirmasi Otorisasi Klinisi & Buka Konsol'),
      findsOneWidget,
    );

    // Tekan tombol otorisasi untuk menutup dialog
    await tester.tap(find.text('Konfirmasi Otorisasi Klinisi & Buka Konsol'));
    await tester.pumpAndSettle();

    // Verifikasi Dashboard Konsol Konseling tampil bersih & elegan
    expect(find.text('FEDMIND Prototype 1'), findsOneWidget);
    expect(find.text('Layanan Asesmen'), findsOneWidget);
    expect(find.text('Mulai Pemeriksaan Pasien'), findsOneWidget);
    // Shortcut Golden Case telah dipindahkan ke tab tersendiri "Simulasi"
    expect(
      find.text('Uji Kasus Standar (Golden Case P600)'),
      findsNothing,
    );
    expect(find.text('Simulasi'), findsOneWidget);
    expect(find.text('Daftar Pasien & Riwayat'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
      'ScreeningResultScreen displays Model Verification & SOAP Workbench',
      (WidgetTester tester) async {
    final fakeRepo = FakeScreeningRepository();
    final provider = ScreeningProvider(repository: fakeRepo);

    final sampleResult = ScreeningResponse(
      screeningId: 'SCR-TEST-600',
      participantId: 'P600',
      status: 'completed',
      prediction: PredictionResult(
        phq8Score: 15.4,
        riskProbabilityProxy: 0.86,
        binaryPrediction: 'depression_risk',
        riskCategory: 'high',
      ),
      patientModalityAttribution: PatientModalityAttribution(
        textPct: 25.0,
        visualPct: 50.0,
        audioPct: 25.0,
        dominantModality: 'visual',
        shapValues: PatientShapValues(text: 1.5, visual: 3.8, audio: 1.68),
      ),
      createdAt: '2026-11-07T10:00:00Z',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ScreeningProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ScreeningResultScreen(result: sampleResult),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asesmen: P600'), findsOneWidget);
    expect(find.text('Hasil Skrining Model Multimodal'), findsOneWidget);
    expect(find.text('Faktor Observasi Multimodal'), findsOneWidget);
    expect(find.text('Panduan Tindak Lanjut Konseling'), findsOneWidget);
    expect(find.text('Kesimpulan & Penjelasan Model'), findsOneWidget);
    expect(find.text('Masuk ke Lembar Verifikasi Konselor'), findsOneWidget);
    expect(find.byType(ClinicalBottomNavBar), findsOneWidget);
    expect(find.text('Evaluasi Ahli Klinis'), findsNothing);

    // Test layar terpisah ClinicalVerificationScreen
    await tester.pumpWidget(
      ChangeNotifierProvider<ScreeningProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ClinicalVerificationScreen(screening: sampleResult),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evaluasi Hasil Pemeriksaan'), findsOneWidget);
    expect(find.text('Sesuai / Cocok'), findsOneWidget);
    expect(find.text('Hasil Terlalu Tinggi'), findsOneWidget);
    expect(find.text('Hasil Terlalu Rendah'), findsOneWidget);
    expect(find.text('Kualitas Rekaman Kurang'), findsOneWidget);
    expect(find.text('Wajah & Mimik Jelas'), findsOneWidget);
    expect(find.text('Suara Terdengar Jernih'), findsOneWidget);
    expect(find.text('Percakapan Memadai'), findsOneWidget);
    expect(find.byType(ClinicalBottomNavBar), findsOneWidget);
    expect(
      find.text('Simpan Verifikasi ke Rekam Medis'),
      findsOneWidget,
    );
  });
}
