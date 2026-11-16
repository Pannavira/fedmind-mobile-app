import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fedmind_mobile_app/core/constants/edaic_interview_protocol.dart';

void main() {
  group('EdaicInterviewProtocol PHQ-8 Indonesian Tests', () {
    test('contains exactly 8 complete PHQ-8 questions numbered 1 to 8 in Indonesian', () {
      final questions = EdaicInterviewProtocol.questions;
      expect(questions.length, equals(8));

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        expect(q.id, isNotEmpty);
        expect(q.number, equals(i + 1));
        expect(q.phq8ItemNumber, equals(i + 1));
        expect(q.category, isNotEmpty);
        expect(q.phq8Dimension, isNotEmpty);
        expect(q.questionIndonesian, isNotEmpty);
        expect(q.phq8Badge, contains('PHQ-8 #${i + 1}'));
      }

      // Verifikasi seluruh 8 dimensi PHQ-8 dataset (1..8) tercakup berurutan
      final phqNumbers = questions.map((q) => q.phq8ItemNumber).toList();
      expect(phqNumbers, equals([1, 2, 3, 4, 5, 6, 7, 8]));
    });

    test('duration bounds return expected single-protocol defaults', () {
      expect(EdaicInterviewProtocol.recommendedMinDurationSec, equals(60));
      expect(EdaicInterviewProtocol.maxReferenceDurationSec, equals(120));
    });

    test('EdaicQuestion phq8Badge formats cleanly in Indonesian', () {
      const qPhq = EdaicQuestion(
        id: 'test_phq',
        number: 2,
        category: 'Suasana Hati',
        phq8ItemNumber: 2,
        phq8Dimension: 'Perasaan Murung',
        questionIndonesian: 'Pertanyaan tes',
        icon: Icons.help_outline,
      );
      expect(qPhq.phq8Badge, equals('PHQ-8 #2 • Perasaan Murung'));
    });
  });
}
