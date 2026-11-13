import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class LocalPreparedTensors {
  final Float32List audio; // Shape [1, 512, 80] -> length 40,960
  final Float32List visual; // Shape [1, 512, 72, 3] -> length 110,592
  final Float32List text; // Shape [1, 512, 768] -> length 393,216
  final Map<String, dynamic> qualityFlags;

  LocalPreparedTensors({
    required this.audio,
    required this.visual,
    required this.text,
    required this.qualityFlags,
  });
}

class LocalPreprocessingService {
  static const String _statsAssetPath = 'assets/models/train_norm_stats.json';

  Map<String, List<double>>? _meanStats;
  Map<String, List<double>>? _stdStats;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Memuat statistik normalisasi training (mean dan std) dari asset JSON
  Future<void> initialize() async {
    if (_isLoaded) return;

    final jsonString = await rootBundle.loadString(_statsAssetPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;

    _meanStats = {};
    _stdStats = {};

    for (final mod in ['audio', 'visual', 'text']) {
      if (data.containsKey(mod)) {
        final modData = data[mod] as Map<String, dynamic>;
        _meanStats![mod] = (modData['mean'] as List).map((e) => (e as num).toDouble()).toList();
        _stdStats![mod] = (modData['std'] as List).map((e) => (e as num).toDouble()).toList();
      }
    }

    _isLoaded = true;
  }

  /// Z-score normalization: (x - mean) / (std + 1e-7)
  List<double> normalizeFeature(List<double> raw, String modality) {
    if (_meanStats == null || !_meanStats!.containsKey(modality)) {
      return List<double>.from(raw);
    }

    final mean = _meanStats![modality]!;
    final std = _stdStats![modality]!;
    final out = List<double>.filled(raw.length, 0.0);

    for (int i = 0; i < raw.length; i++) {
      final m = i < mean.length ? mean[i] : 0.0;
      final s = i < std.length ? std[i] : 1.0;
      final val = raw[i];
      if (val.isNaN || val.isInfinite) {
        out[i] = 0.0;
      } else {
        out[i] = (val - m) / (s + 1e-7);
      }
    }
    return out;
  }

  /// Evaluasi Quality Flags untuk mendeteksi low information / noise
  Map<String, dynamic> checkQualityFlags({
    required List<double> audio,
    required List<double> visual,
    required List<double> text,
  }) {
    double calculateVariance(List<double> arr) {
      if (arr.isEmpty) return 0.0;
      final mean = arr.reduce((a, b) => a + b) / arr.length;
      final sumSq = arr.fold(0.0, (acc, val) => acc + pow(val - mean, 2));
      return sumSq / arr.length;
    }

    final textVar = calculateVariance(text);
    final audioVar = calculateVariance(audio);
    final visualVar = calculateVariance(visual);

    final lowText = textVar < 1e-4;
    final poorAudio = audioVar < 1e-4;
    final poorVisual = visualVar < 1e-4;

    final details = <String>[];
    if (lowText) details.add('Very low text variance (minimal responses)');
    if (poorAudio) details.add('Low audio energy or quiet recording');
    if (poorVisual) details.add('Flat facial dynamics or landmark activity');

    return {
      'low_text_information': lowText,
      'poor_audio_quality': poorAudio,
      'poor_visual_quality': poorVisual,
      'details': details.isNotEmpty ? details.join('; ') : 'Multimodal signal quality within normal parameters.',
    };
  }

  /// Menyiapkan tensor input yang 100% selaras dengan implementasi Python
  Future<LocalPreparedTensors> prepareMultimodalTensors({
    required List<double> audioInput,
    required List<double> visualInput,
    required List<double> textInput,
  }) async {
    await initialize();

    // 1. Cek Quality Flags
    final flags = checkQualityFlags(
      audio: audioInput,
      visual: visualInput,
      text: textInput,
    );

    // 2. Normalisasi Z-Score
    final normAudio = normalizeFeature(audioInput, 'audio');
    final normVisual = normalizeFeature(visualInput, 'visual');
    final normText = normalizeFeature(textInput, 'text');

    // 3. Adaptasi Temporal Sequence (T=512)
    // A. Audio Target: (512, 80) -> Float32List(512 * 80)
    final audioTensor = Float32List(512 * 80);
    final vec80 = normAudio.length >= 80 ? normAudio.sublist(0, 80) : [...normAudio, ...List.filled(80 - normAudio.length, 0.0)];
    for (int t = 0; t < 512; t++) {
      final timeStep = 0.8 + (1.2 - 0.8) * (t / 511.0);
      final offset = t * 80;
      for (int j = 0; j < 80; j++) {
        audioTensor[offset + j] = vec80[j] * timeStep;
      }
    }

    // B. Visual Target: (512, 72, 3) -> Total 512 * 216 -> Float32List(512 * 216)
    final visualTensor = Float32List(512 * 216);
    // Ulangi 75 feature hingga minimal 216 elemen
    final vec216 = List<double>.filled(216, 0.0);
    for (int i = 0; i < 216; i++) {
      vec216[i] = normVisual[i % normVisual.length];
    }
    double vMin = vec216.reduce(min);
    double vMax = vec216.reduce(max);
    if (vMax > vMin) {
      for (int i = 0; i < 216; i++) {
        vec216[i] = (vec216[i] - vMin) / (vMax - vMin);
      }
    }
    for (int t = 0; t < 512; t++) {
      final timeStep = 0.9 + (1.1 - 0.9) * (t / 511.0);
      final offset = t * 216;
      for (int j = 0; j < 216; j++) {
        visualTensor[offset + j] = vec216[j] * timeStep;
      }
    }

    // C. Text Target: (512, 768) -> Float32List(512 * 768)
    final textTensor = Float32List(512 * 768);
    final vec768 = normText.length >= 768 ? normText.sublist(0, 768) : [...normText, ...List.filled(768 - normText.length, 0.0)];
    for (int t = 0; t < 512; t++) {
      final timeStep = 0.95 + (1.05 - 0.95) * (t / 511.0);
      final offset = t * 768;
      for (int j = 0; j < 768; j++) {
        textTensor[offset + j] = vec768[j] * timeStep;
      }
    }

    return LocalPreparedTensors(
      audio: audioTensor,
      visual: visualTensor,
      text: textTensor,
      qualityFlags: flags,
    );
  }
}

