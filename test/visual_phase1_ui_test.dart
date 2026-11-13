import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/multimodal_inspection/face_modality_card.dart';

class _StubLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}
}

class _StubScreeningRepository extends ScreeningRepository {
  _StubScreeningRepository()
      : super(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
          localInferenceService: _StubLocalInferenceService(),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 Visual UI Integrity Tests', () {
    testWidgets(
      'FaceModalityCard preserves P716 depressive affect title & description while translating FACS terms',
      (tester) async {
        final p716Data = json.decode(
          File('assets/samples/p716_features.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        final inspection =
            MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: 'P716',
          visualFeatures: (p716Data['visual_features'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          audioFeatures: (p716Data['audio_features'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          textFeatures: (p716Data['text_features'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
          clientTranscript: p716Data['transcript_excerpt'] as String?,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FaceModalityCard(inspection: inspection),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('Afek Wajah Depresif'), findsOneWidget);
        expect(
          find.textContaining('Ekspresi Afek Tenang dengan Sedikit Kerutan Dahi'),
          findsNothing,
        );
        expect(find.textContaining('AU04 p90=0.97'), findsOneWidget);
        expect(find.textContaining('penurunan sudut bibir'), findsOneWidget);
      },
    );

    testWidgets(
      'ScreeningResultScreen visualReason reflects actual pV, visualPct, faceDetectionRatePct, pose, and AU scores',
      (tester) async {
        final provider = ScreeningProvider(
          repository: _StubScreeningRepository(),
        );

        final response = ScreeningResponse(
          screeningId: 'SCR-PHASE1-TEST',
          participantId: 'P_TEST_VIS',
          status: 'completed',
          prediction: PredictionResult(
            phq8Score: 13.5,
            riskProbabilityProxy: 0.77,
            binaryPrediction: 'depression_risk',
            riskCategory: 'moderate',
          ),
          patientModalityAttribution: PatientModalityAttribution(
            textPct: 50.0,
            visualPct: 35.5,
            audioPct: 14.5,
            dominantModality: 'text',
            shapValues: PatientShapValues(
              text: 3.10,
              visual: -1.42, // visual pulls risk DOWN despite moderate overall score
              audio: 0.58,
            ),
          ),
          qualityFlags: QualityFlags(
            lowTextInformation: false,
            poorAudioQuality: false,
            poorVisualQuality: false,
          ),
        );

        const inspection = MultimodalInspectionData(
          participantId: 'P_TEST_VIS',
          isFromRealVideo: true,
          videoDurationSec: 30.0,
          framesAnalyzed: 24,
          facesDetected: 21,
          faceDetectionRatePct: 87.5,
          avgFaceConfidence: 95.0,
          avgHeadPitchDeg: -2.4,
          avgHeadYawDeg: 1.1,
          facialAffectTitle: 'Wajah Terdeteksi Jelas & Ekspresi Responsif',
          facialAffectDescription: 'Wajah terdeteksi konsisten.',
          actionUnitScores: {
            'AU04 Brow Lowerer (Corrugator Supercilii)': 0.31,
            'AU05 Upper Lid Raiser (Eye Aperture)': 0.74,
            'AU12 Lip Corner Puller (Zygomaticus / Smile)': 0.81,
            'AU15 Lip Corner Depressor (Depressive Affect)': 0.22,
            'Optical Flow / Facial Motor Dynamics': 0.69,
          },
          visualFrames: [],
          audioSampleRate: 16000,
          totalAudioSamples: 160000,
          audioWaveformBars: [0.3, 0.4],
          pitchContourHz: [140.0, 145.0],
          avgPitchHz: 142.5,
          pitchStdHz: 14.0,
          voicedRatioPct: 68.0,
          pauseRatioPct: 32.0,
          jitterPct: 1.1,
          shimmerPct: 4.5,
          vocalProsodyTitle: 'Stabil',
          vocalProsodyDescription: 'Stabil',
          fullTranscript: 'Test transcript',
          transcriptSegments: [],
          detectedKeywords: [],
          emotionalValence: -0.2,
          selfPronounCount: 2,
          linguisticTitle: 'Netral',
          linguisticDescription: 'Netral',
          sampleVisualVector: [],
          sampleAudioVector: [],
          sampleTextVector: [],
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ScreeningProvider>.value(
            value: provider,
            child: MaterialApp(
              home: ScreeningResultScreen(
                result: response,
                inspectionData: inspection,
                isSimulation: true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('88%'), findsWidgets);
        expect(find.textContaining('-1.42 poin PHQ-8'), findsOneWidget);
        expect(find.textContaining('35.5%'), findsWidgets);
        expect(find.textContaining('Senyum (AU12) 81%'), findsOneWidget);
        expect(find.textContaining('Ketegangan Alis (AU04) 31%'), findsOneWidget);
      },
    );
  });
}
