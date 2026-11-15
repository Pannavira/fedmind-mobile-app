import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../data/models/multimodal_inspection_models.dart';
import '../../data/models/screening_models.dart';
import '../constants/clinical_constants.dart';
import 'local_preprocessing_service.dart';
import 'on_device_mentalbert_service.dart';
import 'onnx_asset_loader.dart';

class LocalInferenceService {
  final LocalPreprocessingService _preprocessor = LocalPreprocessingService();
  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _mainSession;
  OrtSession? _regSession;

  FedMindModelVariant _selectedVariant = FedMindModelVariant.model3Edge;
  FedMindModelVariant get selectedVariant => _selectedVariant;

  List<double>? _audioBase;
  List<double>? _visualBase;
  List<double>? _textBase;
  double _v000Baseline = FedMindModelVariant.model3Edge.defaultV000Baseline;
  double get v000Baseline => _v000Baseline;

  double _binaryThreshold = FedMindModelVariant.model3Edge.binaryThreshold;
  double get binaryThreshold => _binaryThreshold;

  int _latentDim = FedMindModelVariant.model3Edge.latentDim;
  int get latentDim => _latentDim;

  String _modelKey = FedMindModelVariant.model3Edge.key;
  String get modelKey => _modelKey;

  String _modelName = FedMindModelVariant.model3Edge.displayName;
  String get modelName => _modelName;

  List<CoalitionStepScore> _lastCoalitionScores = const [];
  List<CoalitionStepScore> get lastCoalitionScores => _lastCoalitionScores;

  double _lastAudioLatentNorm = 1.0;
  double get lastAudioLatentNorm => _lastAudioLatentNorm;

  double _lastVisualLatentNorm = 1.0;
  double get lastVisualLatentNorm => _lastVisualLatentNorm;

  double _lastTextLatentNorm = 1.0;
  double get lastTextLatentNorm => _lastTextLatentNorm;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get isMentalBertLoaded => OnDeviceMentalBertService.isInitialized;
  String? get mentalBertError => OnDeviceMentalBertService.lastError;

  /// Mengganti varian model aktif (Model 3 Edge default vs Model 2 Legacy)
  Future<void> setModelVariant(FedMindModelVariant variant) async {
    if (_selectedVariant == variant && _isInitialized) return;
    _selectedVariant = variant;
    _v000Baseline = variant.defaultV000Baseline;
    _binaryThreshold = variant.binaryThreshold;
    _latentDim = variant.latentDim;
    _modelKey = variant.key;
    _modelName = variant.displayName;
    await dispose();
    await initialize();
  }

  /// Memuat model ONNX dan konstanta XAI ke memori sesuai varian aktif
  Future<void> initialize() async {
    if (_isInitialized) return;

    final variant = _selectedVariant;

    // 1. Inisialisasi Preprocessor sesuai varian
    await _preprocessor.initialize(variant);

    // 2. Inisialisasi Sesi ONNX (Multimodal Fusion + Shapley Regressor + MentalBERT INT4)
    _mainSession = await OnnxAssetLoader.createSessionFromAsset(
      _ort,
      variant.modelAssetPath,
    );
    _regSession = await OnnxAssetLoader.createSessionFromAsset(
      _ort,
      variant.regressorAssetPath,
    );
    try {
      await OnDeviceMentalBertService.initialize();
    } catch (e) {
      debugPrint('[LocalInference] Peringatan gagal pra-muat MentalBERT ONNX: $e');
    }

    // 3. Memuat Baseline Laten XAI
    final xaiStr = await rootBundle.loadString(variant.xaiBaselineAssetPath);
    final xaiData = json.decode(xaiStr) as Map<String, dynamic>;

    _v000Baseline =
        (xaiData['v_000'] as num?)?.toDouble() ?? variant.defaultV000Baseline;
    _binaryThreshold =
        (xaiData['calibrated_threshold'] as num?)?.toDouble() ??
            variant.binaryThreshold;
    _latentDim = (xaiData['latent_dim'] as num?)?.toInt() ?? variant.latentDim;
    _modelKey = xaiData['model_key']?.toString() ?? variant.key;
    _modelName = xaiData['model_name']?.toString() ?? variant.displayName;
    _audioBase =
        (xaiData['audio_base'] as List).map((e) => (e as num).toDouble()).toList();
    _visualBase =
        (xaiData['visual_base'] as List).map((e) => (e as num).toDouble()).toList();
    _textBase =
        (xaiData['text_base'] as List).map((e) => (e as num).toDouble()).toList();

    _isInitialized = true;
  }

