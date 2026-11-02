import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local Preprocessing & Tensor Tests', () {
    late Map<String, dynamic> p600Data;

    setUp(() async {
      final file = File('assets/samples/p600_features.json');
      final content = await file.readAsString();
      p600Data = json.decode(content) as Map<String, dynamic>;
    });

    test('LocalPreprocessingService should prepare valid tensor dimensions', () async {
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
  });
}

