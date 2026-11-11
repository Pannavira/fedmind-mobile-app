import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
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
        expect(ins.translatedTranscript.isNotEmpty, isTrue);
        expect(ins.transcriptLanguage, equals('id'));
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
      'Different user stories/notes (including short <4 word notes and negations) must produce distinct 768D Psycholinguistic Text features',
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

        final featShortDistress =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              userNote: 'sedih lelah cemas',
            );

        final featShortPositive =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              userNote: 'tenang semangat bahagia',
            );

        double textDiff = 0.0;
        double shortNoteDiff = 0.0;
        for (int i = 0; i < 768; i++) {
          textDiff +=
              (featDistress.textFeatures[i] - featPositive.textFeatures[i])
                  .abs();
          shortNoteDiff +=
              (featShortDistress.textFeatures[i] -
                      featShortPositive.textFeatures[i])
                  .abs();
        }

        expect(textDiff, greaterThan(5.0));
        expect(shortNoteDiff, greaterThan(5.0));
        expect(
          featDistress.inspectionData.emotionalValence,
          lessThan(featPositive.inspectionData.emotionalValence),
        );
      },
    );

    test(
      'Different videos without manual notes must produce distinct preprocessed tensors across all 3 modalities',
      () async {
        final featA = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_VID_A',
        );
        final featB = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileB.path,
          participantId: 'P_VID_B',
        );

        final preprocessor = LocalPreprocessingService();
        final tensorsA = await preprocessor.prepareMultimodalTensors(
          audioInput: featA.audioFeatures,
          visualInput: featA.visualFeatures,
          textInput: featA.textFeatures,
        );
        final tensorsB = await preprocessor.prepareMultimodalTensors(
          audioInput: featB.audioFeatures,
          visualInput: featB.visualFeatures,
          textInput: featB.textFeatures,
        );

        double audioTensorDiff = 0.0;
        for (int i = 0; i < 80; i++) {
          audioTensorDiff += (tensorsA.audio[i] - tensorsB.audio[i]).abs();
        }
        double visualTensorDiff = 0.0;
        for (int i = 0; i < 216; i++) {
          visualTensorDiff += (tensorsA.visual[i] - tensorsB.visual[i]).abs();
        }
        double textTensorDiff = 0.0;
        for (int i = 0; i < 768; i++) {
          textTensorDiff += (tensorsA.text[i] - tensorsB.text[i]).abs();
        }

        expect(audioTensorDiff, greaterThan(0.5));
        expect(visualTensorDiff, greaterThan(0.5));
        expect(textTensorDiff, greaterThan(0.5));
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

        if (await realVideoFile.exists()) {
          // Pastikan parser header MP4 (mvhd) membaca durasi asli video (~47.6 detik), bukan 4.0 detik!
          expect(extracted.inspectionData.videoDurationSec, closeTo(47.6, 1.0));
          expect(
            extracted.inspectionData.transcriptSegments.last.timeRangeLabel,
            contains('00:48'),
          );
          expect(extracted.inspectionData.isWhisperTranscribed, isTrue);
          expect(extracted.inspectionData.translatedTranscript.isNotEmpty, isTrue);
        }
      },
    );

    test(
      'Different videos produce distinct UI Inspection Metrics (Waktu Bicara, Waktu Jeda, Kestabilan Vokal, Nada Dasar, Timestamps, & Transkrip)',
      () async {
        const channel = MethodChannel('com.fedmind.edge/multimodal_extractor');
        final binding =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        // Simulasikan 2 video berbeda pada MethodChannel (sebagaimana diekstrak dari MediaExtractor/MediaMetadataRetriever)
        binding.setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method != 'extractVideoMultimodal') return null;
          final args = call.arguments as Map<dynamic, dynamic>;
          final path = args['videoPath'] as String;
          final isVideoA = path.endsWith('_a.mp4');

          final frames = List<Map<String, double>>.generate(12, (i) {
            if (isVideoA) {
              // Video A (durasi 36 detik): ekspresif, senyum aktif, kontak mata stabil
              return {
                'timeSec': i * 3.0,
                'faceFound': 1.0,
                'confidence': 0.95,
                'bboxLeft': 0.24,
                'bboxTop': 0.16,
                'bboxRight': 0.76,
                'bboxBottom': 0.82,
                'eulerX': -1.5,
                'eulerY': 1.2,
                'eulerZ': 0.4,
                'browActivation': 0.30 + 0.04 * sin(i * 0.6),
                'eyeOpenness': 0.48 + 0.05 * cos(i * 0.5),
                'cheekActivation': 0.46 + 0.06 * sin(i * 0.7),
                'mouthActivation': 0.58 + 0.12 * sin(i * 0.8),
                'mouthOpenness': 0.42 + 0.10 * cos(i * 0.9),
                'asymmetry': 0.03,
                'motionEnergy': 0.42 + 0.08 * sin(i * 0.5),
              };
            } else {
              // Video B (durasi 24 detik): dahi tegang, kepala menunduk, afek datar
              return {
                'timeSec': i * 2.0,
                'faceFound': i % 4 == 0 ? 0.0 : 1.0,
                'confidence': i % 4 == 0 ? 0.35 : 0.88,
                'bboxLeft': 0.26,
                'bboxTop': 0.22,
                'bboxRight': 0.74,
                'bboxBottom': 0.86,
                'eulerX': -10.5,
                'eulerY': -4.5,
                'eulerZ': 1.8,
                'browActivation': 0.56 + 0.02 * sin(i * 0.3),
                'eyeOpenness': 0.28 + 0.01 * cos(i * 0.3),
                'cheekActivation': 0.24 + 0.01 * sin(i * 0.2),
                'mouthActivation': 0.25 + 0.01 * cos(i * 0.2),
                'mouthOpenness': 0.20 + 0.01 * sin(i * 0.2),
                'asymmetry': 0.11,
                'motionEnergy': 0.11 + 0.01 * cos(i * 0.2),
              };
            }
          });

          const int sr = 8000;
          const int nSamples = 32768;
          final pcm = List<double>.filled(nSamples, 0.0);
          double phaseA = 0.0;
          double phaseB = 0.0;
          for (int n = 0; n < nSamples; n++) {
            final sec = n / sr;
            if (isVideoA) {
              // Video A: suara pria stabil ~115 Hz, bicara aktif ~82% waktu (jeda pendek)
              final isSpeaking = (sec % 1.0) < 0.82;
              final f0 = 115.0 + 2.5 * sin(2 * pi * 1.2 * sec);
              phaseA += (2 * pi * f0) / sr;
              if (isSpeaking) {
                pcm[n] = 0.22 *
                    (sin(phaseA) +
                        0.45 * sin(2 * phaseA) +
                        0.20 * sin(3 * phaseA));
              } else {
                pcm[n] = 0.008 * sin(n * 1.7);
              }
            } else {
              // Video B: suara lebih tinggi ~185 Hz dengan tremor/jitter tinggi, bicara ~38% waktu (jeda panjang 62%)
              final isSpeaking = (sec % 1.2) < 0.45;
              final tremor =
                  1.0 + 0.08 * sin(2 * pi * 12.5 * sec) + 0.05 * cos(n * 0.19);
              final f0 = 185.0 * tremor;
              phaseB += (2 * pi * f0) / sr;
              if (isSpeaking) {
                pcm[n] = 0.09 *
                    (sin(phaseB) +
                        0.35 * sin(2 * phaseB) +
                        0.15 * sin(3 * phaseB));
              } else {
                pcm[n] = 0.007 * cos(n * 2.1);
              }
            }
          }

          return {
            'visual': {
              'frames': frames,
              'facesDetectedCount': isVideoA ? 12 : 9,
              'totalSampled': 12,
              'durationMs': isVideoA ? 36000 : 24000,
            },
            'audio': {
              'pcmSamples': pcm,
              'sampleRate': sr,
            },
          };
        });

        try {
          final featA = await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileA.path,
            participantId: 'VID_COMPARE_A',
          );
          final featB = await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileB.path,
            participantId: 'VID_COMPARE_B',
          );

          final insA = featA.inspectionData;
          final insB = featB.inspectionData;

          // 1. Durasi video & rentang waktu segmen harus berbeda sesuai metadata video
          expect(insA.videoDurationSec, equals(36.0));
          expect(insB.videoDurationSec, equals(24.0));
          expect(
            insA.transcriptSegments.first.timeRangeLabel,
            isNot(equals(insB.transcriptSegments.first.timeRangeLabel)),
          );

          // 2. Waktu Bicara (%) dan Waktu Jeda (%) harus berbeda signifikan (bukan 58% / 42% statis)
          expect(insA.voicedRatioPct, greaterThan(70.0));
          expect(insB.voicedRatioPct, lessThan(50.0));
          expect(insA.pauseRatioPct, lessThan(30.0));
          expect(insB.pauseRatioPct, greaterThan(50.0));

          // 3. Nada dasar (avgPitchHz) harus mencerminkan F0 sebenarnya (~115 Hz vs ~185 Hz), bukan konvergen ke 143 Hz
          expect(insA.avgPitchHz, lessThan(132.0));
          expect(insB.avgPitchHz, greaterThan(165.0));

          // 4. Kestabilan Vokal (jitterPct <= 2.0 Stabil vs > 2.0 Fluktuatif) harus berbeda
          expect(insA.jitterPct, lessThan(2.0)); // Stabil
          expect(insB.jitterPct, greaterThan(2.0)); // Fluktuatif

          // 5. Transkrip observasi, prosodyNote setiap segmen, dan kata kunci harus berbeda
          expect(insA.fullTranscript, isNot(equals(insB.fullTranscript)));
          expect(insA.isExplicitTranscript, isFalse);
          expect(insB.isExplicitTranscript, isFalse);
          expect(
            insA.transcriptSegments[0].text,
            isNot(equals(insB.transcriptSegments[0].text)),
          );
          expect(
            insA.transcriptSegments[1].text,
            isNot(equals(insB.transcriptSegments[1].text)),
          );
          expect(
            insA.transcriptSegments[2].text,
            isNot(equals(insB.transcriptSegments[2].text)),
          );
          expect(
            insA.transcriptSegments[0].prosodyNote,
            isNot(equals(insB.transcriptSegments[0].prosodyNote)),
          );
          expect(
            insA.transcriptSegments[1].prosodyNote,
            isNot(equals(insB.transcriptSegments[1].prosodyNote)),
          );
          expect(
            insA.transcriptSegments[2].prosodyNote,
            isNot(equals(insB.transcriptSegments[2].prosodyNote)),
          );
        } finally {
          binding.setMockMethodCallHandler(channel, null);
        }
      },
    );

    test(
      'Explicit clientTranscript must set isExplicitTranscript=true and use verbatim text in transcript segments',
      () async {
        const customTranscript =
            'Saya merasa sangat lelah dan tidak bertenaga sejak dua minggu lalu.';
        final feat = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_EXPLICIT',
          clientTranscript: customTranscript,
        );

        final ins = feat.inspectionData;
        expect(ins.isExplicitTranscript, isTrue);
        expect(ins.fullTranscript, equals(customTranscript));
        expect(ins.transcriptSegments.first.text, equals(customTranscript));
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
