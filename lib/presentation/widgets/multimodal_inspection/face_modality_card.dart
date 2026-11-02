import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../data/models/multimodal_inspection_models.dart';

class FaceModalityCard extends StatefulWidget {
  final MultimodalInspectionData inspection;
  final bool isSimpleMode;
  final ValueChanged<double>? onVideoProgressChanged;

  const FaceModalityCard({
    super.key,
    required this.inspection,
    this.isSimpleMode = true,
    this.onVideoProgressChanged,
  });

  @override
  State<FaceModalityCard> createState() => _FaceModalityCardState();
}

class _FaceModalityCardState extends State<FaceModalityCard> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _slateDark = Color(0xFF0F172A);

  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  int _selectedFrameIdx = 0;
  bool _showBoundingBoxOverlay = true;

  @override
  void initState() {
    super.initState();
    _initVideoIfAvailable();
  }

  @override
  void didUpdateWidget(covariant FaceModalityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inspection.videoPath != widget.inspection.videoPath) {
      _disposeVideo();
      _initVideoIfAvailable();
    }
  }

  Future<void> _initVideoIfAvailable() async {
    final path = widget.inspection.videoPath;
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (!await file.exists()) return;

      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      await ctrl.setLooping(true);
      ctrl.addListener(_onVideoTick);

      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _videoController = ctrl;
        _isVideoReady = true;
      });
    } catch (_) {
      // Fallback ke kanvas biometrik interaktif jika gagal memuat video
    }
  }

  void _onVideoTick() {
    final ctrl = _videoController;
    if (ctrl == null || !ctrl.value.isInitialized || !mounted) return;

    final durMs = ctrl.value.duration.inMilliseconds;
    final posMs = ctrl.value.position.inMilliseconds;
    if (durMs > 0) {
      final progress = (posMs / durMs).clamp(0.0, 1.0);
      widget.onVideoProgressChanged?.call(progress);

      final frames = widget.inspection.visualFrames;
      if (frames.isNotEmpty) {
        final idx = (progress * (frames.length - 1)).round().clamp(0, frames.length - 1);
        if (idx != _selectedFrameIdx) {
          setState(() {
            _selectedFrameIdx = idx;
          });
        }
      }
    }
  }

  void _disposeVideo() {
    final ctrl = _videoController;
    if (ctrl != null) {
      ctrl.removeListener(_onVideoTick);
      ctrl.dispose();
      _videoController = null;
      _isVideoReady = false;
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  VisualFrameInspection get _activeFrame {
    final frames = widget.inspection.visualFrames;
    if (frames.isEmpty) {
      return const VisualFrameInspection(
        frameIndex: 0,
        timeSec: 0.0,
        faceFound: true,
        confidence: 0.94,
        bboxLeft: 0.24,
        bboxTop: 0.16,
        bboxRight: 0.76,
        bboxBottom: 0.82,
        eulerX: -3.5,
        eulerY: 1.5,
        eulerZ: 0.5,
        browTension: 0.45,
        eyeOpenness: 0.75,
        smileIntensity: 0.35,
        lipDepressor: 0.42,
        motionEnergy: 0.38,
        expressionLabel: 'Wajah Terdeteksi Jelas • Ekspresi Stabil',
      );
    }
    return frames[_selectedFrameIdx.clamp(0, frames.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final ins = widget.inspection;
    final frame = _activeFrame;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER MODALITAS WAJAH ---
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brandTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: _brandTealDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '1. Modalitas Visual (Wajah & Ekspresi)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _slateDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ins.faceDetectionRatePct.toStringAsFixed(0)}% Terdeteksi',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ins.isFromRealVideo
                            ? 'Deteksi wajah riil dari ${ins.framesAnalyzed} segmen frame video Anda'
                            : 'Simulasi pemindaian 75 titik ekspresi wajah (Action Units)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- LAYAR VIDEO / KANVAS DETEKSI WAJAH REAL-TIME ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 235,
                color: const Color(0xFF0F172A),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isVideoReady && _videoController != null)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    else
                      const _SimulatedCameraBackground(),

                    // Overlay Bounding Box & Landmark Wajah
                    if (_showBoundingBoxOverlay)
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _FaceDetectionOverlayPainter(
                            frame: frame,
                            drawSimulatedFaceAvatar: !_isVideoReady,
                          ),
                        ),
                      ),

                    // Badge Status Kiri Atas: Apakah Wajah Terdeteksi?
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: frame.faceFound
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              frame.faceFound
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              size: 14,
                              color: frame.faceFound
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              frame.faceFound
                                  ? 'Wajah Terdeteksi (${(frame.confidence * 100).toStringAsFixed(0)}%)'
                                  : 'Wajah Kurang Terlihat',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tombol Toggle Overlay di Kanan Atas
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _showBoundingBoxOverlay = !_showBoundingBoxOverlay;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showBoundingBoxOverlay
                                      ? Icons.grid_on_rounded
                                      : Icons.grid_off_rounded,
                                  color: const Color(0xFF5EEAD4),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showBoundingBoxOverlay ? 'Sensor ON' : 'Sensor OFF',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Tombol Play/Pause jika video asli tersedia
                    if (_isVideoReady && _videoController != null)
                      Positioned(
                        bottom: 48,
                        right: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'face_video_play_btn',
                          backgroundColor: _brandTeal,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),

                    // Status Bar Bawah: Apa yang sedang terjadi pada frame ini
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _brandTeal.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${frame.timeSec.toStringAsFixed(1)}s',
                                style: const TextStyle(
                                  color: Color(0xFF5EEAD4),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                frame.expressionLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

          // --- SCRUBBER SEGMEN WAKTU FRAME WAJAH ---
          if (ins.visualFrames.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Geser untuk melihat deteksi wajah per detik:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'Frame ${_selectedFrameIdx + 1} / ${ins.visualFrames.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brandTealDark,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _brandTeal,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: _brandTealDark,
                      overlayColor: _brandTeal.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _selectedFrameIdx.toDouble(),
                      min: 0,
                      max: max(1, ins.visualFrames.length - 1).toDouble(),
                      divisions: max(1, ins.visualFrames.length - 1),
                      onChanged: (val) {
                        final newIdx = val.round();
                        setState(() {
                          _selectedFrameIdx = newIdx;
                        });
                        if (_isVideoReady && _videoController != null) {
                          final targetSec = ins.visualFrames[newIdx].timeSec;
                          _videoController!.seekTo(
                            Duration(milliseconds: (targetSec * 1000).round()),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          // --- APA YANG TERJADI PADA WAJAH? (NARASI RAMAH PENGGUNA) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 16,
                        color: _brandTealDark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Apa yang Terjadi: ${ins.facialAffectTitle}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ins.facialAffectDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF134E4A),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- INDIKATOR GERAK OTOT WAJAH (ACTION UNITS) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isSimpleMode
                          ? 'Sinyal Bahasa Wajah yang Dibaca AI:'
                          : 'Intensitas Facial Action Units (FACS 75D):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _slateDark,
                      ),
                    ),
                    Text(
                      'Pose Kepala: ${frame.eulerX.toStringAsFixed(1)}° Pitch | ${frame.eulerY.toStringAsFixed(1)}° Yaw',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...ins.actionUnitScores.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildActionUnitBar(
                      label: entry.key,
                      value: entry.value,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionUnitBar({
    required String label,
    required double value,
  }) {
    final pct = (value * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _brandTealDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation<Color>(_brandTeal),
          ),
        ),
      ],
    );
  }
}

class _SimulatedCameraBackground extends StatelessWidget {
  const _SimulatedCameraBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          radius: 0.9,
        ),
      ),
    );
  }
}

