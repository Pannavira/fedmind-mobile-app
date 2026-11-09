import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';

class MockScreeningRepository extends Fake implements ScreeningRepository {
  int saveRecordCallCount = 0;
  final LocalInferenceService _inferenceService = LocalInferenceService();

  @override
  LocalInferenceService get localInferenceService => _inferenceService;

  @override
  Future<ScreeningResponse> executeLocalScreening({
    required String participantId,
    required List<double> textFeatures,
    required List<double> audioFeatures,
    required List<double> visualFeatures,
    String? sessionId,
    String? counselorNote,
    String? transcription,
  }) async {
    return ScreeningResponse(
      screeningId: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
      participantId: participantId,
      status: 'completed',
      createdAt: DateTime.now().toIso8601String(),
      prediction: PredictionResult(
        riskCategory: 'moderate',
        phq8Score: 12.0,
        binaryPrediction: 'depressed',
        riskProbabilityProxy: 0.75,
      ),
      patientModalityAttribution: PatientModalityAttribution(
        dominantModality: 'visual',
        visualPct: 55.0,
        audioPct: 30.0,
        textPct: 15.0,
        shapValues: PatientShapValues(visual: 2.5, audio: 1.2, text: 0.6),
      ),
      qualityFlags: QualityFlags(
        poorVisualQuality: false,
        poorAudioQuality: false,
        lowTextInformation: false,
      ),
    );
  }

  @override
  Future<void> saveLocalScreeningRecord({
    required ScreeningResponse screening,
    dynamic inspectionData,
    String? videoPath,
  }) async {
    saveRecordCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simulation Sandbox Isolation Tests', () {
    late MockScreeningRepository mockRepo;
    late ScreeningProvider provider;

    setUp(() {
      mockRepo = MockScreeningRepository();
      provider = ScreeningProvider(repository: mockRepo);
    });

    test('Simulation execution does NOT save to database, does NOT add to history, and does NOT require verification', () async {
      // Pastikan kondisi awal riwayat kosong
      expect(provider.historyItems, isEmpty);
      expect(provider.pendingVerificationCount, 0);
      expect(mockRepo.saveRecordCallCount, 0);

      // Jalankan simulasi (isSimulation: true)
      final success = await provider.executeLocalOnDeviceScreening(
        participantId: 'P600-SIM',
        textFeatures: List.filled(768, 0.1),
        audioFeatures: List.filled(248, 0.1),
        visualFeatures: List.filled(75, 0.1),
        isSimulation: true,
      );

      expect(success, isTrue);
      expect(provider.currentScreening, isNotNull);
      expect(provider.currentScreening!.isSimulation, isTrue);
      expect(provider.currentScreening!.sessionType, 'simulation');

      // Database SQLite TIDAK boleh dipanggil untuk menyimpan record simulasi
      expect(mockRepo.saveRecordCallCount, 0);

      // History item TIDAK boleh bertambah
      expect(provider.historyItems, isEmpty);

      // Pending verification TIDAK boleh bertambah
      expect(provider.pendingVerificationCount, 0);
    });

    test('Real patient screening DOES save to database and DOES add to verification queue', () async {
      // Jalankan skrining klinis nyata (isSimulation: false)
      final success = await provider.executeLocalOnDeviceScreening(
        participantId: 'PATIENT-001',
        textFeatures: List.filled(768, 0.1),
        audioFeatures: List.filled(248, 0.1),
        visualFeatures: List.filled(75, 0.1),
        isSimulation: false,
      );

      expect(success, isTrue);
      expect(provider.currentScreening, isNotNull);
      expect(provider.currentScreening!.isSimulation, isFalse);

      // Harus tersimpan ke database rekam medis lokal
      expect(mockRepo.saveRecordCallCount, 1);

      // Harus masuk ke daftar riwayat pemeriksaan
      expect(provider.historyItems.length, 1);

      // Harus tercatat dalam antrean verifikasi klinisi
      expect(provider.pendingVerificationCount, 1);
    });

    testWidgets('ScreeningResultScreen in simulation mode hides save verification button and shows sandbox banner', (WidgetTester tester) async {
      final simResult = ScreeningResponse(
        screeningId: 'SIM-999',
        participantId: 'P600',
        status: 'completed',
        sessionType: 'simulation',
        prediction: PredictionResult(
          riskCategory: 'moderate',
          phq8Score: 12.0,
          binaryPrediction: 'depressed',
          riskProbabilityProxy: 0.75,
        ),
        patientModalityAttribution: PatientModalityAttribution(
          dominantModality: 'visual',
          visualPct: 50.0,
          audioPct: 30.0,
          textPct: 20.0,
          shapValues: PatientShapValues(visual: 2.0, audio: 1.0, text: 0.5),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ScreeningProvider>.value(
          value: provider,
          child: MaterialApp(
            home: ScreeningResultScreen(
              result: simResult,
              isSimulation: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner Sandbox muncul
      expect(find.text('Sesi Simulasi & Benchmark (Sandbox)'), findsOneWidget);

      // Status simulasi muncul di bagian verifikasi
      expect(find.text('Sesi Simulasi • Tidak Masuk Antrean Verifikasi'), findsOneWidget);

      // Tombol simpan verifikasi ke database pasien TIDAK boleh ada
      expect(find.text('Simpan Verifikasi ke Rekam Medis Lokal'), findsNothing);
    });
  });
}
