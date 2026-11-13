import 'package:flutter/material.dart';

/// Model pertanyaan wawancara klinis semi-terstruktur selaras E-DAIC (DAIC-WOZ) dan PHQ-8
class EdaicQuestion {
  final String id;
  final int number;
  final String category;
  final int? phq8ItemNumber;
  final String phq8Dimension;
  final String questionIndonesian;
  final String questionEnglishEdaic;
  final String guidanceHint;
  final IconData icon;
  final int recommendedDurationSec;

  const EdaicQuestion({
    required this.id,
    required this.number,
    required this.category,
    this.phq8ItemNumber,
    required this.phq8Dimension,
    required this.questionIndonesian,
    required this.questionEnglishEdaic,
    required this.guidanceHint,
    required this.icon,
    this.recommendedDurationSec = 15,
  });

  /// Label badge PHQ-8 untuk UI
  String get phq8Badge {
    if (phq8ItemNumber != null) {
      return 'PHQ-8 Item #$phq8ItemNumber: $phq8Dimension';
    }
    return 'E-DAIC Protocol: $phq8Dimension';
  }
}

/// Mode protokol wawancara klinis saat perekaman
enum EdaicProtocolMode {
  /// 4 Pertanyaan Inti terpilih (optimal untuk durasi 45-60 detik)
  standard,

  /// 8 Pertanyaan Komprehensif (mencakup seluruh dimensi PHQ-8, durasi 60-90+ detik)
  comprehensive,
}

/// Protokol Wawancara Elisitasi Multimodal E-DAIC / PHQ-8
class EdaicInterviewProtocol {
  /// Daftar 4 Pertanyaan Inti (Standard Preset)
  static const List<EdaicQuestion> standardQuestions = [
    EdaicQuestion(
      id: 'std_q1_mood',
      number: 1,
      category: 'Mood & Afek Depresif',
      phq8ItemNumber: 2,
      phq8Dimension: 'Suasana Hati & Kesedihan',
      questionIndonesian:
          'Bagaimana suasana hati Anda dalam 2 minggu terakhir? Adakah hal yang membuat Anda merasa sedih, tertekan, atau terbebani?',
      questionEnglishEdaic:
          'How would you describe your mood lately? What are some things that make you feel down or overwhelmed?',
      guidanceHint:
          'Ceritakan secara terbuka mengenai beban perasaan atau perubahan suasana hati yang Anda alami belakangan ini.',
      icon: Icons.sentiment_dissatisfied_rounded,
      recommendedDurationSec: 15,
    ),
    EdaicQuestion(
      id: 'std_q2_anhedonia',
      number: 2,
      category: 'Anhedonia & Minat',
      phq8ItemNumber: 1,
      phq8Dimension: 'Kehilangan Minat & Kesenangan',
      questionIndonesian:
          'Apa yang biasanya Anda lakukan untuk bersantai atau menikmati waktu luang? Kapan terakhir kali Anda merasa sangat bahagia atau menikmati kegiatan tersebut?',
      questionEnglishEdaic:
          'What do you do to relax or enjoy yourself? When was the last time you felt really happy?',
      guidanceHint:
          'Ceritakan kegiatan menyenangkan Anda dan apakah rasa gembira saat melakukannya masih sama atau berkurang.',
      icon: Icons.celebration_rounded,
      recommendedDurationSec: 15,
    ),
    EdaicQuestion(
      id: 'std_q3_somatic',
      number: 3,
      category: 'Pola Tidur & Energi',
      phq8ItemNumber: 3,
      phq8Dimension: 'Ritme Sirkadian & Keletihan',
      questionIndonesian:
          'Bagaimana kemudahan Anda untuk tidur nyenyak di malam hari? Seperti apa tingkat energi dan stamina Anda saat menjalani aktivitas sehari-hari?',
      questionEnglishEdaic:
          'How easy is it for you to get a good night\'s sleep? What are you like when you don\'t get enough sleep?',
      guidanceHint:
          'Jelaskan apakah Anda mengalami insomnia, sering terbangun, atau merasa cepat lelah tanpa tenaga.',
      icon: Icons.bedtime_outlined,
      recommendedDurationSec: 15,
    ),
    EdaicQuestion(
      id: 'std_q4_self_worth',
      number: 4,
      category: 'Persepsi Diri & Koping',
      phq8ItemNumber: 6,
      phq8Dimension: 'Penilaian Diri & Mekanisme Koping',
      questionIndonesian:
          'Bagaimana Anda memandang diri Anda akhir-akhir ini? Apakah Anda merasa terlalu keras terhadap diri sendiri, dan bagaimana cara Anda menenangkan diri saat situasi terasa sulit?',
      questionEnglishEdaic:
          'How do you feel about yourself lately? Do you feel you\'re being too hard on yourself, and how do you cope?',
      guidanceHint:
          'Ungkapkan bagaimana perasaan Anda terhadap diri sendiri dan cara Anda mengelola kecemasan atau tekanan.',
      icon: Icons.psychology_rounded,
      recommendedDurationSec: 15,
    ),
  ];

