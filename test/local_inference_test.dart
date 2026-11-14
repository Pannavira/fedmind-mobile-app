import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
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

    test('LocalInferenceService defaults to Model 3 Edge configuration', () {
      final service = LocalInferenceService();
      expect(service.selectedVariant, equals(FedMindModelVariant.model3Edge));
      expect(service.binaryThreshold, equals(9.1));
      expect(service.latentDim, equals(128));
      expect(service.v000Baseline, closeTo(9.6691, 1e-4));
    });

    test('LocalPreprocessingService prepares Model 3 pooled tensors with Z-clip [-4, 4] and visual disable zeroing', () async {
      final preprocessor = LocalPreprocessingService();

      final audio = (p600Data['audio_features'] as List).map((e) => (e as num).toDouble()).toList();
      final visual = (p600Data['visual_features'] as List).map((e) => (e as num).toDouble()).toList();
      final text = (p600Data['text_features'] as List).map((e) => (e as num).toDouble()).toList();

      final tensors = await preprocessor.prepareMultimodalTensors(
        audioInput: audio,
        visualInput: visual,
        textInput: text,
        variant: FedMindModelVariant.model3Edge,
      );

      expect(tensors.variant, equals(FedMindModelVariant.model3Edge));
      expect(tensors.audioShape, equals([1, 248]));
      expect(tensors.visualShape, equals([1, 75]));
      expect(tensors.textShape, equals([1, 768]));
      expect(tensors.audio.length, equals(248));
      expect(tensors.visual.length, equals(75));
      expect(tensors.text.length, equals(768));

      for (final val in [...tensors.audio, ...tensors.visual, ...tensors.text]) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
        expect(val, inInclusiveRange(-4.0, 4.0));
      }

      final noVisualTensors = await preprocessor.prepareMultimodalTensors(
        audioInput: audio,
        visualInput: visual,
        textInput: text,
        disableVisualBranch: true,
        variant: FedMindModelVariant.model3Edge,
      );

      expect(noVisualTensors.visual.length, equals(75));
      expect(noVisualTensors.visual.every((v) => v == 0.0), isTrue);
      expect(noVisualTensors.qualityFlags['poor_visual_quality'], isTrue);
    });

    test('LocalPreprocessingService calibrates high-RMS short utterances using short_mean and preserves E-DAIC RMS', () async {
      final preprocessor = LocalPreprocessingService(
        defaultVariant: FedMindModelVariant.model3Edge,
      );
      await preprocessor.initialize(FedMindModelVariant.model3Edge);

      // E-DAIC text vector (rms <= 2.5) must use standard zero-leakage normalization
      final p716Text = (p716Data['text_features'] as List).map((e) => (e as num).toDouble()).toList();
      final p716Tensors = await preprocessor.prepareMultimodalTensors(
        audioInput: List<double>.filled(248, 0.0),
        visualInput: List<double>.filled(75, 0.0),
        textInput: p716Text,
        variant: FedMindModelVariant.model3Edge,
      );
      expect(p716Tensors.text.length, equals(768));

      // Synthetic short utterance far from E-DAIC mean (rms > 2.5) centered around short_mean
      final normJson = json.decode(
        await File('assets/models/train_norm_stats_edge.json').readAsString(),
      ) as Map<String, dynamic>;
      final textStats = normJson['text'] as Map<String, dynamic>;
      final shortMean = (textStats['short_mean'] as List).map((e) => (e as num).toDouble()).toList();
      final normShortMean = preprocessor.normalizeFeature(
        shortMean,
        'text',
        variant: FedMindModelVariant.model3Edge,
      );

      // Exact short_mean has raw RMS > 2.5 relative to E-DAIC mean, so calibrated Z should become near 0
      final maxAbsCalibrated = normShortMean.fold<double>(
        0.0,
        (prev, v) => v.abs() > prev ? v.abs() : prev,
      );
      expect(maxAbsCalibrated, lessThan(1e-4));
    });
  });
}

