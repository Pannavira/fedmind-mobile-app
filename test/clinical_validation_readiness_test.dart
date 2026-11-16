import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/core/services/validation_export_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/verification/clinical_verification_screen.dart';

class _StubLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}
}

class _CapturingScreeningRepository extends ScreeningRepository {
  ClinicalVerificationData? lastSavedVerification;
  String? lastSavedScreeningId;

  _CapturingScreeningRepository()
      : super(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
          localInferenceService: _StubLocalInferenceService(),
        );

  @override
  Future<void> saveLocalScreeningRecord({
    required ScreeningResponse screening,
    dynamic inspectionData,
    String? videoPath,
  }) async {
    lastSavedScreeningId = screening.screeningId;
    lastSavedVerification = screening.clinicalVerification;
  }
}

ScreeningResponse _buildSampleScreening({
  required String id,
  required String participantId,
  required double predPhq8,
  String riskCat = 'moderate',
  ClinicalVerificationData? verification,
  String? note,
}) {
  return ScreeningResponse(
    screeningId: id,
    participantId: participantId,
    status: 'completed',
    createdAt: '2026-11-15T10:00:00Z',
    initialCounselorNote: note,
    prediction: PredictionResult(
      phq8Score: predPhq8,
      riskProbabilityProxy: (predPhq8 / 24.0).clamp(0.0, 1.0),
      binaryPrediction: predPhq8 >= 9.4 ? 'depression_risk' : 'non_depression',
      riskCategory: riskCat,
    ),
    patientModalityAttribution: PatientModalityAttribution(
      textPct: 50.0,
      visualPct: 30.0,
      audioPct: 20.0,
      dominantModality: 'text',
      shapValues: PatientShapValues(text: 1.8, visual: 0.9, audio: 0.6),
    ),
    qualityFlags: QualityFlags(
      lowTextInformation: false,
      poorAudioQuality: false,
      poorVisualQuality: false,
    ),
    clinicalVerification: verification,
  );
}

