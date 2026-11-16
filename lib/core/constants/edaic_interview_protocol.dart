import 'package:material_ui/material_ui.dart';

/// Model pertanyaan wawancara skrining klinis PHQ-8 dalam Bahasa Indonesia
class EdaicQuestion {
  final String id;
  final int number;
  final String category;
  final int phq8ItemNumber;
  final String phq8Dimension;
  final String questionIndonesian;
  final IconData icon;
  final int recommendedDurationSec;

  const EdaicQuestion({
    required this.id,
    required this.number,
    required this.category,
    required this.phq8ItemNumber,
    required this.phq8Dimension,
    required this.questionIndonesian,
    required this.icon,
    this.recommendedDurationSec = 10,
  });

  /// Label ringkas dimensi PHQ-8 untuk UI
  String get phq8Badge => 'PHQ-8 #$phq8ItemNumber • $phq8Dimension';
}

/// Protokol Tunggal 8 Pertanyaan PHQ-8 (Sesuai 8 Butir Dataset PHQ-8)
class EdaicInterviewProtocol {
  /// Rekomendasi total durasi minimum perekaman (detik)
  static const int recommendedMinDurationSec = 60;

  /// Rekomendasi durasi referensi maksimum sebelum pengingat non-blocking (detik)
  static const int maxReferenceDurationSec = 120;

  /// Daftar 8 Pertanyaan Baku PHQ-8 (Item #1 s/d #8) dalam Bahasa Indonesia sederhana
  static const List<EdaicQuestion> questions = [
    EdaicQuestion(
      id: 'phq8_q1_no_interest',
      number: 1,
      category: 'Minat & Kesenangan',
      phq8ItemNumber: 1,
      phq8Dimension: 'Kurang Minat / Kesenangan',
      questionIndonesian:
          'Dalam 2 minggu terakhir, bagaimana minat Anda untuk melakukan kegiatan atau hobi yang biasanya disukai?',
      icon: Icons.interests_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q2_depressed',
      number: 2,
      category: 'Suasana Hati',
      phq8ItemNumber: 2,
      phq8Dimension: 'Perasaan Murung, Sedih, atau Putus Asa',
      questionIndonesian:
          'Apakah Anda sering merasa murung, sedih, atau putus asa? Ceritakan singkat apa yang Anda rasakan.',
      icon: Icons.sentiment_dissatisfied_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q3_sleep',
      number: 3,
      category: 'Pola Tidur',
      phq8ItemNumber: 3,
      phq8Dimension: 'Sulit Tidur atau Terlalu Banyak Tidur',
      questionIndonesian:
          'Bagaimana tidur Anda belakangan ini—apakah sulit tidur, sering terbangun, atau terlalu banyak tidur?',
      icon: Icons.bedtime_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q4_tired',
      number: 4,
      category: 'Energi & Lelah',
      phq8ItemNumber: 4,
      phq8Dimension: 'Merasa Lelah atau Kurang Bertenaga',
      questionIndonesian:
          'Apakah Anda sering merasa lelah, lesu, atau kurang bertenaga saat beraktivitas?',
      icon: Icons.battery_alert_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q5_appetite',
      number: 5,
      category: 'Nafsu Makan',
      phq8ItemNumber: 5,
      phq8Dimension: 'Kurang Nafsu Makan atau Makan Berlebihan',
      questionIndonesian:
          'Bagaimana nafsu makan Anda belakangan ini—apakah berkurang drastis atau justru makan berlebihan?',
      icon: Icons.restaurant_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q6_failure',
      number: 6,
      category: 'Penilaian Diri',
      phq8ItemNumber: 6,
      phq8Dimension: 'Merasa Gagal atau Mengecewakan',
      questionIndonesian:
          'Apakah Anda merasa kurang percaya diri, merasa gagal, atau mengecewakan diri maupun keluarga?',
      icon: Icons.psychology_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q7_concentration',
      number: 7,
      category: 'Konsentrasi',
      phq8ItemNumber: 7,
      phq8Dimension: 'Kesulitan Berkonsentrasi',
      questionIndonesian:
          'Apakah Anda sulit berkonsentrasi atau fokus saat membaca, belajar, atau bekerja?',
      icon: Icons.center_focus_strong_rounded,
      recommendedDurationSec: 10,
    ),
    EdaicQuestion(
      id: 'phq8_q8_psychomotor',
      number: 8,
      category: 'Gerak & Bicara',
      phq8ItemNumber: 8,
      phq8Dimension: 'Perubahan Gerak atau Bicara (Psikomotor)',
      questionIndonesian:
          'Apakah Anda merasa bergerak atau berbicara lebih lambat dari biasa, atau justru sangat gelisah?',
      icon: Icons.directions_run_rounded,
      recommendedDurationSec: 10,
    ),
  ];
}
