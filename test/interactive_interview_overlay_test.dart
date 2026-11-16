import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fedmind_mobile_app/core/constants/edaic_interview_protocol.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/widgets/interactive_interview_overlay.dart';

void main() {
  group('InteractiveInterviewOverlay Widget Tests', () {
    testWidgets(
      'renders active question, PHQ-8 category tag, and controls properly',
      (tester) async {
        int activeIndex = 0;
        bool completedCalled = false;

        final questions = EdaicInterviewProtocol.questions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return InteractiveInterviewOverlay(
                    questions: questions,
                    currentQuestionIndex: activeIndex,
                    isRecording: true,
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

        // Memastikan indikator 1/8, kategori, dan pertanyaan Indonesia tampil
        expect(find.text('1/8'), findsOneWidget);
        expect(find.text(questions[0].category), findsOneWidget);
        expect(find.text(questions[0].questionIndonesian), findsOneWidget);

        // Tidak ada lagi teks referensi bahasa Inggris E-DAIC
        expect(find.textContaining('E-DAIC:'), findsNothing);

        // Verifikasi tombol Sebelumnya & Berikutnya
        expect(find.text('Sebelumnya'), findsOneWidget);
        final nextBtn = find.text('Berikutnya');
        expect(nextBtn, findsOneWidget);

        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 300));

        // Memastikan pindah ke pertanyaan ke-2 (2/8)
        expect(activeIndex, equals(1));
        expect(find.text('2/8'), findsOneWidget);
        expect(find.text(questions[1].category), findsOneWidget);
        expect(find.text(questions[1].questionIndonesian), findsOneWidget);

        // Ketuk Sebelumnya untuk kembali ke indeks 0
        await tester.tap(find.text('Sebelumnya'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(activeIndex, equals(0));
        expect(completedCalled, isFalse);
      },
    );

    testWidgets(
      'navigating to last question (8/8) displays Selesai and triggers callback',
      (tester) async {
        int activeIndex = 7; // Pertanyaan terakhir (8 soal: index 0..7)
        bool completedCalled = false;

        final questions = EdaicInterviewProtocol.questions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return InteractiveInterviewOverlay(
                    questions: questions,
                    currentQuestionIndex: activeIndex,
                    isRecording: true,
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

        expect(find.text('8/8'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);

        await tester.tap(find.text('Selesai'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(completedCalled, isTrue);
      },
    );

    testWidgets(
      'opening question list modal allows jumping to any of 8 PHQ-8 questions',
      (tester) async {
        int activeIndex = 0;
        final questions = EdaicInterviewProtocol.questions;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return InteractiveInterviewOverlay(
                    questions: questions,
                    currentQuestionIndex: activeIndex,
                    isRecording: false,
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

        // Modal bottom sheet harus muncul dengan judul Bahasa Indonesia
        expect(find.text('Daftar Pertanyaan PHQ-8'), findsOneWidget);

        // Pilih pertanyaan ke-5 (Nafsu Makan) dari modal (scroll bila di luar viewport)
        final question5Tile = find.text(questions[4].questionIndonesian);
        await tester.scrollUntilVisible(
          question5Tile,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(question5Tile, findsOneWidget);
        await tester.tap(question5Tile);
        await tester.pumpAndSettle();

        // Indeks aktif harus berpindah ke 4 (pertanyaan 5/8)
        expect(activeIndex, equals(4));
        expect(find.text('5/8'), findsOneWidget);
      },
    );
  });
}
