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

  // Clinical risk colors
  static const Color riskLowColor = Color(0xFF10B981); // Emerald Green
  static const Color riskBorderlineColor = Color(0xFFF59E0B); // Amber
  static const Color riskModerateColor = Color(0xFFF97316); // Orange
  static const Color riskHighColor = Color(0xFFEF4444); // Crimson Red

  // Modality colors for XAI Charts
  static const Color textModalityColor = Color(0xFF3B82F6); // Blue
  static const Color visualModalityColor = Color(0xFF8B5CF6); // Purple
  static const Color audioModalityColor = Color(0xFFEC4899); // Pink

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
        return const Color(0xFF6B7280); // Gray
    }
  }

  static String getRiskLabel(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Risiko Rendah (Non-Depression)';
      case 'borderline':
        return 'Borderline (Pengawasan Klinis)';
      case 'moderate':
        return 'Moderat (Indikasi Depresi)';
      case 'high':
        return 'Tinggi (Depresi Berat)';
      default:
        return 'Tidak Terdefinisi';
    }
  }

  static String getRiskDescription(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Skor berada di bawah ambang batas klinis 8.0. Pasien tidak terindikasi depresi mayor.';
      case 'borderline':
        return 'Skor berada pada rentang 8.0 – 9.9. Berada di zona batas yang memerlukan observasi klinis berkala.';
      case 'moderate':
        return 'Skor berada pada rentang 10.0 – 14.9. Terindikasi gejala depresi yang memerlukan asesmen lanjutan.';
      case 'high':
        return 'Skor >= 15.0. Terindikasi depresi berat dan disarankan untuk evaluasi psikiatri sesegera mungkin.';
      default:
        return '-';
    }
  }

  /// Rekomendasi tindakan terapeutik bagi psikolog / konselor klinis
  static String getCounselingGuidance(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Fasilitasi psikoedukasi kesehatan mental promotif, eksplorasi sumber daya koping adaptif pasien, dan pertahankan rutinitas pemulihan.';
      case 'borderline':
        return 'Eksplorasi pemicu stres subklinis (pekerjaan, hubungan, kualitas tidur). Lakukan pemantauan aktif dan jadwalkan evaluasi tindak lanjut dalam 2–4 minggu.';
      case 'moderate':
        return 'Inisiasi protokol psikoterapi terstruktur (seperti CBT atau ACT). Evaluasi distorsi kognitif, anhedonia, dan disabilitas fungsi harian pasien.';
      case 'high':
        return 'Prioritaskan stabilisasi afektif dan asesmen keselamatan krisis (risiko bunuh diri/self-harm). Segera koordinasikan rujukan ke psikiater untuk evaluasi komprehensif.';
      default:
        return 'Lakukan observasi klinis holistik dan sesuaikan dengan riwayat afektif pasien.';
    }
  }

  /// Judul singkat rekomendasi tindakan konseling
  static String getCounselingActionTitle(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Konseling Promotif & Penguatan Resiliensi';
      case 'borderline':
        return 'Observasi Klinis & Konseling Berkala';
      case 'moderate':
        return 'Intervensi Terapi Terstruktur (CBT/ACT)';
      case 'high':
        return 'Prioritas Tinggi / Kolaborasi Psikiatri';
      default:
        return 'Observasi Klinis Umum';
    }
  }
}
