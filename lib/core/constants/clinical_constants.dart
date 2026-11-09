import 'package:flutter/material.dart';

class ClinicalConstants {
  // PHQ-8 Thresholds according to Fed-Mind research protocol
  static const double scoreLowMax = 7.99;
  static const double scoreBorderlineMin = 8.0;
  static const double scoreBorderlineMax = 9.99;
  static const double scoreModerateMin = 10.0;
  static const double scoreModerateMax = 14.99;
  static const double scoreHighMin = 15.0;
  static const double scoreMax = 24.0;

  // Official Clinical Workstation Palette
  static const Color clinicalTeal = Color(0xFF0D9488);
  static const Color deepSlate = Color(0xFF0F172A);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color softBackground = Color(0xFFF8FAFC);

  // Official Clinical Risk Indicator Colors
  static const Color riskLowColor = Color(0xFF10B981); // Emerald
  static const Color riskBorderlineColor = Color(0xFFF59E0B); // Amber
  static const Color riskModerateColor = Color(0xFFF97316); // Orange
  static const Color riskHighColor = Color(0xFFEF4444); // Crimson

  static const Color riskLow = riskLowColor;
  static const Color riskBorderline = riskBorderlineColor;
  static const Color riskModerate = riskModerateColor;
  static const Color riskHigh = riskHighColor;

  // Modality colors for XAI Charts
  static const Color textModalityColor = Color(0xFF3B82F6); // Blue
  static const Color visualModalityColor = Color(0xFF0D9488); // Clinical Teal
  static const Color audioModalityColor = Color(0xFF6366F1); // Indigo

  static Color getRiskColor(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return riskLowColor;
      case 'borderline':
        return riskBorderlineColor;
      case 'moderate':
        return riskModerateColor;
      case 'high':
        return riskHighColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  /// Standardized clinical risk stratification labels (PHQ-8 protocol)
  static String getRiskLabel(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Low Risk / Minimal (PHQ-8: 0–7)';
      case 'borderline':
        return 'Borderline (PHQ-8: 8–9)';
      case 'moderate':
        return 'Moderate Depressive Symptoms (PHQ-8: 10–14)';
      case 'high':
        return 'Severe Depressive Symptoms (PHQ-8: 15–24)';
      default:
        return 'Unclassified Clinical Risk';
    }
  }

  /// Concise clinical risk badge text
  static String getRiskShortBadge(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'LOW RISK (0–7)';
      case 'borderline':
        return 'BORDERLINE (8–9)';
      case 'moderate':
        return 'MODERATE (10–14)';
      case 'high':
        return 'SEVERE / HIGH (15–24)';
      default:
        return 'UNCLASSIFIED';
    }
  }

  /// Standardized clinical modality terminology
  static String getModalityClinicalName(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return 'Modalitas Teks / Linguistik';
      case 'visual':
        return 'Modalitas Visual (Facial Action Units / AUs)';
      case 'audio':
        return 'Modalitas Akustik / Prosodi Audio';
      default:
        return 'Fusi Multimodal (Visual, Akustik, Linguistik)';
    }
  }

  /// Compact clinical modality label for dense cards/tables
  static String getModalityCompactName(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return 'Modalitas Teks / Linguistik';
      case 'visual':
        return 'Modalitas Visual (Facial AUs)';
      case 'audio':
        return 'Modalitas Akustik / Prosodi Audio';
      default:
        return 'Multimodal Fusion';
    }
  }

  static IconData getModalityIcon(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return Icons.notes_rounded;
      case 'visual':
        return Icons.face_retouching_natural_rounded;
      case 'audio':
        return Icons.graphic_eq_rounded;
      default:
        return Icons.hub_outlined;
    }
  }

  static String getRiskDescription(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Estimasi skor PHQ-8 berada di bawah ambang klinis (< 8.0). Tidak terindikasi simtomatologi depresif mayor pada observasi multimodal.';
      case 'borderline':
        return 'Estimasi skor PHQ-8 pada rentang subklinis/borderline (8.0–9.9). Memerlukan pemantauan berkala dan evaluasi faktor stresor psikososial.';
      case 'moderate':
        return 'Estimasi skor PHQ-8 pada rentang 10.0–14.9 (Moderate Depressive Symptoms). Indikasi klinis positif yang memerlukan asesmen diagnostik mendalam dan intervensi psikoterapi terstruktur.';
      case 'high':
        return 'Estimasi skor PHQ-8 ≥ 15.0 (Severe Depressive Symptoms). Prioritas triase tinggi; lakukan evaluasi keselamatan klinis dan kolaborasi psikiatris segera.';
      default:
        return '-';
    }
  }

  /// Therapeutic intervention guidance for psychologists / clinical counselors
  static String getCounselingGuidance(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Pertahankan fungsi adaptif klien, dokumentasikan baseline afektif pada rekam medis, dan jadwalkan evaluasi preventif rutin bila diperlukan.';
      case 'borderline':
        return 'Eksplorasi stresor okupasional, interpersonal, dan pola tidur (sleep hygiene). Lakukan monitoring berkala (follow-up) dalam 2–4 minggu.';
      case 'moderate':
        return 'Inisiasi protokol psikoterapi berbasis bukti (CBT / Behavioral Activation / ACT). Evaluasi distorsi kognitif, anhedonia, serta hendaya fungsi harian.';
      case 'high':
        return 'Prioritaskan stabilisasi afektif dan asesmen risiko krisis/ideasi bunuh diri. Koordinasikan rujukan psikiatris untuk evaluasi medikamentosa dan intervensi intensif.';
      default:
        return 'Lakukan triangulasi observasi klinis sesuai pedoman asesmen psikologi klinis.';
    }
  }

  /// Concise action title for clinical counseling recommendation
  static String getCounselingActionTitle(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Observasi Baseline & Edukasi Preventif';
      case 'borderline':
        return 'Monitoring Klinis Berkala (Follow-Up 2–4 Minggu)';
      case 'moderate':
        return 'Intervensi Psikoterapi Terstruktur (CBT / ACT)';
      case 'high':
        return 'Triase Prioritas Tinggi & Rujukan Kolaborasi Psikiatri';
      default:
        return 'Evaluasi Klinis Standar';
    }
  }

  /// Labels for Model Concordance Status
  static String getConcordanceLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'valid':
      case 'concordant':
        return 'Sesuai / Valid';
      case 'overestimated':
        return 'Overestimated';
      case 'underestimated':
        return 'Underestimated';
      case 'artifact':
        return 'Artefak / False Indicator';
      default:
        return 'Belum Diverifikasi';
    }
  }

  static Color getConcordanceColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'valid':
      case 'concordant':
        return riskLowColor;
      case 'overestimated':
        return riskBorderlineColor;
      case 'underestimated':
        return riskModerateColor;
      case 'artifact':
        return riskHighColor;
      default:
        return const Color(0xFF64748B);
    }
  }
}
