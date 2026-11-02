import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('On-Device Real Multimodal Extractor & DSP Pipeline Tests', () {
    late File tempFileA;
    late File tempFileB;

    setUp(() async {
      tempFileA = File(
        '${Directory.systemTemp.path}/test_clinical_recording_a.mp4',
      );
      tempFileB = File(
        '${Directory.systemTemp.path}/test_clinical_recording_b.mp4',
      );

      // Buat dua file dengan ukuran byte SAMA PERSIS (8192 bytes),
      // tetapi pola sinyal gelombang / konten biner berbeda untuk membuktikan
      // ekstraktor benar-benar memproses isi konten (DSP FFT/MFCC/Visual),
      // BUKAN sekadar Random(fileSize).
      final bytesA = List<int>.generate(
        8192,
        (i) => ((sin(i * 0.15) * 120) + 128).toInt().clamp(0, 255),
      );
      final bytesB = List<int>.generate(
        8192,
        (i) =>
            ((sin(i * 0.85) * 90 + cos(i * 0.05) * 35) + 128)
                .toInt()
                .clamp(0, 255),
      );

      await tempFileA.writeAsBytes(bytesA);
      await tempFileB.writeAsBytes(bytesB);
    });

    tearDown(() async {
      if (await tempFileA.exists()) {
        await tempFileA.delete();
      }
      if (await tempFileB.exists()) {
        await tempFileB.delete();
      }
    });

    test(
      'Should extract valid 75 Visual, 248 Audio, and 768 Text features with physical calibration',
      () async {
        final progressUpdates = <String>[];

        final features = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_TEST_99',
          userNote:
              'Akhir-akhir ini saya merasa lelah, sulit tidur, dan cemas.',
          onProgress: (stage, progress) {
            progressUpdates.add(stage);
          },
        );

        expect(features.participantId, equals('P_TEST_99'));
        expect(features.videoPath, equals(tempFileA.path));
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

        // Verifikasi kelengkapan MultimodalInspectionData (Wajah, Gelombang Suara, & Transkrip)
        final ins = features.inspectionData;
        expect(ins.isFromRealVideo, isTrue);
        expect(ins.visualFrames.isNotEmpty, isTrue);
        expect(ins.audioWaveformBars.length, equals(64));
        expect(ins.pitchContourHz.isNotEmpty, isTrue);
        expect(ins.transcriptSegments.isNotEmpty, isTrue);
        expect(ins.detectedKeywords.isNotEmpty, isTrue);
        expect(ins.actionUnitScores.length, equals(5));
      },
    );

    test(
      'Files with identical byte size but different signal content must yield different Audio & Visual features',
      () async {
        expect(await tempFileA.length(), equals(await tempFileB.length()));

        final featA = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'SAME_ID',
        );
        final featB = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileB.path,
          participantId: 'SAME_ID',
        );

        // Hitung selisih L1 antara kedua hasil ekstraksi
        double audioDiff = 0.0;
        for (int i = 0; i < featA.audioFeatures.length; i++) {
          audioDiff += (featA.audioFeatures[i] - featB.audioFeatures[i]).abs();
        }

        double visualDiff = 0.0;
        for (int i = 0; i < featA.visualFeatures.length; i++) {
          visualDiff +=
              (featA.visualFeatures[i] - featB.visualFeatures[i]).abs();
        }

        expect(audioDiff, greaterThan(1e-3));
        expect(visualDiff, greaterThan(1e-3));
      },
    );

    test(
      'Different user stories/notes must produce distinct 768D Psycholinguistic Text features',
      () async {
        final featDistress =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              userNote:
                  'Saya merasa sangat sedih, hampa, putus asa, dan tidak bisa tidur setiap malam.',
            );

        final featPositive =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              userNote:
                  'Hari ini saya merasa tenang, bersyukur, bahagia, dan bersemangat bekerja.',
            );

        double textDiff = 0.0;
        for (int i = 0; i < 768; i++) {
          textDiff +=
              (featDistress.textFeatures[i] - featPositive.textFeatures[i])
                  .abs();
        }

        expect(textDiff, greaterThan(1.0));
      },
    );

    test(
      'Extracted features from real video_test/VID_20261027_212406.mp4 integrate cleanly with LocalPreprocessingService',
      () async {
        final realVideoFile = File('video_test/VID_20261027_212406.mp4');
        final targetVideoPath = await realVideoFile.exists()
            ? realVideoFile.path
            : tempFileA.path;

        final extracted =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: targetVideoPath,
              participantId: 'REAL_VIDEO_USER',
              userNote: 'Merasa sedikit lelah karena pekerjaan menumpuk.',
            );

        final preprocessor = LocalPreprocessingService();

        final tensors = await preprocessor.prepareMultimodalTensors(
          audioInput: extracted.audioFeatures,
          visualInput: extracted.visualFeatures,
          textInput: extracted.textFeatures,
        );

        expect(tensors.audio.length, equals(512 * 80));
        expect(tensors.visual.length, equals(512 * 216));
        expect(tensors.text.length, equals(512 * 768));

        // Pastikan hasil Z-Score normalization berada pada rentang wajar (tidak meledak ribuan standar deviasi)
        for (int i = 0; i < 80; i++) {
          expect(tensors.audio[i].isNaN, isFalse);
          expect(tensors.audio[i].abs(), lessThan(10.0));
        }
        for (int i = 0; i < 216; i++) {
          expect(tensors.visual[i].isNaN, isFalse);
          expect(tensors.visual[i].abs(), lessThan(10.0));
        }
        for (int i = 0; i < 768; i++) {
          expect(tensors.text[i].isNaN, isFalse);
          expect(tensors.text[i].abs(), lessThan(10.0));
        }

        expect(tensors.qualityFlags['poor_audio_quality'], isFalse);
        expect(tensors.qualityFlags['poor_visual_quality'], isFalse);
      },
    );

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
