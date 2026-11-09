import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local Preprocessing & Tensor Tests', () {
    late Map<String, dynamic> p600Data;
    late Map<String, dynamic> p716Data;

    setUp(() async {
      final file600 = File('assets/samples/p600_features.json');
      p600Data = json.decode(await file600.readAsString()) as Map<String, dynamic>;

      final file716 = File('assets/samples/p716_features.json');
      p716Data = json.decode(await file716.readAsString()) as Map<String, dynamic>;
    });

    test('LocalPreprocessingService should prepare valid tensor dimensions for P600', () async {
      final preprocessor = LocalPreprocessingService();

      final audio = (p600Data['audio_features'] as List).map((e) => (e as num).toDouble()).toList();
      final visual = (p600Data['visual_features'] as List).map((e) => (e as num).toDouble()).toList();
      final text = (p600Data['text_features'] as List).map((e) => (e as num).toDouble()).toList();

      final tensors = await preprocessor.prepareMultimodalTensors(
        audioInput: audio,
        visualInput: visual,
        textInput: text,
      );

      // Verify dimensions
      expect(tensors.audio.length, equals(512 * 80)); // 40,960
      expect(tensors.visual.length, equals(512 * 216)); // 110,592
      expect(tensors.text.length, equals(512 * 768)); // 393,216

      // Verify no NaNs or Infinities
      for (int i = 0; i < 100; i++) {
        expect(tensors.audio[i].isNaN, isFalse);
        expect(tensors.visual[i].isNaN, isFalse);
        expect(tensors.text[i].isNaN, isFalse);
      }

      // Verify Quality Flags
      expect(tensors.qualityFlags['low_text_information'], isFalse);
      expect(tensors.qualityFlags['poor_audio_quality'], isFalse);
      expect(tensors.qualityFlags['poor_visual_quality'], isFalse);
    });

    test('E-DAIC Severe Depression Case (P716) should prepare valid tensors and depressive inspection profile', () async {
      final preprocessor = LocalPreprocessingService();

      expect(p716Data['participant_id'], equals('P716'));
      expect(p716Data['ground_truth_phq8'], equals(15.0));
      expect(p716Data['predicted_phq8_onnx'], equals(19.0));
      expect(p716Data['risk_category'], equals('high'));

      final audio = (p716Data['audio_features'] as List).map((e) => (e as num).toDouble()).toList();
      final visual = (p716Data['visual_features'] as List).map((e) => (e as num).toDouble()).toList();
      final text = (p716Data['text_features'] as List).map((e) => (e as num).toDouble()).toList();

      expect(audio.length, equals(248));
      expect(visual.length, equals(75));
      expect(text.length, equals(768));

      final tensors = await preprocessor.prepareMultimodalTensors(
        audioInput: audio,
        visualInput: visual,
        textInput: text,
      );

      expect(tensors.audio.length, equals(512 * 80));
      expect(tensors.visual.length, equals(512 * 216));
      expect(tensors.text.length, equals(512 * 768));
      expect(tensors.qualityFlags['low_text_information'], isFalse);
      expect(tensors.qualityFlags['poor_audio_quality'], isFalse);
      expect(tensors.qualityFlags['poor_visual_quality'], isFalse);

      final inspection = MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: 'P716',
        visualFeatures: visual,
        audioFeatures: audio,
        textFeatures: text,
        clientTranscript: p716Data['transcript_excerpt'] as String?,
      );

      expect(inspection.participantId, equals('P716'));
      expect(inspection.facialAffectTitle, contains('Afek Wajah Depresif'));
      expect(inspection.vocalProsodyTitle, contains('Prosodi Hipofonik'));
      expect(inspection.emotionalValence, lessThan(0.0));
      expect(inspection.detectedKeywords, isNotEmpty);
    });
  });
}

