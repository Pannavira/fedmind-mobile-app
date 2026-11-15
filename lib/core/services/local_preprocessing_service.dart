import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Varian model inferensi on-device yang tersedia pada FedMind.
enum FedMindModelVariant {
  /// Model 3: Ultra-light pooled MLP + LayerNorm fusion (default & tunggal).
  model3Edge,
}

extension FedMindModelVariantX on FedMindModelVariant {
  String get key => 'edge_fl_iid';

  String get shortLabel => 'Model 3';

  String get displayName => 'Model 3 — FedAvg Edge Client (Aktif)';

  String get selectorTitle => 'Model 3 — FedAvg Edge Client (ONNX)';

  String get checkpointLabel => 'FedMind-Edge-ONNX v3.0-FL (Model 3)';

  String get checkpointFileName => 'fedmind_edge_client.onnx';

  String get regressorFileName => 'fedmind_edge_regressor.onnx';

  String get modelAssetPath => 'assets/models/$checkpointFileName';
  String get regressorAssetPath => 'assets/models/$regressorFileName';

  String get normStatsFileName => 'train_norm_stats_edge.json';

  String get normStatsAssetPath => 'assets/models/$normStatsFileName';

  String get xaiBaselineFileName => 'xai_baseline_edge.json';

  String get xaiBaselineAssetPath => 'assets/models/$xaiBaselineFileName';

  String get architectureName => 'Pooled Edge MLP + LayerNorm Fusion';

  String get parameterSummary {
    return 'Ultra-Light Pooled Edge MLP (Float32 ONNX)';
  }

  int get latentDim => 128;

  int get fusedLatentDim => latentDim * 3;

  double get defaultV000Baseline => 10.0736;

  double get binaryThreshold => 9.4;

  double? get zClip => 4.0;

  String get settingsSummary {
    return 'Pooled Edge MLP + mE5 • 128D Laten • Threshold PHQ-8 ≥ 9.4 • Z-Clip ±4.0';
  }
}

class LocalPreparedTensors {
  final FedMindModelVariant variant;
  final Float32List audio;
  final Float32List visual;
  final Float32List text;
  final List<int> audioShape;
  final List<int> visualShape;
  final List<int> textShape;
  final Map<String, dynamic> qualityFlags;

  LocalPreparedTensors({
    this.variant = FedMindModelVariant.model3Edge,
    required this.audio,
    required this.visual,
    required this.text,
    this.audioShape = const [1, 248],
    this.visualShape = const [1, 75],
    this.textShape = const [1, 768],
    required this.qualityFlags,
  });
}

class LocalPreprocessingService {
  static const Map<String, int> _expectedDims = {
    'audio': 248,
    'visual': 75,
    'text': 768,
  };

  final FedMindModelVariant defaultVariant;
  final Map<FedMindModelVariant, Map<String, List<double>>> _meanStatsByVariant = {};
  final Map<FedMindModelVariant, Map<String, List<double>>> _stdStatsByVariant = {};
  final Map<FedMindModelVariant, List<double>> _shortTextMeanByVariant = {};
  final Map<FedMindModelVariant, double> _shortTextScaleByVariant = {};

  LocalPreprocessingService({
    this.defaultVariant = FedMindModelVariant.model3Edge,
  });

  bool get isLoaded => isVariantLoaded(defaultVariant);

  bool isVariantLoaded(FedMindModelVariant variant) =>
      _meanStatsByVariant.containsKey(variant) &&
      _stdStatsByVariant.containsKey(variant);

  /// Memuat statistik normalisasi training (mean dan std) dari asset JSON
  Future<void> initialize([FedMindModelVariant? variant]) async {
    final targetVariant = variant ?? defaultVariant;
    if (isVariantLoaded(targetVariant)) return;

    final jsonString = await rootBundle.loadString(targetVariant.normStatsAssetPath);
    final data = json.decode(jsonString) as Map<String, dynamic>;

    final means = <String, List<double>>{};
    final stds = <String, List<double>>{};

    for (final mod in ['audio', 'visual', 'text']) {
      if (data.containsKey(mod)) {
        final modData = data[mod] as Map<String, dynamic>;
        means[mod] = (modData['mean'] as List).map((e) => (e as num).toDouble()).toList();
        stds[mod] = (modData['std'] as List).map((e) => (e as num).toDouble()).toList();
        if (mod == 'text') {
          final shortMeanRaw = modData['short_mean'];
          if (shortMeanRaw is List && shortMeanRaw.isNotEmpty) {
            _shortTextMeanByVariant[targetVariant] =
                shortMeanRaw.map((e) => (e as num).toDouble()).toList();
          }
          final shortScaleRaw = modData['short_scale'];
          if (shortScaleRaw is num) {
            _shortTextScaleByVariant[targetVariant] = shortScaleRaw.toDouble();
          }
        }
      }
    }

    _meanStatsByVariant[targetVariant] = means;
    _stdStatsByVariant[targetVariant] = stds;
  }

