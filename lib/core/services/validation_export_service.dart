import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../../data/models/screening_models.dart';

class ValidationSummaryStats {
  final int totalRecords;
  final int verifiedCount;
  final int concordantCount;
  final double? concordanceRatePct;
  final double? mae;
  final double? rmse;
  final double? meanBias;

  const ValidationSummaryStats({
    required this.totalRecords,
    required this.verifiedCount,
    required this.concordantCount,
    this.concordanceRatePct,
    this.mae,
    this.rmse,
    this.meanBias,
  });
}

/// Menghasilkan metrik validasi ahli (MAE, RMSE, Konkordansi) dan ekspor dataset teranonimisasi (CSV / JSON)
/// untuk keperluan analisis klinis penelitian Fed-Mind Model 3.
class ValidationExportService {
  static const List<String> phq8ItemKeys = [
    'q1_anhedonia',
    'q2_depressed_mood',
    'q3_sleep',
    'q4_fatigue',
    'q5_appetite',
    'q6_worthlessness',
    'q7_concentration',
    'q8_psychomotor',
  ];

  static ValidationSummaryStats computeMetrics(List<ScreeningResponse> records) {
    final verifiedPairs = <({double pred, double gt, String status})>[];
    for (final r in records) {
      final ver = r.clinicalVerification;
      final pred = r.prediction;
      if (ver != null && ver.isVerified && pred != null) {
        verifiedPairs.add((
          pred: pred.phq8Score,
          gt: ver.groundTruthPhq8,
          status: ver.concordanceStatus,
        ));
      }
    }
    return _computeStatsFromPairs(records.length, verifiedPairs);
  }

  static ValidationSummaryStats computeMetricsFromSummary(
    List<ScreeningSummaryItem> items,
  ) {
    final verifiedPairs = <({double pred, double gt, String status})>[];
    for (final item in items) {
      if (item.isVerified &&
          item.phq8Score != null &&
          item.groundTruthPhq8 != null) {
        verifiedPairs.add((
          pred: item.phq8Score!,
          gt: item.groundTruthPhq8!,
          status: item.concordanceStatus ?? '',
        ));
      }
    }
    return _computeStatsFromPairs(items.length, verifiedPairs);
  }

