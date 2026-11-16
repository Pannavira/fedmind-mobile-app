import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/constants/edaic_interview_protocol.dart';

void main() {
  group('EdaicInterviewProtocol Protocol & Model Tests', () {
    test('Standard preset contains 4 well-formed PHQ-8 aligned questions', () {
      final questions = EdaicInterviewProtocol.standardQuestions;
      expect(questions.length, equals(4));

      for (final q in questions) {
        expect(q.id, isNotEmpty);
        expect(q.number, isPositive);
        expect(q.category, isNotEmpty);
        expect(q.phq8Dimension, isNotEmpty);
        expect(q.questionIndonesian, isNotEmpty);
        expect(q.questionEnglishEdaic, isNotEmpty);
        expect(q.guidanceHint, isNotEmpty);
        expect(q.phq8Badge, contains('PHQ-8'));
      }

      // Memastikan dimensi kunci PHQ-8 tercakup pada protokol standar
      final phqNumbers = questions.map((q) => q.phq8ItemNumber).toList();
      expect(phqNumbers, contains(1)); // Anhedonia
      expect(phqNumbers, contains(2)); // Mood & Afek
      expect(phqNumbers, contains(3)); // Sleep
      expect(phqNumbers, contains(6)); // Self-worth
    });

    test('Comprehensive preset contains 8 complete E-DAIC / PHQ-8 dimensions', () {
      final questions = EdaicInterviewProtocol.comprehensiveQuestions;
      expect(questions.length, equals(8));

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        expect(q.number, equals(i + 1));
        expect(q.questionIndonesian, isNotEmpty);
        expect(q.questionEnglishEdaic, isNotEmpty);
        expect(q.guidanceHint, isNotEmpty);
      }

      // Verifikasi ketercakupan item PHQ-8
      final phqNumbers = questions
          .map((q) => q.phq8ItemNumber)
          .where((itemNum) => itemNum != null)
          .toList();

      expect(phqNumbers, contains(1)); // Anhedonia
      expect(phqNumbers, contains(2)); // Mood
      expect(phqNumbers, contains(3)); // Sleep
      expect(phqNumbers, contains(4)); // Fatigue
      expect(phqNumbers, contains(6)); // Guilt/Self-worth
      expect(phqNumbers, contains(7)); // Concentration
    });

    test('Protocol mode selector and duration helpers return accurate bounds', () {
      final stdQuestions =
          EdaicInterviewProtocol.getQuestions(EdaicProtocolMode.standard);
      final compQuestions =
          EdaicInterviewProtocol.getQuestions(EdaicProtocolMode.comprehensive);

      expect(stdQuestions.length, equals(4));
      expect(compQuestions.length, equals(8));

      expect(
        EdaicInterviewProtocol.getRecommendedMinDuration(
            EdaicProtocolMode.standard),
        equals(45),
      );
      expect(
        EdaicInterviewProtocol.getMaxDuration(EdaicProtocolMode.standard),
        equals(90),
      );

      expect(
        EdaicInterviewProtocol.getRecommendedMinDuration(
            EdaicProtocolMode.comprehensive),
        equals(60),
      );
      expect(
        EdaicInterviewProtocol.getMaxDuration(EdaicProtocolMode.comprehensive),
        equals(120),
      );
    });

    test('EdaicQuestion phq8Badge formats correctly for both PHQ-8 and Protocol items', () {
      const qPhq = EdaicQuestion(
        id: 'test_phq',
        number: 1,
        category: 'Test Category',
        phq8ItemNumber: 2,
        phq8Dimension: 'Suasana Hati',
        questionIndonesian: 'Pertanyaan tes',
        questionEnglishEdaic: 'Test question',
        guidanceHint: 'Petunjuk tes',
        icon: Icons.help_outline,
      );
      expect(qPhq.phq8Badge, equals('PHQ-8 Item #2: Suasana Hati'));

      const qProtocol = EdaicQuestion(
        id: 'test_protocol',
        number: 1,
        category: 'Baseline',
        phq8ItemNumber: null,
        phq8Dimension: 'Pembentukan Baseline',
        questionIndonesian: 'Pertanyaan pembuka',
        questionEnglishEdaic: 'Opening question',
        guidanceHint: 'Petunjuk pembuka',
        icon: Icons.help_outline,
      );
      expect(qProtocol.phq8Badge, equals('E-DAIC Protocol: Pembentukan Baseline'));
    });
  });
}
