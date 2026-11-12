import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/mic_session_service.dart';

/// Hasil rekaman observasi klinis beserta transkrip tuturan real-time
class ClinicalCameraResult {
  final String videoPath;
  final String? liveTranscript;

  const ClinicalCameraResult({
    required this.videoPath,
    this.liveTranscript,
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
  String? _errorMessage;

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
      _availableCameras.length > 1 && !_isRecording && !_isSwitchingCamera;

  // Real-Time Speech Recognition (Google Native SpeechRecognizer)
  String _liveTranscript = '';

  Timer? _timer;
  int _secondsRecorded = 0;
  static const int _recommendedDuration = 45;
  static const int _maxDuration = 90;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_isRecording) {
      MicSessionService.stop();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
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

      if (targetIndex != null &&
          targetIndex >= 0 &&
          targetIndex < _availableCameras.length) {
        _selectedCameraIndex = targetIndex;
      } else {
        // Konselor merekam klien: prioritaskan kamera belakang jika tersedia
        final backIndex = _availableCameras.indexWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
        );
        _selectedCameraIndex = backIndex != -1 ? backIndex : 0;
      }

      final oldController = _controller;
      _controller = null;
      if (oldController != null) {
        await oldController.dispose();
      }

      final newController = CameraController(
        _availableCameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false, // mikrofon dipegang MicSession (satu pemegang) agar tidak berebut dengan dictation
      );

      await newController.initialize();
      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _controller = newController;
        _isCameraInitialized = true;
        _isSwitchingCamera = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
          _errorMessage = 'Gagal menginisialisasi sensor kamera klinis: $e';
        });
      }
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

  Future<void> _startRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording) {
      return;
    }

    try {
      // 1) Mikrofon tunggal (WAV + dictation) dimulai lebih dulu agar menutupi seluruh video
      await MicSessionService.start(
        onTranscript: (text) {
          if (!mounted) return;
          setState(() => _liveTranscript = text);
        },
        onProblem: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.orange),
          );
        },
      );

      // 2) Video tanpa audio (audio ditangani MicSession)
      try {
        await _controller!.startVideoRecording();
      } catch (e) {
        await MicSessionService.stop();
        rethrow;
      }
      setState(() {
        _isRecording = true;
        _secondsRecorded = 0;
        _liveTranscript = '';
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsRecorded++;
        });

        if (_secondsRecorded >= _maxDuration) {
          _stopRecording();
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
    if (_controller == null || !_isRecording) return;

    _timer?.cancel();
    try {
      final results = await Future.wait([
        _controller!.stopVideoRecording(),
        MicSessionService.stop(),
      ]);
      final xFile = results[0] as XFile;
      final mic = results[1] as ({String transcript, String? wavPath});
      setState(() {
        _isRecording = false;
      });

      final savedPath = await LocalStorageService.saveClinicalVideo(
        sourceFilePath: xFile.path,
        participantId: widget.participantId,
      );

      // Audio asli dari mikrofon disimpan berdampingan dengan video
      if (mic.wavPath != null) {
        await File(mic.wavPath!).copy(MicSessionService.sidecarWavPath(savedPath));
      }

      final finalTranscript =
          mic.transcript.isNotEmpty ? mic.transcript : _liveTranscript.trim();

      if (!mounted) return;
      Navigator.of(context).pop(ClinicalCameraResult(
        videoPath: savedPath,
        liveTranscript: finalTranscript.isNotEmpty ? finalTranscript : null,
      ));
    } catch (e) {
      if (!mounted) return;
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

    if (!_isCameraInitialized) {
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
          // 1. Pratinjau Kamera
          Center(
            child: CameraPreview(_controller!),
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

          // 2. Panduan Kalibrasi Wajah FACS
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 330,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isRecording
                        ? const Color(0xFF10B981).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.65),
                    width: 2.5,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(250, 330)),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _isRecording
                            ? 'FACS ROI Terkunci • Akuisisi Aktif'
                            : (_isBackCamera
                                ? 'Arahkan Kamera ke Wajah Klien (Zona FACS)'
                                : 'Kalibrasi Wajah Klien pada Zona FACS'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Bar Atas & Protokol Wawancara Semi-Terstruktur
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (_isRecording) {
                                _stopRecording();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? const Color(0xFFDC2626).withValues(alpha: 0.9)
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isRecording
                                      ? Colors.white
                                      : const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRecording
                                    ? 'REC: ${_formatTimer(_secondsRecorded)} (${widget.participantId})'
                                    : 'Clinical Camera Ready (${widget.participantId})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tombol Cepat Pengalihan Kamera (Depan / Belakang)
                        Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _canSwitchCamera ? _switchCamera : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flip_camera_ios_rounded,
                                    color: _canSwitchCamera
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _isBackCamera ? 'Belakang' : 'Depan',
                                    style: TextStyle(
                                      color: _canSwitchCamera
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 11.5,
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

                    // Selector Pilihan Mode Kamera (Konselor / Klien)
                    if (!_isRecording && _availableCameras.length > 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _brandTeal.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLensOptionChip(
                              title: 'Kamera Belakang (Klien)',
                              icon: Icons.camera_alt_rounded,
                              isSelected: _isBackCamera,
                              onTap: () => _selectCameraLens(
                                CameraLensDirection.back,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildLensOptionChip(
                              title: 'Kamera Depan (Mandiri)',
                              icon: Icons.person_rounded,
                              isSelected: _isFrontCamera,
                              onTap: () => _selectCameraLens(
                                CameraLensDirection.front,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Kartu Protokol Wawancara Klinis Semi-Terstruktur
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _brandTeal.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.medical_information_outlined,
                                color: Color(0xFF5EEAD4),
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Protokol Elisitasi Wawancara Klinis (PHQ-8 Probe):',
                                  style: TextStyle(
                                    color: Color(0xFF5EEAD4),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            '1. Eksplorasi Anhedonia & Afek Depresif: "Bagaimana minat, energi, serta suasana perasaan klien selama 2 minggu terakhir?"',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '2. Fungsi Vegetatif & Psikomotor: "Adakah perubahan pola tidur, konsentrasi, atau beban kognitif yang menonjol?"',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Kartu Subtitle / Transkrip Tuturan Real-Time (Google STT)
          if (_isRecording || _liveTranscript.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Transkripsi Tuturan Real-Time (Google STT ID):',
                          style: TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (_isRecording)
                          const Text(
                            '● Mendengarkan...',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 75),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          _liveTranscript.isEmpty
                              ? 'Mulai berbicara, tuturan Anda akan ditranskripsikan secara langsung...'
                              : _liveTranscript,
                          style: TextStyle(
                            color: _liveTranscript.isEmpty
                                ? Colors.white60
                                : Colors.white,
                            fontSize: 12.5,
                            fontStyle: _liveTranscript.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Tombol Akuisisi di Bawah
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Durasi Observasi:',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                        Text(
                          'Min. $_recommendedDuration detik',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
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
                            borderRadius:
                                BorderRadius.circular(_isRecording ? 14 : 50),
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
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Pemrosesan:',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                        Text(
                          'On-Device FL',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
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
}