  static ValidationSummaryStats _computeStatsFromPairs(
    int totalRecords,
    List<({double pred, double gt, String status})> verifiedPairs,
  ) {
    if (verifiedPairs.isEmpty) {
      return ValidationSummaryStats(
        totalRecords: totalRecords,
        verifiedCount: 0,
        concordantCount: 0,
      );
    }

    int concordant = 0;
    double absErrSum = 0.0;
    double sqErrSum = 0.0;
    double biasSum = 0.0;

    for (final p in verifiedPairs) {
      final status = p.status.toLowerCase();
      if (status == 'valid' || status == 'concordant') {
        concordant++;
      }
      final err = p.pred - p.gt;
      biasSum += err;
      absErrSum += err.abs();
      sqErrSum += err * err;
    }

    final n = verifiedPairs.length;
    return ValidationSummaryStats(
      totalRecords: totalRecords,
      verifiedCount: n,
      concordantCount: concordant,
      concordanceRatePct: (concordant / n) * 100.0,
      mae: absErrSum / n,
      rmse: sqrt(sqErrSum / n),
      meanBias: biasSum / n,
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.map((p) => p[0].toUpperCase()).join('.');
  }

  static List<Map<String, dynamic>> buildAnonymizedRecords(
    List<ScreeningResponse> records,
  ) {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final pred = r.prediction;
      final attr = r.patientModalityAttribution;
      final ver = r.clinicalVerification;
      final flags = r.qualityFlags;
      final anonId = 'SUBJ_${(i + 1).toString().padLeft(3, '0')}';

      final row = <String, dynamic>{
        'anonymized_id': anonId,
        'screening_id': r.screeningId,
        'created_at': r.createdAt ?? '',
        'model_version': r.model?.version ?? '3.0.0',
        'model_checkpoint': r.model?.checkpoint ?? 'fedmind_edge_client.onnx',
        'predicted_phq8': pred?.phq8Score,
        'predicted_risk_category': pred?.riskCategory ?? '',
        'threshold_9_4_positive': pred != null ? pred.phq8Score >= 9.4 : null,
        'shap_audio': attr?.shapValues.audio,
        'shap_visual': attr?.shapValues.visual,
        'shap_text': attr?.shapValues.text,
        'audio_pct': attr?.audioPct,
        'visual_pct': attr?.visualPct,
        'text_pct': attr?.textPct,
        'dominant_modality': attr?.dominantModality ?? '',
        'low_text_flag': flags?.lowTextInformation ?? false,
        'poor_audio_flag': flags?.poorAudioQuality ?? false,
        'poor_visual_flag': flags?.poorVisualQuality ?? false,
        'is_verified': ver?.isVerified ?? false,
        'concordance_status': ver?.concordanceStatus ?? '',
        'ground_truth_phq8': ver?.groundTruthPhq8,
        'deviation_delta': ver?.deviationDelta,
        'visual_plausible': ver?.visualPlausible,
        'audio_plausible': ver?.audioPlausible,
        'text_plausible': ver?.textPlausible,
        'validator_role': ver?.validatorRole ?? '',
        'validator_initials': _initials(ver?.validatorName),
        'verified_at': ver?.verifiedAt ?? '',
      };

      for (final key in phq8ItemKeys) {
        row['phq8_$key'] = ver?.phq8ItemScores?[key];
      }
      out.add(row);
    }
    return out;
  }

  static String buildAnonymizedCsv(List<ScreeningResponse> records) {
    final rows = buildAnonymizedRecords(records);
    final headers = <String>[
      'anonymized_id',
      'screening_id',
      'created_at',
      'model_version',
      'predicted_phq8',
      'predicted_risk_category',
      'threshold_9_4_positive',
      'shap_audio',
      'shap_visual',
      'shap_text',
      'audio_pct',
      'visual_pct',
      'text_pct',
      'dominant_modality',
      'low_text_flag',
      'poor_audio_flag',
      'poor_visual_flag',
      'is_verified',
      'concordance_status',
      'ground_truth_phq8',
      'deviation_delta',
      ...phq8ItemKeys.map((k) => 'phq8_$k'),
      'visual_plausible',
      'audio_plausible',
      'text_plausible',
      'validator_role',
      'validator_initials',
      'verified_at',
    ];

    String csvCell(Object? value) {
      if (value == null) return '';
      final s = value is double ? value.toStringAsFixed(4) : value.toString();
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    final buf = StringBuffer();
    buf.writeln(headers.join(','));
    for (final row in rows) {
      buf.writeln(headers.map((h) => csvCell(row[h])).join(','));
    }
    return buf.toString();
  }

  static String buildAnonymizedJson(List<ScreeningResponse> records) {
    final metrics = computeMetrics(records);
    final payload = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
      'protocol': 'Fed-Mind Model 3 Clinical Validation (PHQ-8 cut-off >= 9.4)',
      'anonymization_note':
          'Client names, raw file paths, and verbatim transcripts/SOAP text omitted.',
      'summary_metrics': {
        'total_records': metrics.totalRecords,
        'verified_count': metrics.verifiedCount,
        'concordant_count': metrics.concordantCount,
        'concordance_rate_pct': metrics.concordanceRatePct,
        'mae': metrics.mae,
        'rmse': metrics.rmse,
        'mean_bias': metrics.meanBias,
      },
      'records': buildAnonymizedRecords(records),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<File> saveExportToAppDocuments({
    required String content,
    required String extension,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/validation_exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${exportDir.path}/fedmind_validation_$ts.$extension');
    return file.writeAsString(content);
  }
}
