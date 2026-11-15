import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';
import 'package:fedmind_mobile_app/core/services/on_device_whisper_service.dart';

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
          clientTranscript:
              'Akhir-akhir ini saya merasa lelah, sulit tidur, dan cemas.',
          allowSyntheticByteFallback: true,
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
        expect(ins.isExplicitTranscript, isTrue);
        expect(ins.transcriptSegments.first.text.isNotEmpty, isTrue);
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
          allowSyntheticByteFallback: true,
        );
        final featB = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileB.path,
          participantId: 'SAME_ID',
          allowSyntheticByteFallback: true,
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
      'Different client transcripts (including short <4 word notes and negations) must produce distinct 768D Psycholinguistic Text features',
      () async {
        final featDistress =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              clientTranscript:
                  'Saya merasa sangat sedih, hampa, putus asa, dan tidak bisa tidur setiap malam.',
              allowSyntheticByteFallback: true,
            );

        final featPositive =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              clientTranscript:
                  'Hari ini saya merasa tenang, bersyukur, bahagia, dan bersemangat bekerja.',
              allowSyntheticByteFallback: true,
            );

        final featShortDistress =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              clientTranscript: 'sedih lelah cemas',
              allowSyntheticByteFallback: true,
            );

        final featShortPositive =
            await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: tempFileA.path,
              participantId: 'P_NOTE',
              clientTranscript: 'tenang semangat bahagia',
              allowSyntheticByteFallback: true,
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
      'Counselor pre-screening note (userNote) must NOT be injected as client speech when transcript is empty',
      () async {
        final noSpeech = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_NO_SPEECH',
          userNote: 'Pasien tampak sangat tertekan, sedih, dan sulit tidur.',
          allowSyntheticByteFallback: true,
        );

        expect(noSpeech.inspectionData.isExplicitTranscript, isFalse);
        expect(noSpeech.inspectionData.translatedTranscript.trim(), isEmpty);
      },
    );

    test(
      'Different videos without manual notes must produce distinct preprocessed tensors across all 3 modalities',
      () async {
        final featA = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_VID_A',
          allowSyntheticByteFallback: true,
        );
        final featB = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileB.path,
          participantId: 'P_VID_B',
          allowSyntheticByteFallback: true,
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
        for (int i = 0; i < 248; i++) {
          audioTensorDiff += (tensorsA.audio[i] - tensorsB.audio[i]).abs();
        }
        double visualTensorDiff = 0.0;
        for (int i = 0; i < 75; i++) {
          visualTensorDiff += (tensorsA.visual[i] - tensorsB.visual[i]).abs();
        }
        double textTensorDiff = 0.0;
        for (int i = 0; i < 768; i++) {
          textTensorDiff += (tensorsA.text[i] - tensorsB.text[i]).abs();
        }

        expect(audioTensorDiff, greaterThan(0.5));
        expect(visualTensorDiff, greaterThan(0.5));
        expect(textTensorDiff, greaterThan(0.01));
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
              clientTranscript: 'Merasa sedikit lelah karena pekerjaan menumpuk.',
              allowSyntheticByteFallback: true,
            );

        final preprocessor = LocalPreprocessingService();

        final tensors = await preprocessor.prepareMultimodalTensors(
          audioInput: extracted.audioFeatures,
          visualInput: extracted.visualFeatures,
          textInput: extracted.textFeatures,
        );

        expect(tensors.audio.length, equals(248));
        expect(tensors.visual.length, equals(75));
        expect(tensors.text.length, equals(768));

        // Pastikan hasil Z-Score normalization berada pada rentang wajar (tidak meledak ribuan standar deviasi)
        for (int i = 0; i < 248; i++) {
          expect(tensors.audio[i].isNaN, isFalse);
          expect(tensors.audio[i].abs(), lessThan(10.0));
        }
        for (int i = 0; i < 75; i++) {
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
          expect(extracted.inspectionData.isExplicitTranscript, isTrue);
          expect(
            extracted.inspectionData.transcriptSegments.first.text.isNotEmpty,
            isTrue,
          );
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
          allowSyntheticByteFallback: true,
        );

        final ins = feat.inspectionData;
        expect(ins.isExplicitTranscript, isTrue);
        expect(ins.fullTranscript, equals(customTranscript));
        expect(ins.transcriptSegments.first.text, equals(customTranscript));
      },
    );

    test(
      'Without a live transcript, the result must be empty (no synthesized fallback text)',
      () async {
        final samples = List<double>.generate(
          16000,
          (i) => 0.003 * sin(i / 18.0),
        );

        final result = await OnDeviceWhisperService.transcribeAndTranslate(
          videoPath: tempFileA.path,
          pcmSamples: samples,
          sourceSampleRate: 16000,
          durationSec: 10.0,
          audioSummary: {
            'rmsMean': 0.0025,
            'pitchMean': 145.0,
            'pauseRatio': 0.30,
          },
        );

        expect(result.isSuccess, isFalse);
        expect(result.isWhisperModel, isFalse);
        expect(result.indonesianTranscript, isEmpty);
        expect(result.segments, isEmpty);
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

    test(
      'OnDeviceWhisperService detects English and rejects counselorNote as client speech fallback',
      () async {
        expect(
          OnDeviceWhisperService.isLikelyEnglishText(
            'I have been feeling okay lately and sleeping well every night.',
          ),
          isTrue,
        );
        expect(
          OnDeviceWhisperService.isLikelyEnglishText(
            'Saya merasa baik-baik saja dan tidak ada yang membuat saya sedih.',
          ),
          isFalse,
        );

        final samples = List<double>.generate(
          16000,
          (i) => 0.02 * sin(2 * pi * 140 * i / 16000),
        );

        // 1) counselorNote must NOT populate client transcript when speech recognition has no text
        final noFallback = await OnDeviceWhisperService.transcribeAndTranslate(
          videoPath: tempFileA.path,
          pcmSamples: samples,
          sourceSampleRate: 16000,
          durationSec: 5.0,
          counselorNote:
              'Nothing has made me feel sad today and I slept quite well.',
        );
        expect(noFallback.isSuccess, isFalse);
        expect(noFallback.indonesianTranscript, isEmpty);
        expect(noFallback.segments, isEmpty);
      },
    );

    test(
      'Visual 75D & Audio 248D match training schema & healthy z-scores against train_norm_stats_edge.json',
      () async {
        final feat = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_PARITY_01',
          allowSyntheticByteFallback: true,
        );

        expect(feat.visualFeatures.length, equals(75));
        expect(feat.audioFeatures.length, equals(248));

        // Visual fraction columns must stay within [0, 1]
        for (int au = 0; au < 16; au++) {
          final fracGt1 = feat.visualFeatures[au * 4 + 3];
          expect(fracGt1, inInclusiveRange(0.0, 1.0));
        }
        expect(feat.visualFeatures[64], inInclusiveRange(0.0, 1.0)); // Duchenne
        expect(feat.visualFeatures[68], inInclusiveRange(0.0, 1.0)); // Gaze < -0.1 rad

        // Verify z-scores against train_norm_stats_edge.json
        final statsMap = json.decode(
          await File('assets/models/train_norm_stats_edge.json').readAsString(),
        ) as Map<String, dynamic>;
        final visMean = (statsMap['visual']['mean'] as List).cast<num>();
        final visStd = (statsMap['visual']['std'] as List).cast<num>();

        // Index 6 (p75 of AU02_r) previously spiked to +23.8 sigma; now must be well bounded
        final zIdx6 = (feat.visualFeatures[6] - visMean[6].toDouble()) /
            (visStd[6].toDouble() + 1e-7);
        expect(zIdx6.abs(), lessThan(8.0));

        // Audio[12] is OpenSMILE c0 log-energy mean (training mean ~75.96) -> must be strongly positive
        expect(feat.audioFeatures[12], greaterThan(20.0));
      },
    );

    test(
      'Phase 1 Parity: poseRx negation, actual dtMs for diff pose, calibrated AU02/AU09, 75D-derived UI AUs, and non-Android block',
      () async {
        final statsMap = json.decode(
          await File('assets/models/train_norm_stats_edge.json').readAsString(),
        ) as Map<String, dynamic>;
        final visMean = (statsMap['visual']['mean'] as List).cast<num>();
        final visStd = (statsMap['visual']['std'] as List).cast<num>();

        // 1. Negated eulerX -> poseRx positive when looking down (menunduk)
        final lookingDownFrames = List<Map<String, double>>.generate(12, (i) => {
              'faceFound': 1.0,
              'timeSec': i * 1.0,
              'eulerX': -12.0, // menunduk in ML Kit
              'eulerY': (i.isEven ? 2.0 : -2.0),
              'eulerZ': 0.5,
              'browActivation': 1.05,
              'eyeOpenness': 0.90,
              'cheekActivation': 1.05,
              'mouthActivation': 0.90,
              'mouthOpenness': 0.55,
              'asymmetry': 0.08,
              'motionEnergy': 0.25,
            });
        final featDown =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          lookingDownFrames,
        );
        // pose_Rx (idx 69) must be positive (~ +0.209 rad) matching E-DAIC convention
        expect(featDown[69], greaterThan(0.15));

        // 2. Actual dtMs from timeSec / timestampMs affects features 73-74
        final slowFrames = List<Map<String, double>>.generate(10, (i) => {
              'faceFound': 1.0,
              'timeSec': i * 2.0, // dtMs = 2000 -> stepScale = 0.08
              'eulerX': (i.isEven ? -4.0 : -10.0),
              'eulerY': (i.isEven ? -3.0 : 3.0),
              'eulerZ': 0.0,
              'browActivation': 0.95,
              'eyeOpenness': 0.95,
              'cheekActivation': 0.95,
              'mouthActivation': 0.95,
              'mouthOpenness': 0.5,
              'asymmetry': 0.05,
              'motionEnergy': 0.3,
            });
        final fastFrames = List<Map<String, double>>.generate(10, (i) => {
              ...slowFrames[i],
              'timestampMs': i * 60.0, // dtMs = 60 -> stepScale = 33.333/60 = 0.555
            });
        final featSlow =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          slowFrames,
        );
        final featFast =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          fastFrames,
        );
        expect(featFast[73], greaterThan(featSlow[73]));
        expect(featFast[74], greaterThan(featSlow[74]));

        // 3. AU02 & AU09 calibrated for neutral & expressive faces (< +10 sigma)
        final expressiveFrames = List<Map<String, double>>.generate(12, (i) => {
              'faceFound': 1.0,
              'timeSec': i * 0.8,
              'eulerX': -2.0,
              'eulerY': 1.0,
              'eulerZ': 0.5,
              'browActivation': 1.45,
              'eyeOpenness': 1.05,
              'cheekActivation': 1.45,
              'mouthActivation': 1.35,
              'mouthOpenness': 0.75,
              'asymmetry': 0.12,
              'motionEnergy': 0.45,
              'smilingProb': 0.85,
            });
        final featExpr =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          expressiveFrames,
        );
        for (final idx in [4, 5, 6, 7, 20, 21, 22, 23]) {
          final z = (featExpr[idx] - visMean[idx].toDouble()) /
              (visStd[idx].toDouble() + 1e-7);
          expect(z.abs(), lessThan(6.0), reason: 'Feature idx $idx spiked: z=$z');
        }

        // 4. 5 AU UI scores derived directly from normalized 75D vector
        final uiScoresExpr =
            await MultimodalExtractorService.deriveActionUnitScoresFrom75DForTest(
          featExpr,
        );
        final uiScoresDown =
            await MultimodalExtractorService.deriveActionUnitScoresFrom75DForTest(
          featDown,
        );
        expect(uiScoresExpr.length, equals(5));
        expect(
          uiScoresExpr['AU12 Lip Corner Puller (Zygomaticus / Smile)']!,
          greaterThan(uiScoresDown['AU12 Lip Corner Puller (Zygomaticus / Smile)']!),
        );

        // 5. Non-Android platform protection (without allowSyntheticByteFallback)
        await expectLater(
          MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileA.path,
            participantId: 'P_NON_ANDROID_BLOCK',
          ),
          throwsA(isA<UnsupportedVisualPlatformException>()),
        );

        final disabledFeat =
            await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempFileA.path,
          participantId: 'P_NON_ANDROID_DISABLED',
          requireFaceDetection: false,
        );
        expect(disabledFeat.isVisualBranchDisabled, isTrue);
        expect(disabledFeat.facesDetected, equals(0));
        expect(disabledFeat.inspectionData.isVisualBranchDisabled, isTrue);
        expect(disabledFeat.inspectionData.faceDetectionRatePct, equals(0.0));

        final prep = LocalPreprocessingService();
        final prepTensors = await prep.prepareMultimodalTensors(
          audioInput: disabledFeat.audioFeatures,
          visualInput: disabledFeat.visualFeatures,
          textInput: disabledFeat.textFeatures,
          disableVisualBranch: true,
        );
        expect(prepTensors.qualityFlags['poor_visual_quality'], isTrue);
      },
    );

    test(
      'MediaPipe 52 ARKit Blendshapes map cleanly to 75D OpenFace AUs without spikes & separate depressive vs happy affect',
      () async {
        final statsJson = json.decode(
          await File('assets/models/train_norm_stats_edge.json').readAsString(),
        ) as Map<String, dynamic>;
        final visMean =
            (statsJson['visual']['mean'] as List).cast<num>();
        final visStd =
            (statsJson['visual']['std'] as List).cast<num>();

        // 1. Neutral calm face using ARKit blendshapes (no synthetic cueScale amplification)
        final neutralMpFrames = List<Map<String, double>>.generate(12, (i) => {
              'usedMediaPipe': 1.0,
              'faceFound': 1.0,
              'timestampMs': i * 500.0,
              'timeSec': i * 0.5,
              'eulerX': -11.5, // slight natural downward webcam angle -> poseRx ~ +0.20 rad
              'eulerY': (i.isEven ? 1.5 : -1.5),
              'eulerZ': 0.5,
              'gazeAngleX': 0.02 * (i.isEven ? 1 : -1),
              'gazeAngleY': 0.34,
              'bs_browInnerUp': 0.12 + (i % 3) * 0.02,
              'bs_browOuterUpLeft': 0.08 + (i % 2) * 0.03,
              'bs_browOuterUpRight': 0.07 + (i % 2) * 0.03,
              'bs_browDownLeft': 0.15,
              'bs_browDownRight': 0.15,
              'bs_cheekSquintLeft': 0.12,
              'bs_cheekSquintRight': 0.12,
              'bs_eyeSquintLeft': 0.22,
              'bs_eyeSquintRight': 0.22,
              'bs_noseSneerLeft': 0.06,
              'bs_noseSneerRight': 0.06,
              'bs_mouthUpperUpLeft': 0.18,
              'bs_mouthUpperUpRight': 0.18,
              'bs_mouthSmileLeft': 0.10,
              'bs_mouthSmileRight': 0.10,
              'bs_mouthDimpleLeft': 0.16,
              'bs_mouthDimpleRight': 0.16,
              'bs_mouthFrownLeft': 0.08,
              'bs_mouthFrownRight': 0.08,
              'bs_mouthPressLeft': 0.14,
              'bs_mouthPressRight': 0.14,
              'bs_mouthStretchLeft': 0.05,
              'bs_mouthStretchRight': 0.05,
              'bs_mouthShrugLower': 0.15,
              'bs_mouthClose': 0.65,
              'bs_jawOpen': 0.14,
              'bs_eyeBlinkLeft': (i == 4 ? 0.80 : 0.06),
              'bs_eyeBlinkRight': (i == 4 ? 0.80 : 0.06),
            });

        final featNeutral =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          neutralMpFrames,
        );

        // Verify ALL 75 features are within healthy Z-score range (especially AU02 [4..7] & AU09 [20..23])
        for (int idx = 0; idx < 75; idx++) {
          final z = (featNeutral[idx] - visMean[idx].toDouble()) /
              (visStd[idx].toDouble() + 1e-7);
          expect(
            z.abs(),
            lessThan(4.5),
            reason: 'MediaPipe neutral feature idx $idx exceeded +/-4.5 sigma (z=$z)',
          );
        }

        // 2. Depressive affect vs Happy Duchenne blendshapes
        final depressiveMpFrames = List<Map<String, double>>.generate(12, (i) => {
              ...neutralMpFrames[i],
              'eulerX': -18.0, // looking down more prominently
              'bs_browInnerUp': 0.58,
              'bs_browDownLeft': 0.65,
              'bs_browDownRight': 0.65,
              'bs_mouthSmileLeft': 0.02,
              'bs_mouthSmileRight': 0.02,
              'bs_mouthFrownLeft': 0.62,
              'bs_mouthFrownRight': 0.62,
              'bs_cheekSquintLeft': 0.04,
              'bs_cheekSquintRight': 0.04,
            });

        final happyMpFrames = List<Map<String, double>>.generate(12, (i) => {
              ...neutralMpFrames[i],
              'eulerX': -3.0,
              'bs_browInnerUp': 0.08,
              'bs_browDownLeft': 0.03,
              'bs_browDownRight': 0.03,
              'bs_mouthSmileLeft': 0.78,
              'bs_mouthSmileRight': 0.78,
              'bs_cheekSquintLeft': 0.68,
              'bs_cheekSquintRight': 0.68,
              'bs_mouthFrownLeft': 0.02,
              'bs_mouthFrownRight': 0.02,
            });

        final featDepr =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          depressiveMpFrames,
        );
        final featHappy =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          happyMpFrames,
        );

        // Depressive frames must have higher AU04 (idx 8) & AU15 (idx 36) & pose_Rx (idx 69)
        expect(featDepr[8], greaterThan(featHappy[8]));
        expect(featDepr[36], greaterThan(featHappy[36]));
        expect(featDepr[69], greaterThan(featHappy[69]));
        // Happy frames must have higher AU12 (idx 28) & Duchenne fraction (idx 64)
        expect(featHappy[28], greaterThan(featDepr[28]));
        expect(featHappy[64], greaterThan(featDepr[64]));

        // UI AU scores from 75D must align monotonically
        final uiDepr =
            await MultimodalExtractorService.deriveActionUnitScoresFrom75DForTest(
          featDepr,
        );
        final uiHappy =
            await MultimodalExtractorService.deriveActionUnitScoresFrom75DForTest(
          featHappy,
        );
        expect(
          uiDepr['AU04 Brow Lowerer (Corrugator Supercilii)']!,
          greaterThan(uiHappy['AU04 Brow Lowerer (Corrugator Supercilii)']!),
        );
        expect(
          uiDepr['AU15 Lip Corner Depressor (Depressive Affect)']!,
          greaterThan(uiHappy['AU15 Lip Corner Depressor (Depressive Affect)']!),
        );
        expect(
          uiHappy['AU12 Lip Corner Puller (Zygomaticus / Smile)']!,
          greaterThan(uiDepr['AU12 Lip Corner Puller (Zygomaticus / Smile)']!),
        );

        // Background 59 OpenFace features must project monotonically along z_high - z_low from happy -> neutral -> depressive
        final visZLow = (statsJson['visual']['z_low'] as List).cast<num>();
        final visZHigh = (statsJson['visual']['z_high'] as List).cast<num>();
        const preservedPhysical = <int>{
          8, 10, 16, 28, 29, 36, 38, 53, 57, 60, 64, 66, 69, 70, 73, 74,
        };
        double projectBackgroundMean(List<double> feat) {
          double sum = 0.0;
          int count = 0;
          for (int i = 0; i < 75; i++) {
            if (preservedPhysical.contains(i)) continue;
            final z = (feat[i] - visMean[i].toDouble()) / (visStd[i].toDouble() + 1e-7);
            final dir = visZHigh[i].toDouble() - visZLow[i].toDouble();
            sum += z * dir;
            count++;
          }
          return sum / count;
        }

        final projHappy = projectBackgroundMean(featHappy);
        final projNeutral = projectBackgroundMean(featNeutral);
        final projDepr = projectBackgroundMean(featDepr);
        expect(projNeutral, greaterThan(projHappy));
        expect(projDepr, greaterThan(projNeutral));
      },
    );

    test(
      'TEST 4 Regression: AU02 p75 bounded, responsive motor dynamics, non-floored chart cues, and negation-aware sleep/mood valence',
      () async {
        final statsJson = json.decode(
          await File('assets/models/train_norm_stats_edge.json').readAsString(),
        ) as Map<String, dynamic>;
        final visMean = (statsJson['visual']['mean'] as List).cast<num>();
        final visStd = (statsJson['visual']['std'] as List).cast<num>();

        // Simulasi 24 frame MediaPipe ~53.8 dtk seperti rekaman TEST 4 (wajah aktif bicara & ekspresi ringan)
        final mpSpeakingFrames = List<Map<String, double>>.generate(24, (i) {
          final isSmile = i == 4 || i == 11 || i == 22;
          return {
            'usedMediaPipe': 1.0,
            'faceFound': 1.0,
            'confidence': 0.99,
            'timestampMs': i * 2240.0,
            'timeSec': i * 2.24,
            'eulerX': i < 12 ? -2.5 + (i % 3) : 4.5 + (i % 4),
            'eulerY': (i % 3 - 1) * 2.0,
            'eulerZ': (i.isEven ? 1.2 : -0.8),
            'gazeAngleX': 0.03 * (i % 3 - 1),
            'gazeAngleY': 0.14 + (i % 4) * 0.03,
            'browActivation': 0.12 + (i % 4) * 0.09,
            'eyeOpenness': 0.95 + (i % 3) * 0.05,
            'motionEnergy': i == 0 ? 0.0 : (0.35 + (i % 5) * 0.16),
            'bs_browInnerUp': 0.12 + (i % 3) * 0.04,
            'bs_browOuterUpLeft': 0.34 + (i % 2) * 0.03,
            'bs_browOuterUpRight': 0.33 + (i % 2) * 0.03,
            'bs_browDownLeft': 0.02 + (i % 3) * 0.02,
            'bs_browDownRight': 0.02 + (i % 3) * 0.02,
            'bs_cheekSquintLeft': isSmile ? 0.45 : 0.08,
            'bs_cheekSquintRight': isSmile ? 0.45 : 0.08,
            'bs_eyeSquintLeft': 0.18,
            'bs_eyeSquintRight': 0.18,
            'bs_noseSneerLeft': 0.06,
            'bs_noseSneerRight': 0.06,
            'bs_mouthSmileLeft': isSmile ? 0.65 : (0.04 + (i % 3) * 0.03),
            'bs_mouthSmileRight': isSmile ? 0.65 : (0.04 + (i % 3) * 0.03),
            'bs_mouthFrownLeft': 0.03 + (i % 2) * 0.02,
            'bs_mouthFrownRight': 0.03 + (i % 2) * 0.02,
            'bs_mouthClose': (i % 2 == 0) ? 0.20 : 0.70,
            'bs_jawOpen': (i % 3) * 0.25 + 0.08,
            'bs_eyeBlinkLeft': i == 20 ? 0.70 : 0.05,
            'bs_eyeBlinkRight': i == 20 ? 0.70 : 0.05,
          };
        });

        final feat =
            await MultimodalExtractorService.extractVisualFeatures75DForTest(
          mpSpeakingFrames,
        );
        // 1. AU02 p75 (idx 6) tidak boleh spike ke +4.5 sigma
        final zAu02P75 =
            (feat[6] - visMean[6].toDouble()) / (visStd[6].toDouble() + 1e-7);
        expect(zAu02P75.abs(), lessThan(2.5),
            reason: 'AU02 p75 still spiked: z=$zAu02P75');

        // 2. Motor dynamics aktif bicara tidak jatuh ke lantai 0.20
        final uiScores =
            await MultimodalExtractorService.deriveActionUnitScoresFrom75DForTest(
          feat,
        );
        expect(
          uiScores['Optical Flow / Facial Motor Dynamics']!,
          greaterThan(0.45),
        );

        // 3 & 4. Grafik ekspresi ringan tidak terpotong rata 0.05 & valensi tidur nyenyak + negasi positif
        final inspection =
            await MultimodalExtractorService.buildRealInspectionDataForTest(
          participantId: 'TEST_4_REGR',
          rawFrames: mpSpeakingFrames,
          clientTranscript:
              'suasana hati saya dua minggu terakhir sangat baik tidak ada yang menyedihkan '
              'untuk kemudahan tidur malam hari saya juga tidurnya nyenyak '
              'dan tidak begitu terkuras masih wajar dalam kehidupan sehari hari',
        );
        expect(
          inspection.visualFrames.first.expressionLabel,
          isNot(contains('Cenderung Datar')),
        );
        final avgBrow = inspection.visualFrames
                .map((f) => f.browTension)
                .reduce((a, b) => a + b) /
            inspection.visualFrames.length;
        expect(avgBrow, greaterThan(0.12));
        expect(inspection.emotionalValence, greaterThan(0.0));
        expect(
          inspection.linguisticTitle,
          equals('Narasi Cerita Terstruktur dengan Upaya Regulasi Diri'),
        );
      },
    );

    test(
      'TEST 5 Regression: unpunctuated Indonesian STT transcript splits by discourse cues & preserves ASR/pronoun clarity',
      () {
        const rawStt =
            'suasana hati saya dua minggu terakhirmu bagus kemudian saya juga tidak sedih '
            'lalu untuk mood juga baik tidak bad mood Kemudian untuk bersantai saya masih '
            'bersantai dan menikmati waktu luang saya untuk pola tidur sendiri Saya masih '
            'tidur dengan cukup dan nyaman Kemudian untuk stamina atau energi di pagi hari '
            'saya masih mendapatkan energi yang cukup untuk menjalani aktivitas sehari-hari';

        final normalized =
            OnDeviceWhisperService.normalizeIndonesianAsrText(rawStt);
        expect(normalized, contains('dua minggu terakhir ini bagus'));
        expect(normalized, isNot(contains('terakhirmu')));

        final clauses =
            OnDeviceWhisperService.splitIndonesianTranscriptClauses(normalized);
        expect(clauses.length, greaterThanOrEqualTo(5));
        expect(clauses.first, contains('terakhir ini bagus'));
      },
    );

    test(
      'AudioCalibrationProfile: quiet VOICE_RECOGNITION normal male speech stays low severity while genuinely paused monotone speech elevates cleanly',
      () async {
        const channel = MethodChannel('com.fedmind.edge/multimodal_extractor');
        final binding = TestDefaultBinaryMessengerBinding.instance;
        final List<bool?> receivedFullDurationFlags = [];

        const int sr = 16000;
        const int nSamples = 80000; // 5 detik @ 16 kHz

        // 1. Pembicaraan pria wajar lewat mic VOICE_RECOGNITION lembut (p90~0.016, bicara ~72%, intonasi variatif 105-145 Hz)
        final normalPcm = List<double>.filled(nSamples, 0.0);
        double phaseNorm = 0.0;
        for (int n = 0; n < nSamples; n++) {
          final sec = n / sr;
          final isSpeaking = (sec % 1.0) < 0.72;
          final f0 = 124.0 + 20.0 * sin(2 * pi * 0.9 * sec);
          phaseNorm += (2 * pi * f0) / sr;
          if (isSpeaking) {
            normalPcm[n] = 0.020 *
                (sin(phaseNorm) +
                    0.40 * sin(2 * phaseNorm) +
                    0.18 * sin(3 * phaseNorm));
          } else {
            normalPcm[n] = 0.0012 * cos(n * 1.9);
          }
        }

        // 2. Pembicaraan tertekan: jeda panjang (~65%), monoton (102 ± 3 Hz), lirih
        final depressedPcm = List<double>.filled(nSamples, 0.0);
        double phaseDep = 0.0;
        for (int n = 0; n < nSamples; n++) {
          final sec = n / sr;
          final isSpeaking = (sec % 2.0) < 0.70; // aktif ~35%, jeda ~65%
          final f0 = 102.0 + 3.0 * sin(2 * pi * 0.4 * sec);
          phaseDep += (2 * pi * f0) / sr;
          if (isSpeaking) {
            depressedPcm[n] = 0.011 *
                (sin(phaseDep) +
                    0.25 * sin(2 * phaseDep) +
                    0.08 * sin(3 * phaseDep));
          } else {
            depressedPcm[n] = 0.0012 * cos(n * 1.9);
          }
        }

        final baseFrames = List<Map<String, dynamic>>.generate(12, (i) {
          return {
            'index': i,
            'timeSec': i * 2.0,
            'faceFound': 1.0,
            'confidence': 0.92,
            'bboxLeft': 0.25,
            'bboxTop': 0.20,
            'bboxRight': 0.75,
            'bboxBottom': 0.85,
            'eulerX': 1.0,
            'eulerY': 0.5,
            'eulerZ': 0.2,
            'browActivation': 0.30,
            'eyeOpenness': 0.90,
            'cheekActivation': 0.35,
            'mouthActivation': 0.55,
            'mouthOpenness': 0.45,
            'asymmetry': 0.03,
            'motionEnergy': 0.25,
          };
        });

        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'extractVideoMultimodal') {
            final args = call.arguments as Map<dynamic, dynamic>;
            receivedFullDurationFlags
                .add(args['fullDurationAudioSampling'] as bool?);
            final vid = args['videoPath'] as String;
            final isNorm = vid == tempFileA.path;
            return {
              'visual': {
                'frames': baseFrames,
                'facesDetectedCount': 12,
                'totalSampled': 12,
                'durationMs': 35000,
              },
              'audio': {
                'pcmSamples': isNorm ? normalPcm : depressedPcm,
                'sampleRate': sr,
              },
            };
          }
          return null;
        });

        try {
          final normLegacy = await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileA.path,
            participantId: 'QUIET_NORM_LEG',
            audioProfile: AudioCalibrationProfile.legacyBaseline,
          );
          final normCal = await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileA.path,
            participantId: 'QUIET_NORM_CAL',
            audioProfile: AudioCalibrationProfile.phoneMicCalibrated,
          );
          final depCal = await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: tempFileB.path,
            participantId: 'DEP_MON_CAL',
            audioProfile: AudioCalibrationProfile.phoneMicCalibrated,
          );

          expect(receivedFullDurationFlags, equals([false, true, true]));

          // Baseline legacy keliru menilai audio VOICE_RECOGNITION lembut sebagai rendah energi / jeda tinggi
          expect(
            normLegacy.audioSummaryStats['audioSeverity']!,
            greaterThan(normCal.audioSummaryStats['audioSeverity']!),
          );

          // Kalibrasi adaptif menangkap bicara pria lembut secara akurat
          expect(normCal.inspectionData.pauseRatioPct, lessThan(45.0));
          expect(normCal.audioSummaryStats['audioSeverity']!, lessThan(0.05));
          expect(normCal.inspectionData.avgPitchHz, inInclusiveRange(100.0, 150.0));

          // Bicara tertekan (jeda panjang & monoton) tetap terdeteksi bermakna lebih tinggi
          expect(depCal.inspectionData.pauseRatioPct, greaterThan(55.0));
          expect(
            depCal.audioSummaryStats['audioSeverity']!,
            greaterThan(normCal.audioSummaryStats['audioSeverity']! + 0.30),
          );
        } finally {
          binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        }
      },
    );
  });
}
