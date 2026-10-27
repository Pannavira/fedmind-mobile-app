import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('On-Device Multimodal Extractor Tests', () {
    late File tempFile;

    setUp(() async {
      tempFile = File('${Directory.systemTemp.path}/test_clinical_recording.mp4');
      await tempFile.writeAsBytes(List.filled(1024, 42)); // dummy dummy mp4
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('Should extract valid 75 Visual, 248 Audio, and 768 Text features', () async {
      final progressUpdates = <String>[];

      final features = await MultimodalExtractorService.extractFromLocalVideo(
        videoPath: tempFile.path,
        participantId: 'P_TEST_99',
        onProgress: (stage, progress) {
          progressUpdates.add(stage);
        },
      );

      expect(features.participantId, equals('P_TEST_99'));
      expect(features.videoPath, equals(tempFile.path));
      expect(features.visualFeatures.length, equals(75));
      expect(features.audioFeatures.length, equals(248));
      expect(features.textFeatures.length, equals(768));

      // Verifikasi tidak ada NaN atau Infinity
      for (final val in features.visualFeatures) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
      }
      for (final val in features.audioFeatures) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
      }
      for (final val in features.textFeatures) {
        expect(val.isNaN, isFalse);
        expect(val.isInfinite, isFalse);
      }

      expect(progressUpdates.isNotEmpty, isTrue);
      expect(features.toMetadataMap().containsKey('feature_dims'), isTrue);
    });

    test('Should throw exception if file does not exist', () async {
      expect(
        () => MultimodalExtractorService.extractFromLocalVideo(
          videoPath: '/path/non/existent/video.mp4',
          participantId: 'P_ERR',
        ),
        throwsA(isA<String>()),
      );
    });
  });
}
