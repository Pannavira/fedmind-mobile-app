import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/edaic_interview_protocol.dart';
import '../../../core/services/clinical_media_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/mic_session_service.dart';
import '../../../core/services/realtime_face_detector_service.dart';
import 'widgets/interactive_interview_overlay.dart';

/// Hasil rekaman observasi klinis beserta transkrip tuturan real-time
class ClinicalCameraResult {
  final String videoPath;
  final String? liveTranscript;
  final String? speechWarning;
  final EdaicProtocolMode? protocolMode;
  final int? questionsCompletedCount;

  const ClinicalCameraResult({
    required this.videoPath,
    this.liveTranscript,
    this.speechWarning,
    this.protocolMode,
    this.questionsCompletedCount,
  });
}

class ClinicalCameraScreen extends StatefulWidget {
  final String participantId;

  const ClinicalCameraScreen({
    super.key,
    required this.participantId,
  });

  @override
  State<ClinicalCameraScreen> createState() => _ClinicalCameraScreenState();
}

class _ClinicalCameraScreenState extends State<ClinicalCameraScreen>
    with WidgetsBindingObserver {
  static const Color _brandTeal = Color(0xFF0D9488);

  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isSwitchingCamera = false;
  bool _isRecording = false;
  bool _isStopping = false;
  String? _errorMessage;

  // Kontrol Exposure & Tap-to-Focus agar preview tetap terang di berbagai pencahayaan
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _exposureOffset = 0.0;
  bool _userAdjustedExposure = false;
  Offset? _focusPointNorm;
  Timer? _focusOverlayTimer;
  String? _lastCameraError;

  // Protokol Wawancara E-DAIC / PHQ-8 Interaktif
  EdaicProtocolMode _protocolMode = EdaicProtocolMode.standard;
  int _currentQuestionIndex = 0;

  List<EdaicQuestion> get _questions =>
      EdaicInterviewProtocol.getQuestions(_protocolMode);

  int get _recommendedDuration =>
      EdaicInterviewProtocol.getRecommendedMinDuration(_protocolMode);
  int get _maxDuration =>
      EdaicInterviewProtocol.getMaxDuration(_protocolMode);

  CameraLensDirection? get _currentLensDirection {
    if (_availableCameras.isEmpty ||
        _selectedCameraIndex >= _availableCameras.length) {
      return null;
    }
    return _availableCameras[_selectedCameraIndex].lensDirection;
  }

  bool get _isFrontCamera =>
      _currentLensDirection == CameraLensDirection.front;
  bool get _isBackCamera =>
      _currentLensDirection == CameraLensDirection.back;
  bool get _canSwitchCamera =>
      _availableCameras.length > 1 &&
      !_isRecording &&
      !_isSwitchingCamera &&
      !_isStopping;

  // Real-Time Speech Recognition (Google Native SpeechRecognizer)
  String _liveTranscript = '';
  String? _speechWarning;

  // Notifier terpisah agar pembaruan detik/transkrip tidak me-rebuild CameraPreview
  final ValueNotifier<int> _secondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> _liveTranscriptNotifier =
      ValueNotifier<String>('');
  bool _targetNoticeShown = false;

  // Real-Time Face Presence Detection (Google ML Kit)
  final RealtimeFaceDetectorService _faceDetectorService =
      RealtimeFaceDetectorService();
  RealtimeFaceEvaluation _faceEval = const RealtimeFaceEvaluation(
    status: RealtimeFaceStatus.checking,
    faceCount: 0,
    message: 'Mendeteksi wajah pada kamera...',
  );
  bool _isProcessingFaceFrame = false;
  DateTime _lastFaceCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _hasCompletedInitialFaceCheck = false;
  bool _receivedRecordingStreamFrame = false;
  int _noFaceConsecutiveChecks = 0;

  Timer? _timer;
  int _secondsRecorded = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ClinicalMediaService.setKeepScreenOn(true);
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    ClinicalMediaService.setKeepScreenOn(false);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _focusOverlayTimer?.cancel();
    _secondsNotifier.dispose();
    _liveTranscriptNotifier.dispose();
    if (_isRecording) {
      MicSessionService.stop();
    }
    _stopPreviewFaceStreamSync();
    _faceDetectorService.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;

    if (state == AppLifecycleState.inactive) {
      // Jangan dispose kamera saat `inactive` sesaat (mis. overlay/dialog SpeechRecognizer)
      // apalagi ketika perekaman sedang aktif, karena memicu preview tiba-tiba gelap.
      if (!_isRecording) {
        _stopPreviewFaceStreamSync();
      }
      return;
    }

    if (state == AppLifecycleState.paused) {
      if (_isRecording && !_isStopping) {
        _stopRecording();
        return;
      }
      if (cameraController != null) {
        _controller = null;
        _isCameraInitialized = false;
        _stopPreviewFaceStreamSync();
        cameraController.dispose();
        if (mounted) {
          setState(() {});
        }
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      ClinicalMediaService.setKeepScreenOn(true);
      if (!_isRecording &&
          !_isStopping &&
          (_controller == null || !_controller!.value.isInitialized)) {
        _initCamera(_selectedCameraIndex);
      } else if (!_isRecording &&
          _controller != null &&
          _controller!.value.isInitialized) {
        _configureExposureAndFocus(_controller!);
        _startPreviewFaceStream();
      }
    }
  }

  Future<void> _checkPermissionsAndInit() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isGranted && micStatus.isGranted) {
        await _initCamera();
      } else {
        setState(() {
          _errorMessage =
              'Otorisasi sensor kamera dan mikrofon diperlukan untuk akuisisi Modalitas Visual (AUs) dan Prosodi Audio.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal meminta otorisasi sensor kamera/mikrofon: $e';
      });
    }
  }

  Future<void> _initCamera([int? targetIndex]) async {
    try {
      if (_availableCameras.isEmpty) {
        _availableCameras = await availableCameras();
      }
      if (_availableCameras.isEmpty) {
        setState(() {
          _errorMessage = 'Perangkat sensor kamera tidak terdeteksi.';
        });
        return;
      }

      int newIndex;
      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < _availableCameras.length) {
        newIndex = targetIndex;
      } else {
        // Konselor merekam klien: prioritaskan kamera belakang jika tersedia
        final backIndex = _availableCameras.indexWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
        );
        newIndex = backIndex != -1 ? backIndex : 0;
      }
      _selectedCameraIndex = newIndex;
      final targetCamera = _availableCameras[_selectedCameraIndex];

      // Jika controller sudah ada dan aktif, gunakan setDescription (standar resmi Camera Flutter)
      // agar CameraX tidak melepaskan SurfaceProvider / unbindAll secara bersamaan
      if (_controller != null && _controller!.value.isInitialized) {
        await _stopPreviewFaceStream();
        _resetFaceDetectionState();
        await _controller!.setDescription(targetCamera);
        await _configureExposureAndFocus(_controller!);
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _isSwitchingCamera = false;
          });
          await _startPreviewFaceStream();
        }
      } else {
        final newController = CameraController(
          targetCamera,
          ResolutionPreset.medium,
          enableAudio: false, // mikrofon dipegang MicSession (satu pemegang) agar tidak berebut dengan dictation
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );

        _attachControllerErrorListener(newController);

        await newController.initialize();
        if (!mounted) {
          await newController.dispose();
          return;
        }

        final oldController = _controller;
        _resetFaceDetectionState();
        await _configureExposureAndFocus(newController);
        if (!mounted) {
          await newController.dispose();
          return;
        }
        setState(() {
          _controller = newController;
          _isCameraInitialized = true;
          _isSwitchingCamera = false;
        });

        if (oldController != null) {
          await oldController.dispose();
        }
        await _startPreviewFaceStream();
      }
    } catch (e) {
      debugPrint('[ClinicalCamera] Gagal menginisialisasi kamera: $e');
      // Graceful fallback jika setDescription tidak didukung pada hardware OEM tertentu:
      // Lepas controller lama terlebih dahulu agar CameraX unbindAll selesai, baru inisialisasi ulang
      try {
        final old = _controller;
        _controller = null;
        if (old != null) {
          if (old.value.isStreamingImages) {
            try {
              await old.stopImageStream();
            } catch (_) {}
          }
          await old.dispose();
        }

        final fallbackController = CameraController(
          _availableCameras[_selectedCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        _attachControllerErrorListener(fallbackController);
        await fallbackController.initialize();
        if (mounted) {
          _resetFaceDetectionState();
          await _configureExposureAndFocus(fallbackController);
          if (!mounted) {
            await fallbackController.dispose();
            return;
          }
          setState(() {
            _controller = fallbackController;
            _isCameraInitialized = true;
            _isSwitchingCamera = false;
          });
          await _startPreviewFaceStream();
        }
      } catch (fallbackError) {
        if (mounted) {
          setState(() {
            _isSwitchingCamera = false;
            _errorMessage = 'Gagal menginisialisasi sensor kamera klinis: $fallbackError';
          });
        }
      }
    }
  }

  void _resetFaceDetectionState() {
    _hasCompletedInitialFaceCheck = false;
    _noFaceConsecutiveChecks = 0;
    _faceEval = const RealtimeFaceEvaluation(
      status: RealtimeFaceStatus.checking,
      faceCount: 0,
      message: 'Mendeteksi wajah pada kamera...',
    );
  }

  Future<void> _startPreviewFaceStream() async {
    if (!Platform.isAndroid) return;
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isRecording ||
        controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('[ClinicalCamera] Stream deteksi wajah tidak didukung: $e');
    }
  }

  Future<void> _stopPreviewFaceStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isStreamingImages) {
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  void _stopPreviewFaceStreamSync() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isStreamingImages) {
      return;
    }
    controller.stopImageStream().catchError((_) {});
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!mounted || _isSwitchingCamera) return;
    if (_isRecording && !_receivedRecordingStreamFrame) {
      _receivedRecordingStreamFrame = true;
    }

    final now = DateTime.now();
    if (_isProcessingFaceFrame ||
        now.difference(_lastFaceCheckAt).inMilliseconds < 350) {
      return;
    }
    if (_availableCameras.isEmpty ||
        _selectedCameraIndex >= _availableCameras.length) {
      return;
    }

    _isProcessingFaceFrame = true;
    _lastFaceCheckAt = now;

    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;

      final eval = await _faceDetectorService.processCameraImage(
        image: image,
        camera: _availableCameras[_selectedCameraIndex],
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (!mounted || eval == null) return;

      // Histeresis ringan (2 frame gagal beruntun) saat berpindah dari terdeteksi -> tidak terlihat
      // agar kotak indikator tidak berkedip saat klien berkedip cepat.
      RealtimeFaceEvaluation nextEval = eval;
      if (eval.status == RealtimeFaceStatus.noFace) {
        _noFaceConsecutiveChecks++;
        if (_hasCompletedInitialFaceCheck &&
            _faceEval.isFacePresent &&
            _noFaceConsecutiveChecks < 2) {
          nextEval = _faceEval;
        }
      } else {
        _noFaceConsecutiveChecks = 0;
      }

      setState(() {
        _hasCompletedInitialFaceCheck = true;
        _faceEval = nextEval;
      });
    } catch (e) {
      debugPrint('[ClinicalCamera] Gagal memproses deteksi wajah real-time: $e');
    } finally {
      _isProcessingFaceFrame = false;
    }
  }

  Future<void> _switchCamera() async {
    if (!_canSwitchCamera) return;

    final targetLens = _isFrontCamera
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _selectCameraLens(targetLens);
  }

  Future<void> _selectCameraLens(CameraLensDirection targetDirection) async {
    if (!_canSwitchCamera) return;
    if (_currentLensDirection == targetDirection) return;

    int targetIndex = _availableCameras.indexWhere(
      (c) => c.lensDirection == targetDirection,
    );
    if (targetIndex == -1) {
      targetIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    }

    setState(() {
      _isSwitchingCamera = true;
    });

    await _initCamera(targetIndex);

    if (mounted) {
      final lensName = _isBackCamera
          ? 'Kamera Belakang (Observasi Klien)'
          : 'Kamera Depan (Wicara Mandiri)';
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F172A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                _isBackCamera
                    ? Icons.camera_alt_outlined
                    : Icons.person_outline_rounded,
                color: const Color(0xFF5EEAD4),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Menggunakan $lensName',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<bool> _confirmStartWithoutFace() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_off_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wajah Tidak Terlihat di Kamera',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Detektor visual real-time belum mendeteksi wajah di dalam bingkai oval. '
          'Jika direkam tanpa wajah yang terlihat, analisis ekspresi visual akan ditolak.\n\n'
          'Pastikan wajah menghadap kamera dengan pencahayaan cukup.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(backgroundColor: _brandTeal),
            child: const Text(
              'Perbaiki Posisi',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tetap Rekam'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  void _attachControllerErrorListener(CameraController controller) {
    controller.addListener(() {
      if (!mounted) return;
      final err = controller.value.errorDescription;
      if (controller.value.hasError && err != null && err != _lastCameraError) {
        _lastCameraError = err;
        debugPrint('[ClinicalCamera] Error kamera: $err');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Peringatan sensor kamera: $err'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _configureExposureAndFocus(CameraController controller) async {
    try {
      final minExp = await controller.getMinExposureOffset();
      final maxExp = await controller.getMaxExposureOffset();
      final targetEv = (_userAdjustedExposure &&
              _exposureOffset >= minExp &&
              _exposureOffset <= maxExp)
          ? _exposureOffset
          : 0.0.clamp(minExp, maxExp).toDouble();

      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureOffset(targetEv);
      if (mounted) {
        setState(() {
          _minExposureOffset = minExp;
          _maxExposureOffset = maxExp;
          _exposureOffset = targetEv;
        });
      }
    } catch (_) {
      // Sensor tertentu tidak mengekspos offset exposure manual; lanjut aman.
    }
  }

  Future<void> _adjustExposureStep(double delta) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_maxExposureOffset <= _minExposureOffset) return;

    final next =
        (_exposureOffset + delta).clamp(_minExposureOffset, _maxExposureOffset).toDouble();
    try {
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposureOffset(next);
      if (mounted) {
        setState(() {
          _userAdjustedExposure = true;
          _exposureOffset = next;
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePreviewTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return;
    }

    final nx = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final ny = (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);
    final point = Offset(nx, ny);

    _focusOverlayTimer?.cancel();
    setState(() {
      _focusPointNorm = point;
    });
    _focusOverlayTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _focusPointNorm = null);
      }
    });

    try {
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {
      // Abaikan bila sensor depan tidak mendukung metering point.
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording ||
        _isStopping) {
      return;
    }

    if (_hasCompletedInitialFaceCheck && !_faceEval.isFacePresent) {
      final proceed = await _confirmStartWithoutFace();
      if (!proceed || !mounted) return;
    }

    try {
      ClinicalMediaService.setKeepScreenOn(true);
      // Hentikan image stream preview terlebih dahulu sebelum mengikat VideoCapture CameraX
      await _stopPreviewFaceStream();
      _receivedRecordingStreamFrame = false;

      // Pastikan kesiapan Android 13+ SpeechRecognizer sebelum mulai
      final speechReq = await MicSessionService.getSpeechRequirements();
      if (Platform.isAndroid && !speechReq.supportsParallelMic && mounted) {
        const sdkWarning =
            'Perangkat terdeteksi Android < 13 (API < 33): SpeechRecognizer paralel tidak didukung. Lanjutkan merekam lalu lengkapi transkrip secara manual.';
        setState(() => _speechWarning = sdkWarning);
      } else {
        setState(() => _speechWarning = null);
      }

      // 1) Mikrofon tunggal (WAV + dictation) dimulai lebih dulu agar menutupi seluruh video
      await MicSessionService.start(
        onTranscript: (text) {
          if (!mounted) return;
          _liveTranscript = text;
          _liveTranscriptNotifier.value = text;
        },
        onProblem: (msg) {
          if (!mounted) return;
          setState(() => _speechWarning = msg);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.orange),
          );
        },
      );

      // 2) Rekam video tanpa concurrent ImageAnalysis stream agar CameraX Camera/Preview
      //    pada perangkat FULL/LIMITED (non-LEVEL_3) tidak meredup atau konflik surface.
      try {
        await _controller!.startVideoRecording();
      } catch (e) {
        await MicSessionService.stop();
        await _startPreviewFaceStream();
        rethrow;
      }

      // Segarkan mode auto-exposure/focus segera setelah Pipeline RECORD dimulai.
      await _configureExposureAndFocus(_controller!);
      if (!mounted) return;

      _secondsRecorded = 0;
      _secondsNotifier.value = 0;
      _liveTranscript = '';
      _liveTranscriptNotifier.value = '';
      _targetNoticeShown = false;

      setState(() {
        _isRecording = true;
        _currentQuestionIndex = 0;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        _secondsRecorded++;
        _secondsNotifier.value = _secondsRecorded;

        // Tidak ada auto-stop paksa pada 90/120 detik; tampilkan pengingat non-blocking
        // agar klinisi tetap mengendalikan kapan wawancara dihentikan.
        if (_secondsRecorded == _maxDuration && !_targetNoticeShown) {
          _targetNoticeShown = true;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Durasi referensi protokol (${_formatTimer(_maxDuration)}) tercapai. Lanjutkan wawancara bila masih diperlukan, ketuk tombol Stop saat selesai.',
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai akuisisi video observasi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording || _isStopping) return;

    _timer?.cancel();
    setState(() {
      _isStopping = true;
    });

    try {
      final results = await Future.wait([
        _controller!.stopVideoRecording(),
        MicSessionService.stop(),
      ]);
      final xFile = results[0] as XFile;
      final mic = results[1] as ({String transcript, String? wavPath});

      final savedPath = await LocalStorageService.saveClinicalVideo(
        sourceFilePath: xFile.path,
        participantId: widget.participantId,
      );

      // Audio asli dari mikrofon disimpan berdampingan dengan video secara utuh (untuk fitur model),
      // lalu digabung (mux) ke track audio .mp4 (video copy lossless) agar pemutaran video bersuara.
      if (mic.wavPath != null) {
        final sidecarWav = MicSessionService.sidecarWavPath(savedPath);
        await File(mic.wavPath!).copy(sidecarWav);
        await ClinicalMediaService.muxAudioIntoMp4(
          videoPath: savedPath,
          wavPath: sidecarWav,
        );
      }

      final finalTranscript =
          mic.transcript.isNotEmpty ? mic.transcript : _liveTranscript.trim();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isStopping = false;
      });
      Navigator.of(context).pop(ClinicalCameraResult(
        videoPath: savedPath,
        liveTranscript: finalTranscript.isNotEmpty ? finalTranscript : null,
        speechWarning: _speechWarning,
        protocolMode: _protocolMode,
        questionsCompletedCount: _currentQuestionIndex + 1,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isStopping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan berkas observasi klinis: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Clinical Camera & Audio Capture')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 56,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _checkPermissionsAndInit,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kalibrasi Ulang Sensor'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: _brandTeal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Pratinjau Kamera + Tap-to-Focus/Metering (Dilindungi dari null pointer saat switch kamera)
          Center(
            child: (_controller != null && _controller!.value.isInitialized)
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) =>
                            _handlePreviewTap(details, constraints),
                        child: Stack(
                          fit: StackFit.loose,
                          children: [
                            CameraPreview(_controller!),
                            if (_focusPointNorm != null)
                              Positioned(
                                left: (_focusPointNorm!.dx *
                                            constraints.maxWidth -
                                        26)
                                    .clamp(0.0, constraints.maxWidth - 52),
                                top: (_focusPointNorm!.dy *
                                            constraints.maxHeight -
                                        26)
                                    .clamp(0.0, constraints.maxHeight - 52),
                                child: IgnorePointer(
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF5EEAD4),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(color: _brandTeal),
                  ),
          ),

          // Indikator Penyimpanan & Penggabungan Audio Video
          if (_isStopping)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _brandTeal),
                    SizedBox(height: 12),
                    Text(
                      'Menyimpan video & menggabungkan audio...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Indikator Transisi Pengalihan Lensa Kamera
          if (_isSwitchingCamera)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _brandTeal),
                    SizedBox(height: 12),
                    Text(
                      'Mengalihkan Sensor Kamera...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Panduan Kalibrasi Wajah FACS Real-Time (Proporsional di Tengah, Bebas Halangan)
          IgnorePointer(
            child: Center(
              child: Builder(
                builder: (context) {
                  final ({Color color, IconData icon, String label}) guide =
                      _resolveFaceGuideVisuals();
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 220,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: guide.color.withValues(alpha: 0.9),
                        width: 2.5,
                      ),
                      borderRadius:
                          const BorderRadius.all(Radius.elliptical(220, 280)),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: guide.color.withValues(alpha: 0.65),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(guide.icon, color: guide.color, size: 14),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  guide.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Bar Atas & Protokol Wawancara Semi-Terstruktur
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Tombol Kembali
                        Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              if (_isStopping) return;
                              if (_isRecording) {
                                _stopRecording();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Status Rekam / Standby (Expanded mencegah overflow 15px)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFFDC2626).withValues(alpha: 0.9)
                                  : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: _isRecording
                                        ? Colors.white
                                        : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _secondsNotifier,
                                    builder: (context, seconds, _) {
                                      return Text(
                                        _isRecording
                                            ? 'REC ${_formatTimer(seconds)} (${widget.participantId})'
                                            : 'Siap Rekam (${widget.participantId})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Cepat Pengalihan Kamera (Depan / Belakang)
                        Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _canSwitchCamera ? _switchCamera : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flip_camera_ios_rounded,
                                    color: _canSwitchCamera
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isBackCamera ? 'Belakang' : 'Depan',
                                    style: TextStyle(
                                      color: _canSwitchCamera
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Selector Pilihan Mode Kamera & Protokol (Saat Tidak Merekam)
                    if (!_isRecording) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_availableCameras.length > 1) ...[
                              _buildLensOptionChip(
                                title: 'Belakang (Klien)',
                                icon: Icons.camera_alt_rounded,
                                isSelected: _isBackCamera,
                                onTap: () => _selectCameraLens(
                                  CameraLensDirection.back,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildLensOptionChip(
                                title: 'Depan (Mandiri)',
                                icon: Icons.person_rounded,
                                isSelected: _isFrontCamera,
                                onTap: () => _selectCameraLens(
                                  CameraLensDirection.front,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildProtocolModeChip(
                              title: 'E-DAIC 4-Soal',
                              icon: Icons.bolt_rounded,
                              isSelected:
                                  _protocolMode == EdaicProtocolMode.standard,
                              onTap: () {
                                setState(() {
                                  _protocolMode = EdaicProtocolMode.standard;
                                  _currentQuestionIndex = 0;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildProtocolModeChip(
                              title: 'PHQ-8 8-Dimensi',
                              icon: Icons.checklist_rounded,
                              isSelected: _protocolMode ==
                                  EdaicProtocolMode.comprehensive,
                              onTap: () {
                                setState(() {
                                  _protocolMode =
                                      EdaicProtocolMode.comprehensive;
                                  _currentQuestionIndex = 0;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Overlay Pertanyaan Wawancara Klinis Interaktif E-DAIC / PHQ-8
                    ValueListenableBuilder<String>(
                      valueListenable: _liveTranscriptNotifier,
                      builder: (context, liveTranscript, _) {
                        return InteractiveInterviewOverlay(
                          questions: _questions,
                          currentQuestionIndex: _currentQuestionIndex,
                          isRecording: _isRecording,
                          liveTranscript: liveTranscript,
                          currentMode: _protocolMode,
                          onQuestionChanged: (idx) {
                            setState(() {
                              _currentQuestionIndex = idx;
                            });
                          },
                          onModeChanged: (mode) {
                            setState(() {
                              _protocolMode = mode;
                              _currentQuestionIndex = 0;
                            });
                          },
                          onAllQuestionsCompleted: () {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF5EEAD4),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Semua pertanyaan telah dijawab! Ketuk tombol merah di bawah untuk menyimpan rekaman.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF0F172A),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Kartu Subtitle / Transkrip Tuturan Real-Time (Ramping & Bebas Overflow)
          ValueListenableBuilder<String>(
            valueListenable: _liveTranscriptNotifier,
            builder: (context, liveTranscript, _) {
              if (!_isRecording && liveTranscript.isEmpty) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 12,
                right: 12,
                bottom: _maxExposureOffset > _minExposureOffset ? 138 : 105,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.75),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jawaban Q${_currentQuestionIndex + 1} (${_questions[_currentQuestionIndex].category}):',
                              style: const TextStyle(
                                color: Color(0xFF5EEAD4),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isRecording)
                            const Text(
                              '● Mendengarkan...',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 55),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Text(
                            liveTranscript.isEmpty
                                ? 'Mulai berbicara, tuturan Anda akan ditranskripsikan secara langsung...'
                                : liveTranscript,
                            style: TextStyle(
                              color: liveTranscript.isEmpty
                                  ? Colors.white60
                                  : Colors.white,
                              fontSize: 11.5,
                              fontStyle: liveTranscript.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 5. Tombol Akuisisi di Bawah + Kontrol Exposure Cepat
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_maxExposureOffset > _minExposureOffset)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _adjustExposureStep(-0.5),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.wb_sunny_outlined,
                                color: Color(0xFFFDE047),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'EV ${_exposureOffset >= 0 ? '+' : ''}${_exposureOffset.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _adjustExposureStep(0.5),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _secondsNotifier,
                          builder: (context, seconds, _) {
                            final targetReached =
                                _isRecording && seconds >= _recommendedDuration;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Target Minimal:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                  ),
                                ),
                                Text(
                                  targetReached
                                      ? 'Min. $_recommendedDuration dtk ✓'
                                      : 'Min. $_recommendedDuration dtk',
                                  style: TextStyle(
                                    color: targetReached
                                        ? const Color(0xFF34D399)
                                        : Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        GestureDetector(
                          onTap: _isStopping
                              ? null
                              : () {
                                  if (_isRecording) {
                                    _stopRecording();
                                  } else {
                                    _startRecording();
                                  }
                                },
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.transparent,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? const Color(0xFFEF4444)
                                    : _brandTeal,
                                borderRadius: BorderRadius.circular(
                                    _isRecording ? 14 : 50),
                              ),
                              child: Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.videocam_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Protokol Elisitasi:',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10.5),
                            ),
                            Text(
                              _protocolMode == EdaicProtocolMode.standard
                                  ? 'E-DAIC 4-Soal'
                                  : 'PHQ-8 8-Dimensi',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({Color color, IconData icon, String label}) _resolveFaceGuideVisuals() {
    if (_isRecording && !_receivedRecordingStreamFrame) {
      return (
        color: const Color(0xFF10B981),
        icon: Icons.lock_outline_rounded,
        label: 'FACS ROI Terkunci • Akuisisi Aktif',
      );
    }

    switch (_faceEval.status) {
      case RealtimeFaceStatus.detected:
        return (
          color: const Color(0xFF10B981),
          icon: Icons.face_retouching_natural_rounded,
          label: _isRecording
              ? 'Wajah Terdeteksi • Akuisisi Aktif'
              : 'Wajah Terdeteksi • Siap Rekam',
        );
      case RealtimeFaceStatus.outOfZone:
        return (
          color: const Color(0xFFF59E0B),
          icon: Icons.center_focus_weak_rounded,
          label: _faceEval.message,
        );
      case RealtimeFaceStatus.noFace:
        return (
          color: const Color(0xFFEF4444),
          icon: Icons.face_retouching_off_rounded,
          label: _isRecording
              ? 'Wajah Tidak Terlihat • Dekatkan ke Oval'
              : 'Wajah Tidak Terlihat di Kamera',
        );
      case RealtimeFaceStatus.checking:
      case RealtimeFaceStatus.recordingActive:
        return (
          color: Colors.white70,
          icon: Icons.face_rounded,
          label: _isBackCamera
              ? 'Mendeteksi Wajah Klien (Zona FACS)...'
              : 'Mendeteksi Wajah pada Zona FACS...',
        );
    }
  }

  Widget _buildLensOptionChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _canSwitchCamera ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _brandTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolModeChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: !_isRecording ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
