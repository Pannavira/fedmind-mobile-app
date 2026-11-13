import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/constants/edaic_interview_protocol.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/widgets/interactive_interview_overlay.dart';

void main() {
  group('InteractiveInterviewOverlay Widget Tests', () {
    testWidgets('renders active question, dimension tag, and controls properly',
        (tester) async {
      int activeIndex = 0;
      bool completedCalled = false;

      final questions = EdaicInterviewProtocol.standardQuestions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return InteractiveInterviewOverlay(
                  questions: questions,
                  currentQuestionIndex: activeIndex,
                  isRecording: true,
                  liveTranscript: 'Saya merasa agak lelah',
                  currentMode: EdaicProtocolMode.standard,
                  onQuestionChanged: (newIdx) {
                    setState(() {
                      activeIndex = newIdx;
                    });
                  },
                  onAllQuestionsCompleted: () {
                    completedCalled = true;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Memastikan indikator 1/4 dan kategori tampil
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text(questions[0].category), findsOneWidget);
      expect(find.text(questions[0].questionIndonesian), findsOneWidget);

      // Verifikasi tombol Sebelumnya non-aktif pada indeks 0
      final prevBtn = find.text('Sebelumnya');
      expect(prevBtn, findsOneWidget);

      // Ketuk tombol Berikutnya
      final nextBtn = find.text('Berikutnya');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 300));

      // Memastikan pindah ke pertanyaan ke-2 (2/4)
      expect(activeIndex, equals(1));
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text(questions[1].category), findsOneWidget);
      expect(find.text(questions[1].questionIndonesian), findsOneWidget);

      // Ketuk Sebelumnya untuk kembali ke indeks 0
      await tester.tap(find.text('Sebelumnya'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(activeIndex, equals(0));
      expect(completedCalled, isFalse);
    });

    testWidgets('navigating to last question displays Selesai Menjawab and triggers callback',
        (tester) async {
      int activeIndex = 3; // Pertanyaan terakhir pada standardQuestions (4 soal: index 0..3)
      bool completedCalled = false;

      final questions = EdaicInterviewProtocol.standardQuestions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return InteractiveInterviewOverlay(
                  questions: questions,
                  currentQuestionIndex: activeIndex,
                  isRecording: true,
                  liveTranscript: '',
                  currentMode: EdaicProtocolMode.standard,
                  onQuestionChanged: (newIdx) {
                    setState(() {
                      activeIndex = newIdx;
                    });
                  },
                  onAllQuestionsCompleted: () {
                    completedCalled = true;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('4/4'), findsOneWidget);
      expect(find.text('Selesai Menjawab'), findsOneWidget);

      await tester.tap(find.text('Selesai Menjawab'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(completedCalled, isTrue);
    });

    testWidgets('opening question list modal allows jumping to any question',
        (tester) async {
      int activeIndex = 0;
      final questions = EdaicInterviewProtocol.standardQuestions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return InteractiveInterviewOverlay(
                  questions: questions,
                  currentQuestionIndex: activeIndex,
                  isRecording: false,
                  liveTranscript: '',
                  currentMode: EdaicProtocolMode.standard,
                  onQuestionChanged: (newIdx) {
                    setState(() {
                      activeIndex = newIdx;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Buka modal daftar pertanyaan melalui icon list
      final listIcon = find.byIcon(Icons.format_list_bulleted_rounded);
      expect(listIcon, findsOneWidget);
      await tester.tap(listIcon);
      await tester.pumpAndSettle();

      // Modal bottom sheet harus muncul dengan judul
      expect(find.text('Protokol Pertanyaan E-DAIC / PHQ-8'), findsOneWidget);

      // Pilih pertanyaan ke-3 dari modal
      final question3Tile = find.text(questions[2].questionIndonesian);
      expect(question3Tile, findsOneWidget);
      await tester.tap(question3Tile);
      await tester.pumpAndSettle();

      // Indeks aktif harus berpindah ke 2 (pertanyaan 3)
      expect(activeIndex, equals(2));
      expect(find.text('3/4'), findsOneWidget);
    });
  });
}