void main() {
  group('Model 3 Clinical Cutoff & Concordance Metric Tests', () {
    test('ClinicalConstants aligns risk tiers with Model 3 cut-off 9.4', () {
      expect(ClinicalConstants.scoreBorderlineMax, closeTo(9.39, 1e-6));
      expect(ClinicalConstants.scoreModerateMin, closeTo(9.4, 1e-6));

      expect(ClinicalConstants.getRiskLabel('borderline'), contains('8.0–9.3'));
      expect(ClinicalConstants.getRiskLabel('moderate'), contains('9.4–14.9'));
      expect(ClinicalConstants.getRiskShortBadge('moderate'), contains('9.4–14.9'));
      expect(ClinicalConstants.getRiskDescription('moderate'), contains('9.4'));
    });

    test('ScreeningProvider.modelConcordanceRatePct returns null when 0 verified cases exist', () {
      final repo = _CapturingScreeningRepository();
      final provider = ScreeningProvider(repository: repo);
      expect(provider.verifiedCasesCount, equals(0));
      expect(provider.modelConcordanceRatePct, isNull);
    });
  });

  group('ValidationExportService Metrics & Anonymization Tests', () {
    test('computeMetrics returns null stats when no records are verified', () {
      final unverified = [
        _buildSampleScreening(
          id: 'S1',
          participantId: 'Budi Santoso',
          predPhq8: 11.0,
        ),
      ];
      final stats = ValidationExportService.computeMetrics(unverified);
      expect(stats.totalRecords, equals(1));
      expect(stats.verifiedCount, equals(0));
      expect(stats.concordantCount, equals(0));
      expect(stats.concordanceRatePct, isNull);
      expect(stats.mae, isNull);
      expect(stats.rmse, isNull);
    });

    test('computeMetrics and export builders compute exact MAE/RMSE and omit PII', () {
      final verified = [
        _buildSampleScreening(
          id: 'SCR-A',
          participantId: 'Ahmad Wijaya (RM-9901)',
          predPhq8: 12.0,
          note: 'Catatan klinis sensitif tentang keluarga pasien.',
          verification: ClinicalVerificationData(
            isVerified: true,
            concordanceStatus: 'valid',
            groundTruthPhq8: 10.0,
            deviationDelta: 2.0,
            visualPlausible: true,
            audioPlausible: true,
            textPlausible: true,
            soapSubjective: 'Rahasia subjektif SOAP',
            soapObjective: 'Rahasia objektif SOAP',
            soapAssessment: 'Rahasia assessment SOAP',
            soapPlan: 'Rahasia plan SOAP',
            verifiedBy: 'Dr. Rina Sari (Psikolog Klinis)',
            verifiedAt: '2026-11-15T11:00:00Z',
            validatorName: 'Rina Sari',
            validatorRole: 'Psikolog Klinis',
            phq8ItemScores: {
              'q1_anhedonia': 2,
              'q2_depressed_mood': 2,
              'q3_sleep': 1,
              'q4_fatigue': 2,
              'q5_appetite': 1,
              'q6_worthlessness': 1,
              'q7_concentration': 1,
              'q8_psychomotor': 0,
            },
          ),
        ),
        _buildSampleScreening(
          id: 'SCR-B',
          participantId: 'Siti Aminah (RM-9902)',
          predPhq8: 6.0,
          verification: ClinicalVerificationData(
            isVerified: true,
            concordanceStatus: 'overestimated',
            groundTruthPhq8: 6.0,
            deviationDelta: 0.0,
            visualPlausible: true,
            audioPlausible: true,
            textPlausible: true,
            soapSubjective: '',
            soapObjective: '',
            soapAssessment: '',
            soapPlan: '',
            verifiedBy: 'Budi Hartono (Psikiater)',
            verifiedAt: '2026-11-15T12:00:00Z',
            validatorName: 'Budi Hartono',
            validatorRole: 'Psikiater',
          ),
        ),
      ];

      final stats = ValidationExportService.computeMetrics(verified);
      expect(stats.verifiedCount, equals(2));
      expect(stats.concordantCount, equals(1));
      expect(stats.concordanceRatePct, closeTo(50.0, 1e-6));
      // Errors: +2.0 and 0.0 -> MAE = 1.0, RMSE = sqrt((4 + 0)/2) = sqrt(2)
      expect(stats.mae, closeTo(1.0, 1e-6));
      expect(stats.rmse, closeTo(1.4142135, 1e-4));
      expect(stats.meanBias, closeTo(1.0, 1e-6));

      final csv = ValidationExportService.buildAnonymizedCsv(verified);
      expect(csv, contains('SUBJ_001'));
      expect(csv, contains('SUBJ_002'));
      expect(csv, contains('phq8_q1_anhedonia'));
      expect(csv, contains('R.S'));
      expect(csv, isNot(contains('Ahmad Wijaya')));
      expect(csv, isNot(contains('Siti Aminah')));
      expect(csv, isNot(contains('Rahasia subjektif SOAP')));
      expect(csv, isNot(contains('Rina Sari')));

      final jsonStr = ValidationExportService.buildAnonymizedJson(verified);
      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      expect(parsed['summary_metrics']['mae'], closeTo(1.0, 1e-6));
      expect(parsed['records'], hasLength(2));
      expect(parsed['records'][0]['phq8_q1_anhedonia'], equals(2));
      expect(jsonStr, isNot(contains('Ahmad Wijaya')));
      expect(jsonStr, isNot(contains('Rahasia assessment SOAP')));
    });
  });

  group('ClinicalVerificationScreen Unbiased Validation Flow Tests', () {
    testWidgets(
      'Starts unprefilled (no Samakan Skor / no default valid) and requires 8 PHQ-8 items + validator identity + concordance',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = _CapturingScreeningRepository();
        final provider = ScreeningProvider(repository: repo);
        final sample = _buildSampleScreening(
          id: 'SCR-VER-01',
          participantId: 'RM-VER-01',
          predPhq8: 14.2,
          riskCat: 'moderate',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ScreeningProvider>.value(
            value: provider,
            child: MaterialApp(
              home: ClinicalVerificationScreen(screening: sample),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tidak ada anchoring bias: tidak ada tombol Samakan Skor, skor ahli belum dinilai, SOAP O/A/P kosong
        expect(find.text('Samakan Skor'), findsNothing);
        expect(find.text('Belum dinilai'), findsOneWidget);
        expect(find.text('0 / 8 butir'), findsOneWidget);
        expect(find.textContaining('Estimasi AI PHQ-8:'), findsNothing);

        // Tombol simpan nonaktif ketika form wajib masih kosong
        final saveBtnFinder = find.widgetWithText(
          ElevatedButton,
          'Simpan Verifikasi ke Rekam Medis',
        );
        expect(saveBtnFinder, findsOneWidget);
        expect(tester.widget<ElevatedButton>(saveBtnFinder).onPressed, isNull);

        // 1. Pilih status kesesuaian AI
        await tester.ensureVisible(find.text('Sesuai / Cocok'));
        await tester.tap(find.text('Sesuai / Cocok'));
        await tester.pump();

        // 2. Isi seluruh 8 butir PHQ-8 masing-masing dengan skor 1 -> total = 8
        final score1Buttons = find.text('1');
        expect(score1Buttons.evaluate().length, equals(8));
        for (int i = 0; i < 8; i++) {
          final target = score1Buttons.at(i);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pump();
        }
        expect(find.text('8 / 24'), findsWidgets);

        // 3. Masih nonaktif sebelum nama validator diisi
        expect(tester.widget<ElevatedButton>(saveBtnFinder).onPressed, isNull);

        // 4. Isi nama validator
        final nameField = find.widgetWithText(TextField, 'Nama Validator *');
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Dr. Rina Sari');
        await tester.pump();

        // Sekarang tombol simpan aktif!
        expect(
          tester.widget<ElevatedButton>(saveBtnFinder).onPressed,
          isNotNull,
        );

        await tester.ensureVisible(saveBtnFinder);
        await tester.tap(saveBtnFinder);
        await tester.pumpAndSettle();

        expect(repo.lastSavedScreeningId, equals('SCR-VER-01'));
        expect(repo.lastSavedVerification, isNotNull);
        expect(repo.lastSavedVerification!.groundTruthPhq8, equals(8.0));
        expect(repo.lastSavedVerification!.concordanceStatus, equals('valid'));
        expect(repo.lastSavedVerification!.validatorName, equals('Dr. Rina Sari'));
        expect(
          repo.lastSavedVerification!.validatorRole,
          equals('Psikolog Klinis'),
        );
        expect(
          repo.lastSavedVerification!.phq8ItemScores?.values
              .reduce((a, b) => a + b),
          equals(8),
        );
      },
    );
  });
}