  /// Z-score normalization sesuai pipeline varian model aktif.
  List<double> normalizeFeature(
    List<double> raw,
    String modality, {
    FedMindModelVariant? variant,
    double? zClip,
    int? targetDim,
  }) {
    final targetVariant = variant ?? defaultVariant;
    final meanStats = _meanStatsByVariant[targetVariant];
    final stdStats = _stdStatsByVariant[targetVariant];

    final dim = targetDim ?? _expectedDims[modality] ?? raw.length;
    final clip = zClip ?? targetVariant.zClip ?? 4.0;
    final out = List<double>.filled(dim, 0.0);
    final mean = meanStats?[modality];
    final std = stdStats?[modality];
    if (mean == null || std == null) {
      for (int i = 0; i < dim; i++) {
        final val = i < raw.length ? raw[i] : 0.0;
        out[i] = (val.isNaN || val.isInfinite) ? 0.0 : val.clamp(-clip, clip);
      }
      return out;
    }

    final zUnclipped = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      final val = i < raw.length ? raw[i] : 0.0;
      if (val.isNaN || val.isInfinite) {
        zUnclipped[i] = 0.0;
        continue;
      }
      final m = i < mean.length ? mean[i] : 0.0;
      final s = max(i < std.length ? std[i] : 1.0, 1e-6);
      zUnclipped[i] = (val - m) / s;
    }

    final shortMean = _shortTextMeanByVariant[targetVariant];
    if (modality == 'text' && shortMean != null && dim > 0) {
      double sumSq = 0.0;
      for (int i = 0; i < dim; i++) {
        sumSq += zUnclipped[i] * zUnclipped[i];
      }
      final rms = sqrt(sumSq / dim + 1e-8);
      if (rms > 2.5) {
        final shortScale = _shortTextScaleByVariant[targetVariant] ?? 0.06;
        for (int i = 0; i < dim; i++) {
          final val = i < raw.length ? raw[i] : 0.0;
          if (val.isNaN || val.isInfinite) {
            zUnclipped[i] = 0.0;
            continue;
          }
          final sm = i < shortMean.length
              ? shortMean[i]
              : (i < mean.length ? mean[i] : 0.0);
          final s = max(i < std.length ? std[i] : 1.0, 1e-6);
          zUnclipped[i] = shortScale * (val - sm) / s;
        }
      }
    }

    for (int i = 0; i < dim; i++) {
      out[i] = zUnclipped[i].clamp(-clip, clip);
    }
    return out;
  }

  /// Evaluasi Quality Flags untuk mendeteksi low information / noise
  Map<String, dynamic> checkQualityFlags({
    required List<double> audio,
    required List<double> visual,
    required List<double> text,
    bool disableVisualBranch = false,
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
    final poorVisual = disableVisualBranch || visualVar < 1e-4;

    final details = <String>[];
    if (lowText) details.add('Very low text variance (minimal responses)');
    if (poorAudio) details.add('Low audio energy or quiet recording');
    if (disableVisualBranch) {
      details.add('Visual branch disabled (native face extractor unavailable on this platform)');
    } else if (poorVisual) {
      details.add('Flat facial dynamics or landmark activity');
    }

    return {
      'low_text_information': lowText,
      'poor_audio_quality': poorAudio,
      'poor_visual_quality': poorVisual,
      'visual_branch_disabled': disableVisualBranch,
      'details': details.isNotEmpty ? details.join('; ') : 'Multimodal signal quality within normal parameters.',
    };
  }

  /// Menyiapkan tensor input sesuai arsitektur model yang dipilih
  Future<LocalPreparedTensors> prepareMultimodalTensors({
    required List<double> audioInput,
    required List<double> visualInput,
    required List<double> textInput,
    bool disableVisualBranch = false,
    FedMindModelVariant? variant,
  }) async {
    final targetVariant = variant ?? defaultVariant;
    await initialize(targetVariant);

    // 1. Cek Quality Flags
    final flags = checkQualityFlags(
      audio: audioInput,
      visual: visualInput,
      text: textInput,
      disableVisualBranch: disableVisualBranch,
    );

    // 2. Pipeline Model 3 (Pooled Edge MLP) -> vektor pooled [1, 248], [1, 75], [1, 768]
    final normAudio = normalizeFeature(audioInput, 'audio', variant: targetVariant);
    final normVisual = disableVisualBranch
        ? List<double>.filled(75, 0.0)
        : normalizeFeature(visualInput, 'visual', variant: targetVariant);
    final normText = normalizeFeature(textInput, 'text', variant: targetVariant);

    return LocalPreparedTensors(
      variant: targetVariant,
      audio: Float32List.fromList(normAudio),
      visual: Float32List.fromList(normVisual),
      text: Float32List.fromList(normText),
      audioShape: const [1, 248],
      visualShape: const [1, 75],
      textShape: const [1, 768],
      qualityFlags: flags,
    );
  }
}