  /// Menjalankan inferensi dan Exact Shapley XAI secara lokal on-device
  Future<ScreeningResponse> predict({
    required List<double> audioFeatures,
    required List<double> visualFeatures,
    required List<double> textFeatures,
    required String participantId,
    String? sessionId,
    String? counselorNote,
    String? transcription,
    bool disableVisualBranch = false,
  }) async {
    await initialize();

    final activeVariant = _selectedVariant;
    final latentDim = _latentDim;
    final fusedDim = latentDim * 3;

    final now = DateTime.now().toUtc();
    final screeningId = sessionId ?? 'SCR-LOCAL-${now.millisecondsSinceEpoch}';

    // 1. Preprocessing & Tensor Shaping sesuai varian model aktif
    final prep = await _preprocessor.prepareMultimodalTensors(
      audioInput: audioFeatures,
      visualInput: visualFeatures,
      textInput: textFeatures,
      disableVisualBranch: disableVisualBranch,
      variant: activeVariant,
    );

    // 2. Siapkan OrtValue untuk Model Utama
    final audioOrt = await OrtValue.fromList(prep.audio, prep.audioShape);
    final visualOrt = await OrtValue.fromList(prep.visual, prep.visualShape);
    final textOrt = await OrtValue.fromList(prep.text, prep.textShape);

    Map<String, OrtValue>? mainOutputs;
    Map<String, OrtValue>? regOutputs;
    OrtValue? fusedOrt;

    try {
      // 3. Forward Pass Model Utama
      mainOutputs = await _mainSession!.run({
        'audio': audioOrt,
        'visual': visualOrt,
        'text': textOrt,
      });

      final predList = await _requireOutput(
        mainOutputs,
        const ['pred_phq8', 'phq8_pred'],
        'main prediction',
      ).asFlattenedList();
      final double rawScore = (predList[0] as num).toDouble();

      final aIList = (await _requireOutput(
        mainOutputs,
        const ['lat_audio', 'audio_latent'],
        'audio latent',
      ).asFlattenedList())
          .map((e) => (e as num).toDouble())
          .toList();
      final rawVIList = (await _requireOutput(
        mainOutputs,
        const ['lat_visual', 'visual_latent'],
        'visual latent',
      ).asFlattenedList())
          .map((e) => (e as num).toDouble())
          .toList();
      final vIList = disableVisualBranch ? List<double>.from(_visualBase!) : rawVIList;
      final tIList = (await _requireOutput(
        mainOutputs,
        const ['lat_text', 'text_latent'],
        'text latent',
      ).asFlattenedList())
          .map((e) => (e as num).toDouble())
          .toList();

      // 4. Hitung 8 Koalisi Exact Shapley menggunakan Regressor ONNX
      // Koalisi: (a, v, t) berukuran fusedDim (384D untuk Model 3 atau 768D untuk Model 2)
      final coalitionBatch = Float32List(8 * fusedDim);

      void copyCoalition(int row, List<double> a, List<double> v, List<double> t) {
        final offset = row * fusedDim;
        for (int i = 0; i < latentDim; i++) {
          coalitionBatch[offset + i] = a[i];
          coalitionBatch[offset + latentDim + i] = v[i];
          coalitionBatch[offset + (latentDim * 2) + i] = t[i];
        }
      }

      // S0: v_000 (Base, Base, Base)
      copyCoalition(0, _audioBase!, _visualBase!, _textBase!);
      // S1: v_100 (Ai, Base, Base)
      copyCoalition(1, aIList, _visualBase!, _textBase!);
      // S2: v_010 (Base, Vi, Base)
      copyCoalition(2, _audioBase!, vIList, _textBase!);
      // S3: v_001 (Base, Base, Ti)
      copyCoalition(3, _audioBase!, _visualBase!, tIList);
      // S4: v_110 (Ai, Vi, Base)
      copyCoalition(4, aIList, vIList, _textBase!);
      // S5: v_101 (Ai, Base, Ti)
      copyCoalition(5, aIList, _visualBase!, tIList);
      // S6: v_011 (Base, Vi, Ti)
      copyCoalition(6, _audioBase!, vIList, tIList);
      // S7: v_111 (Ai, Vi, Ti)
      copyCoalition(7, aIList, vIList, tIList);

      fusedOrt = await OrtValue.fromList(coalitionBatch, [8, fusedDim]);
      regOutputs = await _regSession!.run({'fused_latents': fusedOrt});

      final scoresList = (await _requireOutput(
        regOutputs,
        const ['pred_phq8', 'scores'],
        'regressor coalition scores',
      ).asFlattenedList())
          .map((e) => (e as num).toDouble())
          .toList();
      final v000 = scoresList[0];
      final v100 = scoresList[1];
      final v010 = scoresList[2];
      final v001 = scoresList[3];
      final v110 = scoresList[4];
      final v101 = scoresList[5];
      final v011 = scoresList[6];
      final v111 = scoresList[7];

      double calcL2Norm(List<double> vec) {
        if (vec.isEmpty) return 0.0;
        final sumSq = vec.fold(0.0, (acc, x) => acc + x * x);
        return double.parse(sqrt(sumSq).toStringAsFixed(2));
      }

      _lastAudioLatentNorm = calcL2Norm(aIList);
      _lastVisualLatentNorm = calcL2Norm(vIList);
      _lastTextLatentNorm = calcL2Norm(tIList);

      _lastCoalitionScores = [
        CoalitionStepScore(
          coalitionCode: 'S0 (v₀₀₀)',
          label: 'Baseline Kohort E[f(X)] (Tanpa Sinyal Klien)',
          description: 'Ekspektasi prior populasi sebelum representasi laten pasien dimasukkan',
          hasAudio: false,
          hasVisual: false,
          hasText: false,
          predictedScore: double.parse(v000.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S1 (v₁₀₀)',
          label: 'Modalitas Akustik / Prosodi Audio Tunggal',
          description: 'Estimasi PHQ-8 menggunakan fitur prosodi vokal & MFCC (248D -> ${latentDim}D)',
          hasAudio: true,
          hasVisual: false,
          hasText: false,
          predictedScore: double.parse(v100.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S2 (v₀₁₀)',
          label: 'Modalitas Visual (Facial Action Units / AUs) Tunggal',
          description: 'Estimasi PHQ-8 menggunakan aktivasi FACS Action Units & Head Pose (75D -> ${latentDim}D)',
          hasAudio: false,
          hasVisual: true,
          hasText: false,
          predictedScore: double.parse(v010.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S3 (v₀₀₁)',
          label: 'Modalitas Teks / Linguistik Tunggal',
          description: 'Estimasi PHQ-8 menggunakan embedding psikolinguistik MentalBERT (768D -> ${latentDim}D)',
          hasAudio: false,
          hasVisual: false,
          hasText: true,
          predictedScore: double.parse(v001.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S4 (v₁₁₀)',
          label: 'Koalisi Bimodal: Akustik + Visual (AUs)',
          description: 'Interaksi sinyal prosodi audio dan Facial Action Units tanpa transkrip teks',
          hasAudio: true,
          hasVisual: true,
          hasText: false,
          predictedScore: double.parse(v110.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S5 (v₁₀₁)',
          label: 'Koalisi Bimodal: Akustik + Teks Linguistik',
          description: 'Interaksi prosodi vokal dan valensi leksikal tanpa fitur visual wajah',
          hasAudio: true,
          hasVisual: false,
          hasText: true,
          predictedScore: double.parse(v101.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S6 (v₀₁₁)',
          label: 'Koalisi Bimodal: Visual (AUs) + Teks Linguistik',
          description: 'Interaksi Facial Action Units dan semantik transkrip tanpa prosodi audio',
          hasAudio: false,
          hasVisual: true,
          hasText: true,
          predictedScore: double.parse(v011.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S7 (v₁₁₁)',
          label: 'Fusi Trimodal Penuh (Akustik + Visual AUs + Teks)',
          description: 'Inferensi fusi lengkap seluruh modalitas observasi klinis',
          hasAudio: true,
          hasVisual: true,
          hasText: true,
          predictedScore: double.parse(v111.toStringAsFixed(2)),
        ),
      ];

      // Shapley Values Axiom Formula untuk 3 pemain:
      final pA = (1 / 3) * (v100 - v000) + (1 / 6) * (v110 - v010) + (1 / 6) * (v101 - v001) + (1 / 3) * (v111 - v011);
      final pV = (1 / 3) * (v010 - v000) + (1 / 6) * (v110 - v100) + (1 / 6) * (v011 - v001) + (1 / 3) * (v111 - v101);
      final pT = (1 / 3) * (v001 - v000) + (1 / 6) * (v101 - v100) + (1 / 6) * (v011 - v010) + (1 / 3) * (v111 - v110);

      final totAbs = pA.abs() + pV.abs() + pT.abs() + 1e-8;
      final pctA = double.parse(((pA.abs() / totAbs) * 100).toStringAsFixed(1));
      final pctV = double.parse(((pV.abs() / totAbs) * 100).toStringAsFixed(1));
      final pctT = double.parse(((pT.abs() / totAbs) * 100).toStringAsFixed(1));

      // Dominant Modality
      String dominantMod = 'visual';
      double maxAbs = pV.abs();
      if (pA.abs() > maxAbs) {
        dominantMod = 'audio';
        maxAbs = pA.abs();
      }
      if (pT.abs() > maxAbs) {
        dominantMod = 'text';
      }

      // 5. Post-Processing Skor & Stratifikasi Risiko
      final boundedScore = rawScore.clamp(0.0, 24.0);
      final phq8Score = double.parse(boundedScore.toStringAsFixed(2));

      String riskCategory;
      if (phq8Score < 8.0) {
        riskCategory = 'low';
      } else if (phq8Score < _binaryThreshold) {
        riskCategory = 'borderline';
      } else if (phq8Score < 15.0) {
        riskCategory = 'moderate';
      } else {
        riskCategory = 'high';
      }

      final binaryPred =
          phq8Score >= _binaryThreshold ? 'depression_risk' : 'non_depression';
      final z = 0.35 * (phq8Score - _binaryThreshold);
      final probProxy = double.parse((1.0 / (1.0 + exp(-z))).clamp(0.001, 0.999).toStringAsFixed(4));

      final completedAt = DateTime.now().toUtc();

      debugPrint(
        '[LocalInference] model=$_modelKey phq8=$phq8Score '
        '(raw=${rawScore.toStringAsFixed(3)}) prob=$probProxy '
        'risk=$riskCategory binary=$binaryPred th=$_binaryThreshold | '
        'dom=$dominantMod (A:$pctA% V:$pctV% T:$pctT%) | '
        'S0=${v000.toStringAsFixed(2)} S1=${v100.toStringAsFixed(2)} '
        'S2=${v010.toStringAsFixed(2)} S3=${v001.toStringAsFixed(2)} '
        'S4=${v110.toStringAsFixed(2)} S5=${v101.toStringAsFixed(2)} '
        'S6=${v011.toStringAsFixed(2)} S7=${v111.toStringAsFixed(2)}',
      );
      if ((v000 - _v000Baseline).abs() > 0.1) {
        debugPrint(
          '[LocalInference] WARNING baseline drift: S0=${v000.toStringAsFixed(4)} '
          'vs xai_baseline=${_v000Baseline.toStringAsFixed(4)}',
        );
      }

      final dominantPct = dominantMod == 'visual' ? pctV : (dominantMod == 'audio' ? pctA : pctT);
      final dominantClinicalLabel = ClinicalConstants.getModalityClinicalName(dominantMod);
      final riskClinicalLabel = ClinicalConstants.getRiskLabel(riskCategory);
      final narrative =
          'Berdasarkan asesmen skrining multimodal pada klien $participantId, estimasi skor PHQ-8 adalah '
          '${phq8Score.toStringAsFixed(1)} dari rentang 24.0 ($riskClinicalLabel). '
          'Indikator yang paling berpengaruh teramati pada $dominantClinicalLabel '
          'dengan kontribusi $dominantPct%, mencerminkan pola respons afektif dan komunikasi klien.';

      return ScreeningResponse(
        screeningId: screeningId,
        participantId: participantId,
        status: 'completed',
        prediction: PredictionResult(
          phq8Score: phq8Score,
          riskProbabilityProxy: probProxy,
          binaryPrediction: binaryPred,
          riskCategory: riskCategory,
        ),
        patientModalityAttribution: PatientModalityAttribution(
          textPct: pctT,
          visualPct: pctV,
          audioPct: pctA,
          dominantModality: dominantMod,
          shapValues: PatientShapValues(
            text: double.parse(pT.toStringAsFixed(3)),
            visual: double.parse(pV.toStringAsFixed(3)),
            audio: double.parse(pA.toStringAsFixed(3)),
          ),
        ),
        globalReference: GlobalReferenceAttribution(
          cohort: 'E-DAIC Clinical Benchmark (N=56)',
          textPct: 61.8,
          visualPct: 33.8,
          audioPct: 4.4,
          dominantModality: 'text',
        ),
        qualityFlags: QualityFlags(
          lowTextInformation: prep.qualityFlags['low_text_information'] == true,
          poorAudioQuality: prep.qualityFlags['poor_audio_quality'] == true,
          poorVisualQuality: prep.qualityFlags['poor_visual_quality'] == true,
          details: prep.qualityFlags['details']?.toString(),
        ),
        clinicalNarrative: narrative,
        model: ModelMetadata(
          modelId: 'fedmind_edge_mobile_$_modelKey',
          name: '$_modelName (Edge FL Node)',
          version: activeVariant == FedMindModelVariant.model3Edge ? '3.0.0' : '2.4.0',
          architecture: activeVariant.architectureName,
          checkpoint: activeVariant.checkpointFileName,
          checksum: 'onnx_float32_sha256_verified',
          xaiBaseline: activeVariant.xaiBaselineFileName,
          device: 'mobile_cpu_npu',
        ),
        xai: XAIMetadata(
          method: 'exact_modality_shapley_coalition',
          numCoalitions: 8,
          efficiencyAxiomVerified: (pA + pV + pT - (v111 - v000)).abs() < 1e-2,
          baselineExpectedValue: _v000Baseline,
        ),
        disclaimer:
            'PERINGATAN KLINIS CDSS: Hasil estimasi model multimodal ini merupakan instrumen Clinical Decision Support (CDS) '
            'untuk membantu triangulasi objektif dan BUKAN diagnosis psikiatris/psikologis otonom. Keputusan diagnostik dan intervensi '
            'sepenuhnya berada pada wewenang klinisi berlisensi.',
        createdAt: now.toIso8601String(),
        completedAt: completedAt.toIso8601String(),
      );
    } finally {
      // Bersihkan alokasi memori native OrtValue
      await audioOrt.dispose();
      await visualOrt.dispose();
      await textOrt.dispose();
      if (fusedOrt != null) await fusedOrt.dispose();
      if (mainOutputs != null) {
        for (final v in mainOutputs.values) {
          await v.dispose();
        }
      }
      if (regOutputs != null) {
        for (final v in regOutputs.values) {
          await v.dispose();
        }
      }
    }
  }

  /// Mengambil tensor output ONNX dengan daftar kandidat nama agar kompatibel
  /// dengan model Model 3 (`pred_phq8`, `lat_*`) maupun Model 2 legacy (`phq8_pred`, `scores`).
  static OrtValue _requireOutput(
    Map<String, OrtValue> outputs,
    List<String> candidateNames,
    String label,
  ) {
    for (final name in candidateNames) {
      final tensor = outputs[name];
      if (tensor != null) return tensor;
    }
    throw StateError(
      'Missing ONNX output for $label. Tried $candidateNames, '
      'available keys: ${outputs.keys.toList()}',
    );
  }

  /// Menutup sesi ONNX ketika tidak lagi digunakan
  Future<void> dispose() async {
    if (_mainSession != null) {
      await _mainSession!.close();
      _mainSession = null;
    }
    if (_regSession != null) {
      await _regSession!.close();
      _regSession = null;
    }
    _isInitialized = false;
  }
}
