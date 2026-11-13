import 'dart:ui';

import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/core/services/realtime_face_detector_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimeFaceDetectorService.evaluateBoundingBoxes', () {
    const frameSize = Size(480, 640);

    test('mengembalikan noFace saat tidak ada wajah di frame kamera', () {
      final eval = RealtimeFaceDetectorService.evaluateBoundingBoxes(
        boundingBoxes: const [],
        rotatedImageSize: frameSize,
        isFrontCamera: false,
      );

      expect(eval.status, RealtimeFaceStatus.noFace);
      expect(eval.isFacePresent, isFalse);
      expect(eval.faceCount, 0);
      expect(eval.normalizedBox, isNull);
    });

    test('mengembalikan detected saat wajah berada di tengah zona FACS', () {
      final eval = RealtimeFaceDetectorService.evaluateBoundingBoxes(
        boundingBoxes: const [Rect.fromLTWH(140, 180, 200, 260)],
        rotatedImageSize: frameSize,
        isFrontCamera: false,
      );

      expect(eval.status, RealtimeFaceStatus.detected);
      expect(eval.isFacePresent, isTrue);
      expect(eval.faceCount, 1);
      expect(eval.normalizedBox, isNotNull);
    });

    test('mengembalikan outOfZone saat wajah terlalu jauh/kecil', () {
      final eval = RealtimeFaceDetectorService.evaluateBoundingBoxes(
        boundingBoxes: const [Rect.fromLTWH(200, 280, 60, 70)],
        rotatedImageSize: frameSize,
        isFrontCamera: true,
      );

      expect(eval.status, RealtimeFaceStatus.outOfZone);
      expect(eval.isFacePresent, isTrue);
    });

    test('mengembalikan outOfZone saat wajah keluar dari area tengah (termasuk mirror kamera depan)', () {
      final eval = RealtimeFaceDetectorService.evaluateBoundingBoxes(
        boundingBoxes: const [Rect.fromLTWH(10, 180, 120, 200)],
        rotatedImageSize: frameSize,
        isFrontCamera: true,
      );

      expect(eval.status, RealtimeFaceStatus.outOfZone);
      expect(eval.isFacePresent, isTrue);
      expect(eval.normalizedBox!.center.dx, greaterThan(0.78));
    });

    test('memilih wajah dengan area terbesar jika ada lebih dari satu wajah', () {
      final eval = RealtimeFaceDetectorService.evaluateBoundingBoxes(
        boundingBoxes: const [
          Rect.fromLTWH(5, 10, 40, 50),
          Rect.fromLTWH(150, 190, 180, 240),
        ],
        rotatedImageSize: frameSize,
        isFrontCamera: false,
      );

      expect(eval.status, RealtimeFaceStatus.detected);
      expect(eval.faceCount, 2);
    });
  });

  group('MultimodalExtractorService.validateVisualFacePresence', () {
    test('melempar FaceNotDetectedException jika 0 wajah terdeteksi', () {
      expect(
        () => MultimodalExtractorService.validateVisualFacePresence(
          facesDetectedCount: 0,
          framesAnalyzed: 16,
        ),
        throwsA(isA<FaceNotDetectedException>()),
      );
    });

    test('melempar FaceNotDetectedException jika rasio deteksi di bawah ambang 20%', () {
      expect(
        () => MultimodalExtractorService.validateVisualFacePresence(
          facesDetectedCount: 2,
          framesAnalyzed: 16,
          minFaceDetectionRate: 0.20,
        ),
        throwsA(isA<FaceNotDetectedException>()),
      );
    });

    test('lolos validasi jika wajah terdeteksi memenuhi ambang minimal', () {
      expect(
        () => MultimodalExtractorService.validateVisualFacePresence(
          facesDetectedCount: 4,
          framesAnalyzed: 16,
          minFaceDetectionRate: 0.20,
        ),
        returnsNormally,
      );
    });
  });
}