class _FaceDetectionOverlayPainter extends CustomPainter {
  final VisualFrameInspection frame;
  final bool drawSimulatedFaceAvatar;

  _FaceDetectionOverlayPainter({
    required this.frame,
    required this.drawSimulatedFaceAvatar,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = frame.bboxLeft * size.width;
    final top = frame.bboxTop * size.height;
    final right = frame.bboxRight * size.width;
    final bottom = frame.bboxBottom * size.height;
    final rect = Rect.fromLTRB(left, top, right, bottom);
    final center = rect.center;

    // 1. Jika tidak ada video nyata, gambar siluet biometrik wajah terukur
    if (drawSimulatedFaceAvatar) {
      final silPaint = Paint()
        ..color = const Color(0xFF334155).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect.deflate(8), silPaint);

      final meshPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(rect.deflate(8), meshPaint);
    }

    if (!frame.faceFound) return;

    // 2. Gambar kotak Bounding Box Sudut (Corner Brackets)
    final boxColor = frame.confidence > 0.75
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    final faintRectPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      faintRectPaint,
    );

    final cornerPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const double cl = 20.0;
    // Kiri Atas
    canvas.drawLine(Offset(left, top + cl), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cl, top), cornerPaint);
    // Kanan Atas
    canvas.drawLine(Offset(right - cl, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cl), cornerPaint);
    // Kiri Bawah
    canvas.drawLine(Offset(left, bottom - cl), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cl, bottom), cornerPaint);
    // Kanan Bawah
    canvas.drawLine(Offset(right - cl, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom - cl), Offset(right, bottom), cornerPaint);

    // 3. Gambar titik Landmark Wajah (Alis, Mata, Hidung, Bibir) yang bergeser sesuai Pose Euler
    final yawOffset = (frame.eulerY / 35.0).clamp(-0.3, 0.3) * rect.width * 0.2;
    final pitchOffset = (-frame.eulerX / 35.0).clamp(-0.3, 0.3) * rect.height * 0.15;

    final lmPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF5EEAD4).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final leftEye = Offset(
      center.dx - rect.width * 0.17 + yawOffset,
      top + rect.height * 0.36 + pitchOffset,
    );
    final rightEye = Offset(
      center.dx + rect.width * 0.17 + yawOffset,
      top + rect.height * 0.36 + pitchOffset,
    );
    final noseTip = Offset(
      center.dx + yawOffset * 1.3,
      top + rect.height * 0.54 + pitchOffset * 1.2,
    );
    final mouthLeft = Offset(
      center.dx - rect.width * 0.14 + yawOffset,
      top + rect.height * 0.72 + pitchOffset + (frame.lipDepressor - frame.smileIntensity) * 6,
    );
    final mouthRight = Offset(
      center.dx + rect.width * 0.14 + yawOffset,
      top + rect.height * 0.72 + pitchOffset + (frame.lipDepressor - frame.smileIntensity) * 6,
    );
    final mouthCenter = Offset(
      center.dx + yawOffset,
      top + rect.height * 0.73 + pitchOffset,
    );

    // Alis kiri & kanan
    final browLift = (0.5 - frame.browTension) * 5.0;
    canvas.drawLine(
      Offset(leftEye.dx - 12, leftEye.dy - 12 + browLift),
      Offset(leftEye.dx + 12, leftEye.dy - 10 - browLift),
      linePaint,
    );
    canvas.drawLine(
      Offset(rightEye.dx - 12, rightEye.dy - 10 - browLift),
      Offset(rightEye.dx + 12, rightEye.dy - 12 + browLift),
      linePaint,
    );

    // Titik mata, hidung, dan garis bibir
    for (final pt in [leftEye, rightEye, noseTip, mouthLeft, mouthRight, mouthCenter]) {
      canvas.drawCircle(pt, 3.2, lmPaint);
    }

    // Jaring konektor simetri wajah
    canvas.drawLine(leftEye, rightEye, linePaint);
    canvas.drawLine(leftEye, noseTip, linePaint);
    canvas.drawLine(rightEye, noseTip, linePaint);
    canvas.drawLine(mouthLeft, mouthCenter, linePaint);
    canvas.drawLine(mouthCenter, mouthRight, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceDetectionOverlayPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.drawSimulatedFaceAvatar != drawSimulatedFaceAvatar;
  }
}

