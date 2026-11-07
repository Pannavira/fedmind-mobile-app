import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_local_datasource.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';

class StubLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}

  @override
  Future<ScreeningResponse> predict({
    required List<double> audioFeatures,
    required List<double> visualFeatures,
    required List<double> textFeatures,
    required String participantId,
    String? sessionId,
    String? counselorNote,
    String? transcription,
  }) async {
    return ScreeningResponse(
      screeningId: sessionId ?? 'SESSION-SQL-999',
      participantId: participantId,
      status: 'completed',
      prediction: PredictionResult(
        phq8Score: 13.8,
        riskProbabilityProxy: 0.65,
        binaryPrediction: 'depression',
        riskCategory: 'moderate',
      ),
      patientModalityAttribution: PatientModalityAttribution(
        textPct: 25.0,
        visualPct: 60.0,
        audioPct: 15.0,
        dominantModality: 'visual',
        shapValues: PatientShapValues(text: 0.8, visual: 2.1, audio: 0.4),
      ),
      clinicalNarrative: 'Klinis pasien terverifikasi.',
      createdAt: '2026-11-07T12:00:00Z',
      completedAt: '2026-11-07T12:00:02Z',
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScreeningProvider Persistent SQLite Integration Tests', () {
    late Database inMemoryDb;
    late ScreeningLocalDataSource localDataSource;
    late ScreeningRepository repository;

    setUp(() async {
      inMemoryDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: ScreeningLocalDataSource.onCreate,
        ),
      );
      localDataSource = ScreeningLocalDataSource(initialDatabase: inMemoryDb);
      repository = ScreeningRepository(
        remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
        localInferenceService: StubLocalInferenceService(),
        localDataSource: localDataSource,
      );
    });

    tearDown(() async {
      await localDataSource.close();
    });

    test(
        'Screening should persist to SQLite and remain retrievable after app restart (simulated new provider)',
        () async {
      // 1. Inisialisasi provider pertama (Sesi Pertama)
      final providerSession1 = ScreeningProvider(repository: repository);

      final dummyInspection = MultimodalInspectionData(
        participantId: 'Patient-Persistent-01',
        videoPath: '/data/user/0/com.fedmind/clinical_patient_recordings/REC_P01.mp4',
        isFromRealVideo: true,
        videoDurationSec: 30.0,
        framesAnalyzed: 90,
        facesDetected: 88,
        faceDetectionRatePct: 97.7,
        avgFaceConfidence: 0.92,
        avgHeadPitchDeg: -4.0,
        avgHeadYawDeg: 2.0,
        facialAffectTitle: 'Reduced Facial Mobility',
        facialAffectDescription: 'Depression motor signature detected.',
        actionUnitScores: {'AU04': 0.6, 'AU12': 0.05},
        visualFrames: const [],
        audioSampleRate: 16000,
        totalAudioSamples: 480000,
        audioWaveformBars: [0.1, 0.3],
        pitchContourHz: [120.0, 125.0],
        avgPitchHz: 122.5,
        pitchStdHz: 3.5,
        voicedRatioPct: 55.0,
        pauseRatioPct: 45.0,
        jitterPct: 1.5,
        shimmerPct: 2.8,
        vocalProsodyTitle: 'Monotone Voice',
        vocalProsodyDescription: 'Reduced vocal dynamism.',
        fullTranscript: 'Hari-hari terasa berat belakangan ini.',
        transcriptSegments: const [],
        detectedKeywords: ['berat'],
        emotionalValence: -0.5,
        selfPronounCount: 1,
        linguisticTitle: 'Negative affect',
        linguisticDescription: 'Fatigue themes present.',
        sampleVisualVector: const [0.1],
        sampleAudioVector: const [0.2],
        sampleTextVector: const [0.3],
      );

      // Jalankan skrining di session 1
      final success = await providerSession1.executeLocalOnDeviceScreening(
        participantId: 'Patient-Persistent-01',
        sessionId: 'SCR-SESSION-101',
        textFeatures: [0.1, 0.2],
        audioFeatures: [0.3, 0.4],
        visualFeatures: [0.5, 0.6],
        counselorNote: 'Catatan konselor awal',
        inspectionData: dummyInspection,
      );

      expect(success, isTrue);
      expect(providerSession1.currentScreening, isNotNull);
      expect(providerSession1.historyItems.length, 1);
      expect(providerSession1.historyItems.first.participantId, 'Patient-Persistent-01');

      // 2. Simulasikan aplikasi ditutup (RAM dibersihkan) dan dibuka kembali dengan Provider baru
      final providerSession2 = ScreeningProvider(repository: repository);
      // Sebelum fetchHistory, session baru belum punya data di memory
      expect(providerSession2.historyItems, isEmpty);
      expect(providerSession2.currentScreening, isNull);

      // 3. Panggil fetchHistory() di session baru (membaca SQLite)
      await providerSession2.fetchHistory();
      expect(providerSession2.historyItems.length, 1);
      expect(providerSession2.historyItems.first.screeningId, 'SCR-SESSION-101');
      expect(providerSession2.historyItems.first.participantId, 'Patient-Persistent-01');
      expect(providerSession2.historyItems.first.phq8Score, 13.8);
      expect(providerSession2.historyItems.first.riskCategory, 'moderate');

      // 4. Buka detail skrining dari session baru
      await providerSession2.loadScreeningDetail('SCR-SESSION-101');
      expect(providerSession2.currentScreening, isNotNull);
      expect(providerSession2.currentScreening!.screeningId, 'SCR-SESSION-101');
      expect(providerSession2.currentScreening!.prediction?.phq8Score, 13.8);

      // Verifikasi data inspeksi multimodal juga berhasil dipulihkan dari SQLite
      expect(providerSession2.currentInspectionData, isNotNull);
      expect(providerSession2.currentInspectionData!.facialAffectTitle, 'Reduced Facial Mobility');
      expect(providerSession2.currentInspectionData!.fullTranscript, 'Hari-hari terasa berat belakangan ini.');
      expect(providerSession2.currentInspectionData!.videoPath,
          '/data/user/0/com.fedmind/clinical_patient_recordings/REC_P01.mp4');

      // 5. Test penghapusan data
      final deleteSuccess = await providerSession2.deleteScreeningRecord('SCR-SESSION-101');
      expect(deleteSuccess, isTrue);
      expect(providerSession2.historyItems, isEmpty);

      // Verifikasi di session 3 (setelah dihapus, data SQLite benar-benar kosong)
      final providerSession3 = ScreeningProvider(repository: repository);
      await providerSession3.fetchHistory();
      expect(providerSession3.historyItems, isEmpty);
    });
  });
}

