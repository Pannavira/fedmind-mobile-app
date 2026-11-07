import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_local_datasource.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScreeningLocalDataSource SQLite Tests', () {
    late Database db;
    late ScreeningLocalDataSource dataSource;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: ScreeningLocalDataSource.onCreate,
        ),
      );
      dataSource = ScreeningLocalDataSource(initialDatabase: db);
    });

    tearDown(() async {
      await dataSource.close();
    });

    ScreeningResponse createSampleScreening({
      required String id,
      required String participantId,
      required double phq8,
      required String risk,
      String modality = 'visual',
      String? createdAt,
    }) {
      return ScreeningResponse(
        screeningId: id,
        participantId: participantId,
        status: 'completed',
        prediction: PredictionResult(
          phq8Score: phq8,
          riskProbabilityProxy: phq8 / 24.0,
          binaryPrediction: phq8 >= 10.0 ? 'depression' : 'non_depression',
          riskCategory: risk,
        ),
        patientModalityAttribution: PatientModalityAttribution(
          textPct: 20.0,
          visualPct: 70.0,
          audioPct: 10.0,
          dominantModality: modality,
          shapValues: PatientShapValues(text: 0.5, visual: 2.5, audio: 0.2),
        ),
        clinicalNarrative: 'Patient $participantId screening test.',
        createdAt: createdAt ?? DateTime.now().toIso8601String(),
        completedAt: DateTime.now().toIso8601String(),
      );
    }

    test('Should insert screening and retrieve complete detail from SQLite',
        () async {
      final sample = createSampleScreening(
        id: 'SCR-001',
        participantId: 'P100',
        phq8: 14.5,
        risk: 'high',
        modality: 'visual',
      );

      await dataSource.insertOrUpdateScreening(
        screening: sample,
        videoPath: '/data/user/0/com.fedmind/clinical_patient_recordings/REC_P100.mp4',
      );

      final retrieved = await dataSource.getScreeningDetail('SCR-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.screeningId, 'SCR-001');
      expect(retrieved.participantId, 'P100');
      expect(retrieved.prediction?.phq8Score, 14.5);
      expect(retrieved.prediction?.riskCategory, 'high');
      expect(retrieved.patientModalityAttribution?.dominantModality, 'visual');
      expect(retrieved.patientModalityAttribution?.shapValues.visual, 2.5);

      final videoPath = await dataSource.getVideoPath('SCR-001');
      expect(
        videoPath,
        '/data/user/0/com.fedmind/clinical_patient_recordings/REC_P100.mp4',
      );
    });

    test('Should save and retrieve full MultimodalInspectionData with nested fields',
        () async {
      final sample = createSampleScreening(
        id: 'SCR-002',
        participantId: 'P200',
        phq8: 8.0,
        risk: 'borderline',
      );

      final inspection = MultimodalInspectionData(
        participantId: 'P200',
        videoPath: '/path/video.mp4',
        isFromRealVideo: true,
        videoDurationSec: 45.0,
        framesAnalyzed: 120,
        facesDetected: 118,
        faceDetectionRatePct: 98.3,
        avgFaceConfidence: 0.94,
        avgHeadPitchDeg: -3.2,
        avgHeadYawDeg: 1.1,
        facialAffectTitle: 'Flat affect with brow tension',
        facialAffectDescription: 'AU04 Corrugator activation detected.',
        actionUnitScores: {'AU04': 0.75, 'AU12': 0.1},
        visualFrames: [
          const VisualFrameInspection(
            frameIndex: 1,
            timeSec: 0.5,
            faceFound: true,
            confidence: 0.95,
            bboxLeft: 10,
            bboxTop: 10,
            bboxRight: 200,
            bboxBottom: 200,
            eulerX: -2.0,
            eulerY: 1.0,
            eulerZ: 0.5,
            browTension: 0.8,
            eyeOpenness: 0.5,
            smileIntensity: 0.05,
            lipDepressor: 0.6,
            motionEnergy: 0.02,
            expressionLabel: 'Flat / Depressed Affect',
          ),
        ],
        audioSampleRate: 16000,
        totalAudioSamples: 720000,
        audioWaveformBars: [0.1, 0.2, 0.35, 0.15],
        pitchContourHz: [130.0, 132.5, 129.0],
        avgPitchHz: 130.5,
        pitchStdHz: 5.2,
        voicedRatioPct: 62.0,
        pauseRatioPct: 38.0,
        jitterPct: 1.2,
        shimmerPct: 2.1,
        vocalProsodyTitle: 'Monotone Prosody',
        vocalProsodyDescription: 'Pitch variation compressed.',
        fullTranscript: 'Saya merasa lelah dan sulit konsentrasi.',
        transcriptSegments: [
          const TranscriptSegmentItem(
            timeRangeLabel: '00:00 - 00:05',
            text: 'Saya merasa lelah dan sulit konsentrasi.',
            detectedKeywords: ['lelah', 'sulit konsentrasi'],
            prosodyNote: 'Slow speech rate',
          ),
        ],
        detectedKeywords: ['lelah', 'sulit konsentrasi'],
        emotionalValence: -0.65,
        selfPronounCount: 1,
        linguisticTitle: 'Depressive Negative Valence',
        linguisticDescription: 'High frequency of fatigue markers.',
        sampleVisualVector: [0.1, 0.2],
        sampleAudioVector: [0.3, 0.4],
        sampleTextVector: [0.5, 0.6],
        coalitionScores: [
          const CoalitionStepScore(
            coalitionCode: 'V',
            label: 'Visual Only',
            description: 'Facial affect contribution',
            hasAudio: false,
            hasVisual: true,
            hasText: false,
            predictedScore: 7.5,
          ),
        ],
      );

      await dataSource.insertOrUpdateScreening(
        screening: sample,
        inspectionData: inspection,
      );

      final retrievedInspection = await dataSource.getInspectionData('SCR-002');
      expect(retrievedInspection, isNotNull);
      expect(retrievedInspection!.participantId, 'P200');
      expect(retrievedInspection.facialAffectTitle, 'Flat affect with brow tension');
      expect(retrievedInspection.actionUnitScores['AU04'], 0.75);
      expect(retrievedInspection.visualFrames.length, 1);
      expect(retrievedInspection.visualFrames.first.expressionLabel, 'Flat / Depressed Affect');
      expect(retrievedInspection.audioWaveformBars, [0.1, 0.2, 0.35, 0.15]);
      expect(retrievedInspection.transcriptSegments.first.detectedKeywords, ['lelah', 'sulit konsentrasi']);
      expect(retrievedInspection.coalitionScores.first.coalitionCode, 'V');
    });

    test('Should return screening history ordered by created_at DESC with filters',
        () async {
      await dataSource.insertOrUpdateScreening(
        screening: createSampleScreening(
          id: 'SCR-1',
          participantId: 'Patient-Alpha',
          phq8: 4.0,
          risk: 'low',
          createdAt: '2026-11-01T10:00:00Z',
        ),
      );
      await dataSource.insertOrUpdateScreening(
        screening: createSampleScreening(
          id: 'SCR-2',
          participantId: 'Patient-Beta',
          phq8: 16.0,
          risk: 'high',
          createdAt: '2026-11-02T10:00:00Z',
        ),
      );
      await dataSource.insertOrUpdateScreening(
        screening: createSampleScreening(
          id: 'SCR-3',
          participantId: 'Patient-Alpha',
          phq8: 11.0,
          risk: 'moderate',
          createdAt: '2026-11-03T10:00:00Z',
        ),
      );

      // Verify total count
      final total = await dataSource.getTotalCount();
      expect(total, 3);

      // Verify default history order (newest first)
      final allHistory = await dataSource.getScreeningHistory();
      expect(allHistory.length, 3);
      expect(allHistory[0].screeningId, 'SCR-3');
      expect(allHistory[1].screeningId, 'SCR-2');
      expect(allHistory[2].screeningId, 'SCR-1');

      // Filter by participantId
      final alphaHistory = await dataSource.getScreeningHistory(
        participantId: 'Alpha',
      );
      expect(alphaHistory.length, 2);
      expect(alphaHistory[0].screeningId, 'SCR-3');
      expect(alphaHistory[1].screeningId, 'SCR-1');

      // Filter by riskCategory
      final highRiskHistory = await dataSource.getScreeningHistory(
        riskCategory: 'High',
      );
      expect(highRiskHistory.length, 1);
      expect(highRiskHistory.first.screeningId, 'SCR-2');
    });

    test('Should delete single screening and clear all screenings', () async {
      await dataSource.insertOrUpdateScreening(
        screening: createSampleScreening(
          id: 'DEL-1',
          participantId: 'PX1',
          phq8: 5.0,
          risk: 'low',
        ),
      );
      await dataSource.insertOrUpdateScreening(
        screening: createSampleScreening(
          id: 'DEL-2',
          participantId: 'PX2',
          phq8: 12.0,
          risk: 'moderate',
        ),
      );

      expect(await dataSource.getTotalCount(), 2);

      // Delete DEL-1
      final deleted = await dataSource.deleteScreening('DEL-1');
      expect(deleted, isTrue);
      expect(await dataSource.getTotalCount(), 1);
      expect(await dataSource.getScreeningDetail('DEL-1'), isNull);

      // Clear all
      await dataSource.clearAll();
      expect(await dataSource.getTotalCount(), 0);
    });
  });
}
