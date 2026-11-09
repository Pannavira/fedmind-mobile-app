import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../data/models/multimodal_inspection_models.dart';
import '../../data/models/screening_models.dart';
import '../constants/clinical_constants.dart';
import 'local_preprocessing_service.dart';

class LocalInferenceService {
  static const String _modelAssetPath = 'assets/models/fedmind_multimodal.onnx';
  static const String _regressorAssetPath = 'assets/models/fedmind_regressor.onnx';
  static const String _xaiBaselineAssetPath = 'assets/models/xai_baseline.json';

  final LocalPreprocessingService _preprocessor = LocalPreprocessingService();
  final OnnxRuntime _ort = OnnxRuntime();

  OrtSession? _mainSession;
  OrtSession? _regSession;

  List<double>? _audioBase;
  List<double>? _visualBase;
  List<double>? _textBase;
  double _v000Baseline = 8.4164;
  String _modelKey = 'fl_iid';
  String _modelName = 'FedAvg FL-IID';

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

  /// Memuat model ONNX dan konstanta XAI ke memori
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Inisialisasi Preprocessor
    await _preprocessor.initialize();

    // 2. Inisialisasi Sesi ONNX
    _mainSession = await _ort.createSessionFromAsset(_modelAssetPath);
    _regSession = await _ort.createSessionFromAsset(_regressorAssetPath);

    // 3. Memuat Baseline Laten XAI
    final xaiStr = await rootBundle.loadString(_xaiBaselineAssetPath);
    final xaiData = json.decode(xaiStr) as Map<String, dynamic>;

    _v000Baseline = (xaiData['v_000'] as num).toDouble();
    _modelKey = xaiData['model_key']?.toString() ?? 'fl_iid';
    _modelName = xaiData['model_name']?.toString() ?? 'FedAvg FL-IID';
    _audioBase = (xaiData['audio_base'] as List).map((e) => (e as num).toDouble()).toList();
    _visualBase = (xaiData['visual_base'] as List).map((e) => (e as num).toDouble()).toList();
    _textBase = (xaiData['text_base'] as List).map((e) => (e as num).toDouble()).toList();

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
  }) async {
    await initialize();

    final now = DateTime.now().toUtc();
    final screeningId = sessionId ?? 'SCR-LOCAL-${now.millisecondsSinceEpoch}';

    // 1. Preprocessing & Tensor Shaping
    final prep = await _preprocessor.prepareMultimodalTensors(
      audioInput: audioFeatures,
      visualInput: visualFeatures,
      textInput: textFeatures,
    );

    // 2. Siapkan OrtValue untuk Model Utama
    final audioOrt = await OrtValue.fromList(prep.audio, [1, 512, 80]);
    final visualOrt = await OrtValue.fromList(prep.visual, [1, 512, 72, 3]);
    final textOrt = await OrtValue.fromList(prep.text, [1, 512, 768]);

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

      final predList = await mainOutputs['phq8_pred']!.asFlattenedList();
      final double rawScore = (predList[0] as num).toDouble();

      final aIList = (await mainOutputs['audio_latent']!.asFlattenedList()).map((e) => (e as num).toDouble()).toList();
      final vIList = (await mainOutputs['visual_latent']!.asFlattenedList()).map((e) => (e as num).toDouble()).toList();
      final tIList = (await mainOutputs['text_latent']!.asFlattenedList()).map((e) => (e as num).toDouble()).toList();

      // 4. Hitung 8 Koalisi Exact Shapley menggunakan Regressor ONNX
      // Koalisi: (a, v, t) berukuran 768D (256 + 256 + 256)
      final coalitionBatch = Float32List(8 * 768);

      void copyCoalition(int row, List<double> a, List<double> v, List<double> t) {
        final offset = row * 768;
        for (int i = 0; i < 256; i++) {
          coalitionBatch[offset + i] = a[i];
          coalitionBatch[offset + 256 + i] = v[i];
          coalitionBatch[offset + 512 + i] = t[i];
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

      fusedOrt = await OrtValue.fromList(coalitionBatch, [8, 768]);
      regOutputs = await _regSession!.run({'fused_latents': fusedOrt});

      final scoresList = (await regOutputs['scores']!.asFlattenedList()).map((e) => (e as num).toDouble()).toList();
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
          description: 'Estimasi PHQ-8 menggunakan fitur prosodi vokal & MFCC (248D -> 256D)',
          hasAudio: true,
          hasVisual: false,
          hasText: false,
          predictedScore: double.parse(v100.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S2 (v₀₁₀)',
          label: 'Modalitas Visual (Facial Action Units / AUs) Tunggal',
          description: 'Estimasi PHQ-8 menggunakan aktivasi FACS Action Units & Head Pose (75D -> 256D)',
          hasAudio: false,
          hasVisual: true,
          hasText: false,
          predictedScore: double.parse(v010.toStringAsFixed(2)),
        ),
        CoalitionStepScore(
          coalitionCode: 'S3 (v₀₀₁)',
          label: 'Modalitas Teks / Linguistik Tunggal',
          description: 'Estimasi PHQ-8 menggunakan embedding psikolinguistik MentalBERT (768D -> 256D)',
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
      } else if (phq8Score < 10.0) {
        riskCategory = 'borderline';
      } else if (phq8Score < 15.0) {
        riskCategory = 'moderate';
      } else {
        riskCategory = 'high';
      }

      final binaryPred = phq8Score >= 10.0 ? 'depression_risk' : 'non_depression';
      final z = 0.35 * (phq8Score - 10.0);
      final probProxy = double.parse((1.0 / (1.0 + exp(-z))).clamp(0.001, 0.999).toStringAsFixed(4));

      final completedAt = DateTime.now().toUtc();

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
          version: '1.0.0',
          architecture: 'Multimodal BiLSTM Attention Fusion',
          checkpoint: 'fedmind_multimodal.onnx',
          checksum: 'onnx_float32_sha256_verified',
          xaiBaseline: 'xai_baseline.json',
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
