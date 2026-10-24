import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class SamplePatientData {
  /// Memuat fitur asli Participant P600 (Golden Case: Skor 9.69, Borderline, Visual Dominant)
  static Future<Map<String, dynamic>> loadP600Features() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/samples/p600_features.json');
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      // Fallback synthetic jika file asset gagal dibaca
      return generateSyntheticFeatures(participantId: 'P600_FALLBACK');
    }
  }

  /// Generator fitur sintetis acak untuk pengujian variasi input
  static Map<String, dynamic> generateSyntheticFeatures({
    required String participantId,
    bool simulateAbnormalAudio = false,
  }) {
    final random = Random();
    
    // Text: 768 float
    final text = List.generate(768, (_) => (random.nextDouble() * 2 - 1) * 0.3);
    
    // Audio: 248 float
    final audio = simulateAbnormalAudio
        ? List.generate(248, (_) => 0.0) // Poor audio flag test
        : List.generate(248, (_) => (random.nextDouble() * 2 - 1) * 0.5);

    // Visual: 75 float
    final visual = List.generate(75, (_) => (random.nextDouble() * 2 - 1) * 0.4);

    return {
      'participant_id': participantId,
      'text_features': text,
      'audio_features': audio,
      'visual_features': visual,
      'metadata': {
        'source': 'FED-MIND Flutter App Synthetic Generator',
        'timestamp': DateTime.now().toIso8601String(),
      }
    };
  }
}
