import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/local_storage_service.dart';

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
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _errorMessage;

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
      _initCamera();
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

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _errorMessage = 'Perangkat sensor kamera tidak terdeteksi.';
        });
        return;
      }

      CameraDescription selectedCamera = _availableCameras.first;
      for (final cam in _availableCameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          selectedCamera = cam;
          break;
        }
      }

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal menginisialisasi sensor kamera klinis: $e';
      });
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecording) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _secondsRecorded = 0;
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
      final xFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });

      final savedPath = await LocalStorageService.saveClinicalVideo(
        sourceFilePath: xFile.path,
        participantId: widget.participantId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(savedPath);
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
                            : 'Kalibrasi Wajah Klien pada Zona FACS',
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
                        const SizedBox(width: 40),
                      ],
                    ),
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

          // 4. Tombol Akuisisi di Bawah
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
}
