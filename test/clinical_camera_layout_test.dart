import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/core/constants/edaic_interview_protocol.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/widgets/interactive_interview_overlay.dart';

void main() {
  group('Narrow Screen Anti-Overflow Tests', () {
    testWidgets('InteractiveInterviewOverlay does not overflow on narrow 320px screen',
        (tester) async {
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('OVERFLOW CONTEXT: ${details.context}');
        debugPrint('OVERFLOW SUMMARY: ${details.summary}');
        for (final info in details.informationCollector?.call() ?? []) {
          debugPrint('INFO: $info');
        }
      };
      // Set tester screen size to narrow 320px screen (e.g. iPhone SE / small Android)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final questions = EdaicInterviewProtocol.standardQuestions;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: InteractiveInterviewOverlay(
                  questions: questions,
                  currentQuestionIndex: 0,
                  isRecording: true,
                  liveTranscript: 'Transkrip suara pengujian',
                  currentMode: EdaicProtocolMode.standard,
                  onQuestionChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Memastikan tidak ada exception overflow yang dilempar flutter
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('TEST ERROR DETAILS:\n${err.toStringDeep()}');
      }
      expect(err, isNull);

      // Verifikasi tinggi komponen sangat kompak (< 130px) agar area tengah kamera tetap luas
      final overlayFinder = find.byType(InteractiveInterviewOverlay);
      expect(overlayFinder, findsOneWidget);
      final size = tester.getSize(overlayFinder);
      expect(size.height, lessThan(130));
    });

    testWidgets('Top bar row layout does not overflow with long participantId on 320px screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const longParticipantId = 'PASIEN-KLINIS-RS-2026-LONG-ID-9999';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Siap Rekam ($longParticipantId)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flip_camera_ios_rounded,
                                color: Colors.white, size: 15),
                            SizedBox(width: 4),
                            Text(
                              'Belakang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('TEST ERROR DETAILS:\n${err.toStringDeep()}');
      }
      expect(err, isNull);
    });
  });
}
