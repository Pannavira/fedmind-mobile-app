import 'package:flutter/material.dart';
import '../../../data/models/multimodal_inspection_models.dart';

class AudioWaveformCard extends StatefulWidget {
  final MultimodalInspectionData inspection;
  final bool isSimpleMode;
  final double playbackProgress;

  const AudioWaveformCard({
    super.key,
    required this.inspection,
    this.isSimpleMode = true,
    this.playbackProgress = 0.0,
  });

  @override
  State<AudioWaveformCard> createState() => _AudioWaveformCardState();
}

class _AudioWaveformCardState extends State<AudioWaveformCard> {
  static const Color _brandBlue = Color(0xFF0284C7);
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _slateDark = Color(0xFF0F172A);

  double _scrubProgress = 0.35;
  bool _userIsScrubbing = false;

  double get _effectiveProgress =>
      _userIsScrubbing ? _scrubProgress : widget.playbackProgress;

  @override
  Widget build(BuildContext context) {
    final ins = widget.inspection;
    final bars = ins.audioWaveformBars;
    final currentSec = (_effectiveProgress * ins.videoDurationSec)
        .clamp(0.0, ins.videoDurationSec);
    final activeBarIdx = bars.isEmpty
        ? 0
        : (_effectiveProgress * (bars.length - 1))
            .round()
            .clamp(0, bars.length - 1);
    final activeAmp = bars.isEmpty ? 0.3 : bars[activeBarIdx];
    final isPauseSegment = activeAmp < 0.14;

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
          // --- HEADER MODALITAS AUDIO ---
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brandBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: _brandBlue,
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
                            '2. Modalitas Suara (Gelombang & Nada)',
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
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ins.avgPitchHz.toStringAsFixed(0)} Hz',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _brandBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ins.isFromRealVideo
                            ? 'Gelombang suara PCM riil (${ins.totalAudioSamples} sampel @ ${ins.audioSampleRate}Hz)'
                            : 'Analisis 248 fitur akustik (MFCC, Kontur Pitch F0, & Jeda Bicara)',
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

          // --- VISUALISASI GELOMBANG SUARA (INTERACTIVE WAVEFORM) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isPauseSegment
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPauseSegment
                                ? 'Detik ${currentSec.toStringAsFixed(1)}s: Jeda Hening / Tarik Napas'
                                : 'Detik ${currentSec.toStringAsFixed(1)}s: Segmen Suara Aktif (${(activeAmp * 100).toStringAsFixed(0)}% Energi)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${ins.videoDurationSec.toStringAsFixed(1)} dtk',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Kanvas Gelombang Suara Interaktif (Sentuh/Geser)
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null && box.size.width > 0) {
                        final localX = details.localPosition.dx;
                        setState(() {
                          _userIsScrubbing = true;
                          _scrubProgress =
                              (localX / (box.size.width - 60)).clamp(0.0, 1.0);
                        });
                      }
                    },
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null && box.size.width > 0) {
                        final localX = details.localPosition.dx;
                        setState(() {
                          _userIsScrubbing = true;
                          _scrubProgress =
                              (localX / (box.size.width - 60)).clamp(0.0, 1.0);
                        });
                      }
                    },
                    child: SizedBox(
                      height: 88,
                      child: CustomPaint(
                        painter: _AudioWaveformPainter(
                          bars: bars,
                          progress: _effectiveProgress,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legenda Warna Gelombang
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          _LegendDot(
                            color: Color(0xFF38BDF8),
                            label: 'Suara Aktif',
                          ),
                          SizedBox(width: 12),
                          _LegendDot(
                            color: Color(0xFFF59E0B),
                            label: 'Jeda Hening',
                          ),
                        ],
                      ),
                      const Text(
                        'Sentuh gelombang untuk cek waktu',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- KONTUR NADA BICARA (PITCH F0 SPARKLINE) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.isSimpleMode
                            ? 'Alunan Nada Suara (Naik-Turun Intonasi):'
                            : 'Kontur Frekuensi Fundamental (Pitch F0 Contour):',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _slateDark,
                        ),
                      ),
                      Text(
                        'Variasi: ±${ins.pitchStdHz.toStringAsFixed(1)} Hz',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PitchContourPainter(
                        pitchValues: ins.pitchContourHz,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- RINGKASAN PROSODI SUARA RAMAH PENGGUNA ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.record_voice_over_rounded,
                        size: 16,
                        color: _brandBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Apa yang Terdengar: ${ins.vocalProsodyTitle}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ins.vocalProsodyDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0C4A6E),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- METRIK AKUSTIK RINGKAS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildAcousticStatBox(
                    title: 'Bicara Aktif',
                    value: '${ins.voicedRatioPct.toStringAsFixed(0)}%',
                    subtitle: 'Proporsi bersuara',
                    color: _brandTeal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAcousticStatBox(
                    title: 'Jeda Hening',
                    value: '${ins.pauseRatioPct.toStringAsFixed(0)}%',
                    subtitle: 'Jeda antar kalimat',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAcousticStatBox(
                    title: widget.isSimpleMode ? 'Kestabilan' : 'Jitter / Shimmer',
                    value: widget.isSimpleMode
                        ? (ins.jitterPct < 2.5 ? 'Stabil' : 'Bergetar')
                        : '${ins.jitterPct.toStringAsFixed(1)}%',
                    subtitle: 'Getaran pita suara',
                    color: _brandBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcousticStatBox({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;

  _AudioWaveformPainter({
    required this.bars,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final int n = bars.length;
    final double spacing = size.width / n;
    final double barWidth = (spacing * 0.62).clamp(2.0, 6.0);
    final double midY = size.height / 2;

    // Garis tengah nol desibel
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerLinePaint);

    for (int i = 0; i < n; i++) {
      final amp = bars[i].clamp(0.06, 1.0);
      final isPause = amp < 0.14;
      final isPassed = (i / n) <= progress;

      Color barColor;
      if (isPause) {
        barColor = isPassed
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF59E0B).withValues(alpha: 0.38);
      } else {
        barColor = isPassed
            ? const Color(0xFF38BDF8)
            : const Color(0xFF38BDF8).withValues(alpha: 0.35);
      }

      final barHeight = (amp * size.height * 0.88).clamp(4.0, size.height);
      final x = i * spacing + (spacing - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, midY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, Paint()..color = barColor);
    }

    // Garis Playhead Vertikal
    final playheadX = (progress.clamp(0.0, 1.0) * size.width);
    final playheadPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
    canvas.drawCircle(
      Offset(playheadX, 6),
      4.5,
      Paint()..color = const Color(0xFF5EEAD4),
    );
  }

  @override
  bool shouldRepaint(covariant _AudioWaveformPainter oldDelegate) {
    return oldDelegate.bars != bars || oldDelegate.progress != progress;
  }
}

class _PitchContourPainter extends CustomPainter {
  final List<double> pitchValues;

  _PitchContourPainter({required this.pitchValues});

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchValues.length < 2) return;

    const double minHz = 75.0;
    const double maxHz = 260.0;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < pitchValues.length; i++) {
      final x = (i / (pitchValues.length - 1)) * size.width;
      final normY = ((pitchValues[i] - minHz) / (maxHz - minHz)).clamp(0.05, 0.95);
      final y = size.height * (1.0 - normY);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0284C7).withValues(alpha: 0.22),
          const Color(0xFF0284C7).withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PitchContourPainter oldDelegate) {
    return oldDelegate.pitchValues != pitchValues;
  }
}