  /// Daftar 8 Pertanyaan Komprehensif (Full 8 Dimensi PHQ-8 + E-DAIC Protocol)
  static const List<EdaicQuestion> comprehensiveQuestions = [
    EdaicQuestion(
      id: 'comp_q1_rapport',
      number: 1,
      category: 'Opening & Baseline',
      phq8ItemNumber: null,
      phq8Dimension: 'Pembentukan Baseline Afek & Prosodi',
      questionIndonesian:
          'Bagaimana kabar dan kondisi perasaan Anda hari ini? Ceritakan sedikit apa yang sedang Anda jalani atau rasakan saat ini.',
      questionEnglishEdaic:
          'How are you doing today? Tell me a little bit about what\'s been going on with you.',
      guidanceHint:
          'Jawab dengan rileks dan santai untuk mengkalibrasi nada suara dan ekspresi wajah awal.',
      icon: Icons.waving_hand_rounded,
      recommendedDurationSec: 12,
    ),
    EdaicQuestion(
      id: 'comp_q2_anhedonia',
      number: 2,
      category: 'Anhedonia & Minat',
      phq8ItemNumber: 1,
      phq8Dimension: 'Kurang Minat / Kegairahan',
      questionIndonesian:
          'Apa yang biasanya Anda lakukan untuk bersantai? Kapan terakhir kali Anda merasa sangat bahagia atau menikmati kegiatan tersebut?',
      questionEnglishEdaic:
          'What do you do to relax? When was the last time you felt really happy?',
      guidanceHint:
          'Ceritakan apakah Anda masih memiliki ketertarikan yang sama pada hobi atau kegiatan yang disukai.',
      icon: Icons.interests_rounded,
      recommendedDurationSec: 14,
    ),
    EdaicQuestion(
      id: 'comp_q3_mood',
      number: 3,
      category: 'Mood & Afek Depresif',
      phq8ItemNumber: 2,
      phq8Dimension: 'Perasaan Murung & Tertekan',
      questionIndonesian:
          'Bagaimana suasana hati Anda dalam 2 minggu terakhir? Adakah hal-hal yang membuat Anda merasa sedih, hampa, atau tertekan?',
      questionEnglishEdaic:
          'How would you describe your mood lately? What are some things that make you feel down?',
      guidanceHint:
          'Ceritakan suasana emosi dominan dan stresor yang membebani pikiran Anda belakangan ini.',
      icon: Icons.sentiment_dissatisfied_rounded,
      recommendedDurationSec: 15,
    ),
    EdaicQuestion(
      id: 'comp_q4_sleep',
      number: 4,
      category: 'Pola Tidur',
      phq8ItemNumber: 3,
      phq8Dimension: 'Gangguan Kualitas Tidur',
      questionIndonesian:
          'Bagaimana kemudahan Anda untuk tidur nyenyak di malam hari? Seperti apa kondisi fisik dan pikiran Anda jika Anda kurang tidur?',
      questionEnglishEdaic:
          'How easy is it for you to get a good night\'s sleep? What are you like when you don\'t sleep well?',
      guidanceHint:
          'Jelaskan apakah Anda kesulitan mengawali tidur, sering terbangun di tengah malam, atau tidur berlebihan.',
      icon: Icons.bedtime_rounded,
      recommendedDurationSec: 14,
    ),
    EdaicQuestion(
      id: 'comp_q5_fatigue',
      number: 5,
      category: 'Energi & Keletihan',
      phq8ItemNumber: 4,
      phq8Dimension: 'Rasa Lelah & Kehilangan Energi',
      questionIndonesian:
          'Bagaimana tingkat energi Anda dalam menjalani aktivitas harian? Apakah Anda merasa cepat lelah atau kekurangan stamina bahkan untuk hal-hal ringan?',
      questionEnglishEdaic:
          'How is your energy level throughout the day? Do you find yourself feeling constantly exhausted or drained?',
      guidanceHint:
          'Ceritakan apakah Anda merasa lesu, mengantuk di siang hari, atau tidak berdaya untuk memulai tugas.',
      icon: Icons.battery_alert_rounded,
      recommendedDurationSec: 14,
    ),
    EdaicQuestion(
      id: 'comp_q6_self_worth',
      number: 6,
      category: 'Persepsi Diri',
      phq8ItemNumber: 6,
      phq8Dimension: 'Rasa Bersalah & Penilaian Diri Rendah',
      questionIndonesian:
          'Bagaimana Anda memandang dan menilai diri Anda akhir-akhir ini? Apakah Anda merasa sering menyalahkan diri sendiri atau merasa telah mengecewakan orang lain?',
      questionEnglishEdaic:
          'How do you feel about yourself lately? Do you think that maybe you\'re being a little hard on yourself?',
      guidanceHint:
          'Ungkapkan apakah ada beban perasaan bersalah, rasa tidak berharga, atau keraguan berlebih pada diri sendiri.',
      icon: Icons.psychology_rounded,
      recommendedDurationSec: 15,
    ),
    EdaicQuestion(
      id: 'comp_q7_concentration',
      number: 7,
      category: 'Fungsi Kognitif',
      phq8ItemNumber: 7,
      phq8Dimension: 'Gangguan Konsentrasi & Fokus',
      questionIndonesian:
          'Apakah Anda mengalami kesulitan untuk fokus atau berkonsentrasi pada pekerjaan, bacaan, atau aktivitas sehari-hari?',
      questionEnglishEdaic:
          'Have you noticed any difficulty concentrating on things like work, reading, or everyday conversations?',
      guidanceHint:
          'Jelaskan jika pikiran Anda mudah teralihkan, melamun, atau membutuhkan waktu lebih lama untuk menyelesaikan sesuatu.',
      icon: Icons.center_focus_strong_rounded,
      recommendedDurationSec: 14,
    ),
    EdaicQuestion(
      id: 'comp_q8_support_coping',
      number: 8,
      category: 'Dukungan & Koping',
      phq8ItemNumber: null,
      phq8Dimension: 'Proteksi Sosial & Regulasi Emosi',
      questionIndonesian:
          'Siapa orang terdekat yang menjadi pengaruh positif bagi Anda, dan bagaimana cara Anda menenangkan diri saat situasi terasa sangat berat?',
      questionEnglishEdaic:
          'Who\'s someone that\'s been a positive influence in your life? How do you cope when things get difficult?',
      guidanceHint:
          'Ceritakan tentang sosok pendukung terdekat serta cara Anda menyalurkan emosi saat tertekan.',
      icon: Icons.handshake_rounded,
      recommendedDurationSec: 14,
    ),
  ];

  /// Mengambil daftar pertanyaan berdasarkan mode yang dipilih
  static List<EdaicQuestion> getQuestions(EdaicProtocolMode mode) {
    switch (mode) {
      case EdaicProtocolMode.standard:
        return standardQuestions;
      case EdaicProtocolMode.comprehensive:
        return comprehensiveQuestions;
    }
  }

  /// Rekomendasi total durasi minimum dalam detik berdasarkan mode
  static int getRecommendedMinDuration(EdaicProtocolMode mode) {
    switch (mode) {
      case EdaicProtocolMode.standard:
        return 45;
      case EdaicProtocolMode.comprehensive:
        return 60;
    }
  }

  /// Rekomendasi durasi maksimum dalam detik
  static int getMaxDuration(EdaicProtocolMode mode) {
    switch (mode) {
      case EdaicProtocolMode.standard:
        return 90;
      case EdaicProtocolMode.comprehensive:
        return 120;
    }
  }
}

