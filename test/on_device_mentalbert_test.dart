import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/core/services/on_device_mentalbert_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnDeviceMentalBertService - Asset & Tokenizer Parity', () {
    setUp(() async {
      await OnDeviceMentalBertService.dispose();
      OnDeviceMentalBertService.assetLoaderOverride =
          (path) => File(path).readAsString();
    });

    tearDown(() async {
      OnDeviceMentalBertService.assetLoaderOverride = null;
      OnDeviceMentalBertService.sessionLoaderOverride = null;
      await OnDeviceMentalBertService.dispose();
    });

    test('MentalBERT assets exist on disk and are declared in pubspec.yaml', () async {
      final pubspec = await File('pubspec.yaml').readAsString();
      const requiredAssets = [
        'assets/models/mentalbert/mentalbert_mean_pool_int4.onnx',
        'assets/models/mentalbert/vocab.txt',
        'assets/models/mentalbert/tokenizer_config.json',
        'assets/models/mentalbert/special_tokens_map.json',
      ];
      for (final asset in requiredAssets) {
        expect(pubspec.contains(asset), isTrue, reason: 'Missing in pubspec.yaml: $asset');
        expect(await File(asset).exists(), isTrue, reason: 'Missing file: $asset');
      }
    });

    test('BertTokenizer produces exact reference IDs on P600-style English text', () async {
      final ids = await OnDeviceMentalBertService.encodeTokenIdsForTest(
        'I feel exhausted lately and have trouble focusing on daily routines.',
      );
      expect(
        ids,
        equals([
          101, 1045, 2514, 9069, 9906, 1998, 2031, 4390, 7995, 2006, 3679,
          23964, 1012, 102,
        ]),
      );
    });

    test('BertTokenizer handles curly quotes, em-dash, and accented characters identically to HF BertTokenizer', () async {
      final ids = await OnDeviceMentalBertService.encodeTokenIdsForTest(
        'I don\u2019t feel well \u2014 caf\u00e9 na\u00efve!',
      );
      expect(
        ids,
        equals([
          101, 1045, 2123, 1521, 1056, 2514, 2092, 1517, 7668, 15743, 999, 102,
        ]),
      );
    });

    test('BertTokenizer produces exact reference IDs on P716 severe depression excerpt', () async {
      final ids = await OnDeviceMentalBertService.encodeTokenIdsForTest(
        'UPS down depression. I hit rock bottom and I have problems sleeping, '
        'bad dreams, bad mood depression, irritable on edge, isolation not really talking with anybody.',
      );
      expect(
        ids,
        equals([
          101, 11139, 2091, 6245, 1012, 1045, 2718, 2600, 3953, 1998, 1045,
          2031, 3471, 5777, 1010, 2919, 5544, 1010, 2919, 6888, 6245, 1010,
          20868, 17728, 3468, 2006, 3341, 1010, 12477, 2025, 2428, 3331, 2007,
          10334, 1012, 102,
        ]),
      );
    });

    test('BertTokenizer truncates at 512 tokens preserving [CLS] and [SEP] and maps >200-char words to [UNK]', () async {
      final longSentence = List.filled(600, 'sad').join(' ');
      final ids = await OnDeviceMentalBertService.encodeTokenIdsForTest(longSentence);
      expect(ids.length, equals(OnDeviceMentalBertService.maxLength));
      expect(ids.first, equals(101));
      expect(ids.last, equals(102));

      final overlongWordIds = await OnDeviceMentalBertService.encodeTokenIdsForTest(
        'a' * 205,
      );
      expect(overlongWordIds, equals([101, 100, 102]));
    });
  });

  group('OnDeviceMentalBertService - ONNX Runtime Integration & Cleanup', () {
    const ortChannel = MethodChannel('flutter_onnxruntime');
    late int nextValueId;
    late Map<String, Map<String, dynamic>> createdValues;
    late List<String> releasedValueIds;
    late List<String> closedSessions;
    late Map<String, dynamic>? lastInferenceCall;

    setUp(() async {
      await OnDeviceMentalBertService.dispose();
      nextValueId = 1;
      createdValues = {};
      releasedValueIds = [];
      closedSessions = [];
      lastInferenceCall = null;

      OnDeviceMentalBertService.assetLoaderOverride =
          (path) => File(path).readAsString();
      OnDeviceMentalBertService.sessionLoaderOverride = (assetPath) async {
        expect(assetPath, equals(OnDeviceMentalBertService.modelAssetPath));
        return OrtSession.fromMap({
          'sessionId': 'mentalbert_test_session',
          'inputNames': ['input_ids', 'attention_mask'],
          'outputNames': ['sentence_embedding'],
        });
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ortChannel, (MethodCall call) async {
        final args = call.arguments as Map<dynamic, dynamic>?;
        switch (call.method) {
          case 'createOrtValue':
            final id = 'ort_val_${nextValueId++}';
            createdValues[id] = {
              'sourceType': args!['sourceType'],
              'data': args['data'],
              'shape': args['shape'],
            };
            return {
              'valueId': id,
              'dataType': args['sourceType'],
              'shape': args['shape'],
            };
          case 'runInference':
            lastInferenceCall = Map<String, dynamic>.from(args!);
            final outVec = Float32List(768);
            for (int i = 0; i < 768; i++) {
              outVec[i] = i == 0 ? double.nan : (i * 0.01 - 2.0);
            }
            createdValues['ort_out_1'] = {
              'sourceType': 'float32',
              'data': outVec,
              'shape': [1, 768],
            };
            return {
              'sentence_embedding': [
                'ort_out_1',
                'float32',
                [1, 768],
              ],
            };
          case 'getOrtValueData':
            final id = args!['valueId'] as String;
            return {'data': createdValues[id]!['data']};
          case 'releaseOrtValue':
            releasedValueIds.add(args!['valueId'] as String);
            return null;
          case 'closeSession':
            closedSessions.add(args!['sessionId'] as String);
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() async {
      await OnDeviceMentalBertService.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ortChannel, null);
      OnDeviceMentalBertService.assetLoaderOverride = null;
      OnDeviceMentalBertService.sessionLoaderOverride = null;
    });

    test('Empty or whitespace text returns 768 zeros without invoking ONNX', () async {
      final emb = await OnDeviceMentalBertService.embedEnglish('   \n\t  ');
      expect(emb.length, equals(768));
      expect(emb.every((v) => v == 0.0), isTrue);
      expect(lastInferenceCall, isNull);
    });

    test('embedEnglish sends int64 [1, 512] tensors, sanitizes non-finite outputs, and disposes all OrtValues', () async {
      final emb = await OnDeviceMentalBertService.embedEnglish(
        'I feel exhausted lately.',
      );

      expect(OnDeviceMentalBertService.isInitialized, isTrue);
      expect(emb.length, equals(768));
      expect(emb[0], equals(0.0)); // NaN sanitized to 0.0
      expect(emb[10], closeTo(10 * 0.01 - 2.0, 1e-5));

      expect(lastInferenceCall, isNotNull);
      final inputIdsVal = createdValues['ort_val_1']!;
      final maskVal = createdValues['ort_val_2']!;
      expect(inputIdsVal['sourceType'], equals('int64'));
      expect(inputIdsVal['shape'], equals([1, 512]));
      expect(maskVal['sourceType'], equals('int64'));
      expect(maskVal['shape'], equals([1, 512]));

      final idsData = inputIdsVal['data'] as Int64List;
      final maskData = maskVal['data'] as Int64List;
      // [CLS] I feel exhausted lately . [SEP] -> 7 real tokens
      expect(idsData.sublist(0, 7), equals([101, 1045, 2514, 9069, 9906, 1012, 102]));
      expect(idsData[7], equals(0));
      expect(maskData.sublist(0, 7), equals([1, 1, 1, 1, 1, 1, 1]));
      expect(maskData[7], equals(0));

      // All 2 input tensors + 1 output tensor must be disposed
      expect(releasedValueIds, containsAll(['ort_val_1', 'ort_val_2', 'ort_out_1']));

      await OnDeviceMentalBertService.dispose();
      expect(OnDeviceMentalBertService.isInitialized, isFalse);
      expect(closedSessions, equals(['mentalbert_test_session']));
    });

    test('MultimodalExtractorService uses OnDeviceMentalBertService and integrates with LocalPreprocessingService', () async {
      const extractorChannel = MethodChannel('com.fedmind.edge/multimodal_extractor');
      final tempVideo = File('${Directory.systemTemp.path}/mentalbert_integ_test.mp4');
      await tempVideo.writeAsBytes(List<int>.filled(256, 42));

      final frames = List<Map<String, double>>.generate(8, (i) => {
        'timeSec': i * 1.5,
        'faceFound': 1.0,
        'confidence': 0.94,
        'bboxLeft': 0.25,
        'bboxTop': 0.20,
        'bboxRight': 0.75,
        'bboxBottom': 0.80,
        'eulerX': -1.0,
        'eulerY': 0.5,
        'eulerZ': 0.2,
        'browActivation': 0.35,
        'eyeOpenness': 0.45,
        'cheekActivation': 0.40,
        'mouthActivation': 0.42,
        'mouthOpenness': 0.30,
        'asymmetry': 0.04,
        'motionEnergy': 0.25,
      });
      final pcm = List<double>.generate(8000, (n) => 0.15 * sin(2 * pi * 140 * n / 8000));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(extractorChannel, (MethodCall call) async {
        if (call.method == 'extractVideoMultimodal') {
          return {
            'visual': {
              'frames': frames,
              'facesDetectedCount': 8,
              'totalSampled': 8,
              'durationMs': 12000,
            },
            'audio': {
              'pcmSamples': pcm,
              'sampleRate': 8000,
            },
          };
        }
        return null;
      });

      try {
        final extracted = await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: tempVideo.path,
          participantId: 'P_MBERT_TEST',
          clientTranscript: 'I feel exhausted lately and have trouble sleeping.',
        );

        expect(extracted.usedMentalBertOnnx, isTrue);
        expect(extracted.textEmbeddingEngine, equals('MentalBERT-INT4 ONNX (768D)'));
        expect(extracted.textFeatures.length, equals(768));
        expect(extracted.toMetadataMap()['used_mentalbert_onnx'], isTrue);
        expect(extracted.extractionSummary, contains('MentalBERT-INT4 ONNX (768D)'));

        final prep = LocalPreprocessingService();
        final tensors = await prep.prepareMultimodalTensors(
          audioInput: extracted.audioFeatures,
          visualInput: extracted.visualFeatures,
          textInput: extracted.textFeatures,
        );
        expect(tensors.text.length, equals(512 * 768));
        expect(tensors.text.every((v) => v.isFinite), isTrue);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(extractorChannel, null);
        if (await tempVideo.exists()) {
          await tempVideo.delete();
        }
      }
    });

    test(
      'encodeChunksForTest splits transcripts >512 tokens with stride 256 and embedEnglish mean-pools chunks',
      () async {
        final longWords = List<String>.generate(
          650,
          (i) => i.isEven ? 'tired' : 'sleep',
        ).join(' ');

        final chunks = await OnDeviceMentalBertService.encodeChunksForTest(longWords);
        expect(chunks.length, greaterThan(1));
        for (final chunk in chunks) {
          expect(chunk.length, lessThanOrEqualTo(OnDeviceMentalBertService.maxLength));
          expect(chunk.first, equals(101)); // [CLS]
          expect(chunk.last, equals(102)); // [SEP]
        }

        int forwardCallCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ortChannel, (MethodCall call) async {
          final args = call.arguments as Map<dynamic, dynamic>?;
          switch (call.method) {
            case 'createOrtValue':
              final id = 'ort_chunk_in_${nextValueId++}';
              createdValues[id] = {
                'sourceType': args!['sourceType'],
                'data': args['data'],
                'shape': args['shape'],
              };
              return {
                'valueId': id,
                'dataType': args['sourceType'],
                'shape': args['shape'],
              };
            case 'runInference':
              forwardCallCount++;
              final fillVal = forwardCallCount * 0.2;
              final outId = 'ort_chunk_out_$forwardCallCount';
              createdValues[outId] = {
                'sourceType': 'float32',
                'data': Float32List.fromList(List<double>.filled(768, fillVal)),
                'shape': [1, 768],
              };
              return {
                'sentence_embedding': [
                  outId,
                  'float32',
                  [1, 768],
                ],
              };
            case 'getOrtValueData':
              final id = args!['valueId'] as String;
              return {'data': createdValues[id]!['data']};
            case 'releaseOrtValue':
              releasedValueIds.add(args!['valueId'] as String);
              return null;
            case 'closeSession':
              closedSessions.add(args!['sessionId'] as String);
              return null;
            default:
              return null;
          }
        });

        final pooled = await OnDeviceMentalBertService.embedEnglish(longWords);
        expect(forwardCallCount, equals(chunks.length));
        expect(pooled.length, equals(768));

        final expectedMean = List<double>.generate(
          chunks.length,
          (idx) => (idx + 1) * 0.2,
        ).reduce((a, b) => a + b) / chunks.length;
        expect(pooled.first, closeTo(expectedMean, 1e-5));
        expect(pooled.last, closeTo(expectedMean, 1e-5));
      },
    );
  });
}
