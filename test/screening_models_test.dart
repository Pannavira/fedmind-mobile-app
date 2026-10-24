import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';

void main() {
  group('Screening Models JSON Serialization Tests', () {
    test('Should correctly parse complete ScreeningResponse from backend JSON', () {
      final jsonMap = {
        'screening_id': 'test-session-123',
        'participant_id': 'P600',
        'status': 'completed',
        'prediction': {
          'phq8_score': 9.69,
          'risk_probability_proxy': 0.473,
          'binary_prediction': 'non_depression',
          'risk_category': 'borderline',
        },
        'patient_modality_attribution': {
          'text_pct': 39.1,
          'visual_pct': 56.8,
          'audio_pct': 4.1,
          'dominant_modality': 'visual',
          'shap_values': {
            'text': -0.45,
            'visual': 1.25,
            'audio': 0.12,
          },
        },
        'global_reference': {
          'cohort': 'E-DAIC Test Set (N=56)',
          'text_pct': 61.8,
          'visual_pct': 33.8,
          'audio_pct': 4.4,
          'dominant_modality': 'text',
        },
        'quality_flags': {
          'low_text_information': false,
          'poor_audio_quality': false,
          'poor_visual_quality': false,
          'details': null,
        },
        'clinical_narrative': 'Estimasi PHQ-8 sebesar 9.69 mengindikasikan risiko borderline.',
        'model': {
          'model_id': 'centralized',
          'name': 'Baseline Multimodal Depression',
          'version': '1.0.0',
          'architecture': 'Late-Fusion Attention',
          'checkpoint': 'storage/models/centralized/model.pt',
          'checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'xai_baseline': 'storage/models/centralized/xai_baseline.pt',
          'device': 'cuda',
        },
        'xai': {
          'method': 'exact_modality_shapley_coalition',
          'num_coalitions': 8,
          'efficiency_axiom_verified': true,
          'baseline_expected_value': 8.77,
        },
        'disclaimer': 'Bukan diagnosis klinis final.',
        'created_at': '2026-10-24T18:00:00Z',
        'completed_at': '2026-10-24T18:00:01Z',
      };

      final response = ScreeningResponse.fromJson(jsonMap);

      expect(response.screeningId, equals('test-session-123'));
      expect(response.participantId, equals('P600'));
      expect(response.prediction?.phq8Score, equals(9.69));
      expect(response.prediction?.riskCategory, equals('borderline'));
      expect(response.patientModalityAttribution?.dominantModality, equals('visual'));
      expect(response.patientModalityAttribution?.visualPct, equals(56.8));
      expect(response.patientModalityAttribution?.shapValues.visual, equals(1.25));
      expect(response.xai?.numCoalitions, equals(8));
      expect(response.xai?.efficiencyAxiomVerified, isTrue);
    });

    test('Should serialize ScreeningCreateRequest properly', () {
      final req = ScreeningCreateRequest(
        participantId: 'P600',
        metadata: {'tester': 'flutter_unit_test'},
      );
      final json = req.toJson();
      expect(json['participant_id'], equals('P600'));
      expect(json['metadata']['tester'], equals('flutter_unit_test'));
    });
  });
}
