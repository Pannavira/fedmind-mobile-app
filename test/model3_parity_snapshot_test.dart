import 'dart:convert';
import 'dart:math' as math;

import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/core/services/local_preprocessing_service.dart';
import 'package:fedmind_mobile_app/core/services/on_device_mentalbert_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Menghitung ringkasan deterministik (L2 norm, mean, & sampel indeks) dari vektor tensor.
Map<String, double> _tensorFingerprint(List<double> values) {
  double sum = 0.0;
  double sumSq = 0.0;
  for (final v in values) {
    sum += v;
    sumSq += v * v;
  }
  return {
    'mean': sum / values.length,
    'l2': math.sqrt(sumSq),
    'first': values.first,
    'mid': values[values.length ~/ 2],
    'last': values.last,
  };
}

void _expectFingerprint(
  Map<String, double> actual,
  Map<String, double> expected, {
  required String label,
}) {
  for (final key in expected.keys) {
    expect(
      actual[key],
      closeTo(expected[key]!, 1e-6),
      reason: '$label.$key berubah dari snapshot baseline Model 3',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Model 3 Golden Parity Snapshot', () {
    test(
      'preserves exact P600, P716, short-text calibration & mE5 token IDs',
      () async {
        final preprocessor = LocalPreprocessingService(
          defaultVariant: FedMindModelVariant.model3Edge,
        );

        final p600Raw = jsonDecode(
          await rootBundle.loadString('assets/samples/p600_features.json'),
        ) as Map<String, dynamic>;
        final p716Raw = jsonDecode(
          await rootBundle.loadString('assets/samples/p716_features.json'),
        ) as Map<String, dynamic>;

        List<double> toDoubleList(dynamic raw) =>
            (raw as List).map((e) => (e as num).toDouble()).toList();

        final p600Tensors = await preprocessor.prepareMultimodalTensors(
          audioInput: toDoubleList(p600Raw['audio_features']),
          visualInput: toDoubleList(p600Raw['visual_features']),
          textInput: toDoubleList(p600Raw['text_features']),
          variant: FedMindModelVariant.model3Edge,
        );

        final p716Tensors = await preprocessor.prepareMultimodalTensors(
          audioInput: toDoubleList(p716Raw['audio_features']),
          visualInput: toDoubleList(p716Raw['visual_features']),
          textInput: toDoubleList(p716Raw['text_features']),
          variant: FedMindModelVariant.model3Edge,
        );

        // Uji kalibrasi short_mean / short_scale saat RMS teks > 2.5
        final syntheticHighRmsText = List<double>.generate(
          768,
          (i) => (i % 2 == 0 ? 3.5 : -3.5) + (i % 7) * 0.1,
        );
        final shortCalTensors = await preprocessor.prepareMultimodalTensors(
          audioInput: List<double>.filled(248, 0.0),
          visualInput: List<double>.filled(75, 0.0),
          textInput: syntheticHighRmsText,
          variant: FedMindModelVariant.model3Edge,
        );

        expect(p600Tensors.audioShape, equals([1, 248]));
        expect(p600Tensors.visualShape, equals([1, 75]));
        expect(p600Tensors.textShape, equals([1, 768]));

        _expectFingerprint(
          _tensorFingerprint(p600Tensors.audio),
          const {
            'mean': -0.5678652204984364,
            'l2': 21.358857689620944,
            'first': -1.7947821617126465,
            'mid': -1.2180976867675781,
            'last': -1.6590083837509155,
          },
          label: 'p600.audio',
        );
        _expectFingerprint(
          _tensorFingerprint(p600Tensors.visual),
          const {
            'mean': -0.7123903839290142,
            'l2': 11.733427793413176,
            'first': -1.6312119960784912,
            'mid': -1.1282795667648315,
            'last': -1.9334031343460083,
          },
          label: 'p600.visual',
        );
        _expectFingerprint(
          _tensorFingerprint(p600Tensors.text),
          const {
            'mean': 0.007495226146071825,
            'l2': 62.06206968117487,
            'first': 2.2269229888916016,
            'mid': -1.3794602155685425,
            'last': 0.6578513979911804,
          },
          label: 'p600.text',
        );

        _expectFingerprint(
          _tensorFingerprint(p716Tensors.audio),
          const {
            'mean': -0.40443451620352966,
            'l2': 17.456533763541977,
            'first': -0.6320348978042603,
            'mid': 1.1368534564971924,
            'last': -0.3784598410129547,
          },
          label: 'p716.audio',
        );
        _expectFingerprint(
          _tensorFingerprint(p716Tensors.visual),
          const {
            'mean': -0.4106713851168752,
            'l2': 6.262360254864305,
            'first': -1.3732972145080566,
            'mid': -0.5857251882553101,
            'last': -1.188454270362854,
          },
          label: 'p716.visual',
        );
        _expectFingerprint(
          _tensorFingerprint(p716Tensors.text),
          const {
            'mean': 0.00755440038915367,
            'l2': 14.071321921785346,
            'first': -0.0795600637793541,
            'mid': 0.2544515132904053,
            'last': 0.5867118239402771,
          },
          label: 'p716.text',
        );

        _expectFingerprint(
          _tensorFingerprint(shortCalTensors.text),
          const {
            'mean': 0.004678883279363315,
            'l2': 110.7175174242801,
            'first': 3.6968653202056885,
            'mid': 4.0,
            'last': -4.0,
          },
          label: 'short_cal.text',
        );

        // Tokenisasi mE5 Unigram SentencePiece
        final idPhrase1 = await OnDeviceMentalBertService.encodeTokenIdsForTest(
          'Saya merasa sedih dan sering lelah belakangan ini',
        );
        final idPhrase2 = await OnDeviceMentalBertService.encodeTokenIdsForTest(
          'Tidur saya terganggu dan kehilangan minat melakukan aktivitas',
        );
        final enPhrase = await OnDeviceMentalBertService.encodeTokenIdsForTest(
          'I have been feeling down and hopeless for the past two weeks',
        );

        expect(
          idPhrase1,
          equals(const [0, 7775, 21266, 119752, 123, 16245, 95, 1566, 27754, 66, 485, 2]),
        );
        expect(
          idPhrase2,
          equals(const [0, 173255, 1216, 704, 112470, 123, 68942, 118243, 6916, 83237, 2]),
        );
        expect(
          enPhrase,
          equals(const [0, 87, 765, 2809, 34698, 7565, 136, 15673, 9393, 100, 70, 11015, 6626, 40859, 2]),
        );

        // Kunci konfigurasi XAI & threshold Model 3
        final xaiEdge = jsonDecode(
          await rootBundle.loadString('assets/models/xai_baseline_edge.json'),
        ) as Map<String, dynamic>;
        expect((xaiEdge['v_000'] as num).toDouble(), closeTo(10.073630332946777, 1e-6));
        expect((xaiEdge['calibrated_threshold'] as num).toDouble(), closeTo(9.4, 1e-6));
        expect(xaiEdge['latent_dim'], equals(128));
        expect((xaiEdge['z_clip'] as num).toDouble(), closeTo(4.0, 1e-6));

        final inference = LocalInferenceService();
        expect(inference.selectedVariant, equals(FedMindModelVariant.model3Edge));
        expect(inference.binaryThreshold, closeTo(9.4, 1e-6));
      },
    );
  });
}
