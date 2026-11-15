import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/clinical_media_service.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/core/services/mic_session_service.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/multimodal_inspection/audio_waveform_card.dart';

class _StubLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}
}

class _StubScreeningRepository extends ScreeningRepository {
  _StubScreeningRepository()
      : super(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
          localInferenceService: _StubLocalInferenceService(),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClinicalMediaService & Audio Playback Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fedmind_media_test_');
      ClinicalAudioPlayerService.instance.state.value =
          ClinicalAudioPlaybackState.empty;
    });

    tearDown(() {
      ClinicalAudioPlayerService.instance.state.value =
          ClinicalAudioPlaybackState.empty;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('resolvePlayableAudioPath prefers valid sidecar WAV then MP4 fallback',
        () {
      expect(ClinicalMediaService.resolvePlayableAudioPath(null), isNull);
      expect(ClinicalMediaService.resolvePlayableAudioPath('   '), isNull);

      final videoPath = '${tempDir.path}${Platform.pathSeparator}obs_01.mp4';
      final wavPath = MicSessionService.sidecarWavPath(videoPath);

      expect(ClinicalMediaService.resolvePlayableAudioPath(videoPath), isNull);

      // MP4 ada, WAV belum ada -> pakai MP4
      File(videoPath).writeAsBytesSync(List<int>.filled(128, 1));
      expect(
        ClinicalMediaService.resolvePlayableAudioPath(videoPath),
        equals(videoPath),
      );

      // WAV hanya header (<= 44 byte) dianggap tidak valid -> tetap fallback MP4
      File(wavPath).writeAsBytesSync(List<int>.filled(44, 0));
      expect(
        ClinicalMediaService.resolvePlayableAudioPath(videoPath),
        equals(videoPath),
      );

      // WAV valid (> 44 byte) -> prioritaskan WAV sidecar 16 kHz
      File(wavPath).writeAsBytesSync(List<int>.filled(512, 2));
      expect(
        ClinicalMediaService.resolvePlayableAudioPath(videoPath),
        equals(wavPath),
      );
    });

    testWidgets(
      'AudioWaveformCard shows unavailable notice when raw audio is missing on disk',
      (tester) async {
        final inspection =
            MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: 'P900',
          visualFeatures: List<double>.filled(75, 0.2),
          audioFeatures: List<double>.filled(248, 0.3),
          textFeatures: List<double>.filled(768, 0.1),
        ).copyWith(
          videoPath: '${tempDir.path}${Platform.pathSeparator}missing.mp4',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AudioWaveformCard(inspection: inspection),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('audio_waveform_unavailable_notice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('audio_waveform_play_btn')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'AudioWaveformCard renders audio player controls (WAV 16kHz & MP4 AAC) and reflects state updates',
      (tester) async {
        final mp4Path = '${tempDir.path}${Platform.pathSeparator}rec_01.mp4';
        File(mp4Path).writeAsBytesSync(List<int>.filled(256, 7));

        final mp4OnlyInspection =
            MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: 'P901',
          visualFeatures: List<double>.filled(75, 0.2),
          audioFeatures: List<double>.filled(248, 0.3),
          textFeatures: List<double>.filled(768, 0.1),
        ).copyWith(videoPath: mp4Path);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AudioWaveformCard(inspection: mp4OnlyInspection),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('audio_waveform_play_btn')),
          findsOneWidget,
        );
        expect(find.text('MP4 AAC'), findsOneWidget);
        expect(find.text('Putar Rekaman Suara'), findsOneWidget);

        // Sekarang tulis sidecar WAV & rebuild dengan path baru agar terdeteksi WAV 16kHz
        final mp4WithWavPath =
            '${tempDir.path}${Platform.pathSeparator}rec_02.mp4';
        final wavSidecar2 = MicSessionService.sidecarWavPath(mp4WithWavPath);
        File(mp4WithWavPath).writeAsBytesSync(List<int>.filled(256, 7));
        File(wavSidecar2).writeAsBytesSync(List<int>.filled(1024, 3));

        final wavInspection = mp4OnlyInspection.copyWith(
          videoPath: mp4WithWavPath,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AudioWaveformCard(inspection: wavInspection),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('WAV 16kHz'), findsOneWidget);

        // Simulasikan event player native mulai memutar WAV sidecar lewat MethodChannel
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.fedmind.edge/audio_player',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onAudioEvent', {
              'type': 'state',
              'path': wavSidecar2,
              'state': 'playing',
              'positionMs': 15000,
              'durationMs': 60000,
            }),
          ),
          (_) {},
        );
        await tester.pump();

        expect(find.text('Memutar Rekaman Suara'), findsOneWidget);
        expect(find.text('00:15 / 01:00'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('audio_waveform_stop_btn')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ScreeningResultScreen opened from History (without localVideoPath) resolves video & audio controls from inspectionData',
      (tester) async {
        final videoPath =
            '${tempDir.path}${Platform.pathSeparator}history_obs.mp4';
        final wavPath = MicSessionService.sidecarWavPath(videoPath);
        File(videoPath).writeAsBytesSync(List<int>.filled(256, 9));
        File(wavPath).writeAsBytesSync(List<int>.filled(1024, 5));

        final inspection =
            MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: 'P-HIST-01',
          visualFeatures: List<double>.filled(75, 0.2),
          audioFeatures: List<double>.filled(248, 0.3),
          textFeatures: List<double>.filled(768, 0.1),
        ).copyWith(videoPath: videoPath);

        final response = ScreeningResponse(
          screeningId: 'scr-hist-01',
          participantId: 'P-HIST-01',
          status: 'completed',
          createdAt: DateTime(2026, 11, 15, 10, 0).toIso8601String(),
          prediction: PredictionResult(
            phq8Score: 9.2,
            riskProbabilityProxy: 0.45,
            binaryPrediction: 'non_depression',
            riskCategory: 'mild',
          ),
          patientModalityAttribution: PatientModalityAttribution(
            dominantModality: 'text',
            textPct: 48.0,
            visualPct: 30.0,
            audioPct: 22.0,
            shapValues: PatientShapValues(text: 1.2, visual: 0.8, audio: 0.5),
          ),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ScreeningProvider>(
            create: (_) =>
                ScreeningProvider(repository: _StubScreeningRepository()),
            child: MaterialApp(
              home: ScreeningResultScreen(
                result: response,
                inspectionData: inspection,
                initialNavIndex: 3,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Video Penuh'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('audio_waveform_play_btn')),
          findsOneWidget,
        );
        expect(find.text('WAV 16kHz'), findsOneWidget);
      },
    );

    test(
      'ClinicalCameraScreen source keeps manual stop control without 90s auto-stop',
      () {
        final camSource = File(
          'lib/presentation/screens/screening/clinical_camera_screen.dart',
        ).readAsStringSync();
        expect(camSource.contains('setKeepScreenOn(true)'), isTrue);
        expect(camSource.contains('muxAudioIntoMp4'), isTrue);
        // Pastikan cabang auto-stop paksa di _secondsRecorded >= _maxDuration sudah dihapus
        expect(
          RegExp(r'if\s*\(\s*_secondsRecorded\s*>=\s*_maxDuration\s*\)\s*\{\s*_stopRecording\(\)')
              .hasMatch(camSource),
          isFalse,
        );
        // Pastikan startVideoRecording tidak lagi mengirim onAvailable yang memicu konflik LEVEL_3
        expect(
          RegExp(r'startVideoRecording\s*\(\s*onAvailable\s*:').hasMatch(camSource),
          isFalse,
        );
      },
    );
  });
}
