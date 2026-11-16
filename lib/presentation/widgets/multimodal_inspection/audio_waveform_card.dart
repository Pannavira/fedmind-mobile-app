import 'package:material_ui/material_ui.dart';
import '../../../core/services/clinical_media_service.dart';
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
  static const Color _slateDark = Color(0xFF1E293B);

  final ClinicalAudioPlayerService _audioPlayer =
      ClinicalAudioPlayerService.instance;

  String? _playableAudioPath;
  double _scrubProgress = 0.0;
  bool _userIsScrubbing = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.ensureListening();
    _playableAudioPath = ClinicalMediaService.resolvePlayableAudioPath(
      widget.inspection.videoPath,
    );
  }

  @override
  void didUpdateWidget(covariant AudioWaveformCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inspection.videoPath != widget.inspection.videoPath) {
      if (_audioPlayer.state.value.ownsPath(_playableAudioPath)) {
        _audioPlayer.stop();
      }
      _playableAudioPath = ClinicalMediaService.resolvePlayableAudioPath(
        widget.inspection.videoPath,
      );
      _userIsScrubbing = false;
      _scrubProgress = 0.0;
    }
  }

  @override
  void dispose() {
    if (_audioPlayer.state.value.ownsPath(_playableAudioPath)) {
      _audioPlayer.stop();
    }
    super.dispose();
  }

  double _resolveProgress(ClinicalAudioPlaybackState audioState) {
    if (_userIsScrubbing) return _scrubProgress;
    if (audioState.ownsPath(_playableAudioPath)) {
      return audioState.progress;
    }
    return widget.playbackProgress.clamp(0.0, 1.0);
  }

  String _formatClock(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  int _resolveDurationMs(ClinicalAudioPlaybackState audioState) {
    if (audioState.ownsPath(_playableAudioPath) &&
        audioState.duration.inMilliseconds > 0) {
      return audioState.duration.inMilliseconds;
    }
    return (widget.inspection.videoDurationSec * 1000)
        .round()
        .clamp(0, 86400000);
  }

  Future<void> _seekToNormalized(
    double normalized,
    ClinicalAudioPlaybackState audioState,
  ) async {
    final audioPath = _playableAudioPath;
    if (audioPath == null) return;
    final durMs = _resolveDurationMs(audioState);
    if (durMs <= 0) return;
    final targetMs = (normalized.clamp(0.0, 1.0) * durMs).round();
    if (audioState.ownsPath(audioPath)) {
      await _audioPlayer.seek(targetMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ins = widget.inspection;
    final bars = ins.audioWaveformBars;
    final audioPath = _playableAudioPath;

    return ValueListenableBuilder<ClinicalAudioPlaybackState>(
      valueListenable: _audioPlayer.state,
      builder: (context, audioState, _) {
        final effectiveProgress = _resolveProgress(audioState);
        final durMs = _resolveDurationMs(audioState);
        final durDuration = Duration(milliseconds: durMs);
        final posDuration = audioState.ownsPath(audioPath)
            ? audioState.position
            : Duration(milliseconds: (effectiveProgress * durMs).round());

        final currentSec =
            (effectiveProgress * ins.videoDurationSec).clamp(0.0, ins.videoDurationSec);
        final activeBarIdx = bars.isEmpty
            ? 0
            : (effectiveProgress * (bars.length - 1))
                .round()
                .clamp(0, bars.length - 1);
        final activeAmp = bars.isEmpty ? 0.3 : bars[activeBarIdx];
        final isPauseSegment = activeAmp < 0.14;
        final isThisOwned = audioState.ownsPath(audioPath);
        final isThisPlaying = audioState.isPlayingPath(audioPath);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HEADER MODALITAS AKUSTIK / PROSODI AUDIO ---
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
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
                              const Flexible(
                                child: Text(
                                  'Pengamatan Intonasi & Suara',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _slateDark,
                                  ),
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
                                child: const Text(
                                  'Intonasi Terukur',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _brandBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Analisis pola nada bicara, tempo kelancaran, dan jeda percakapan klien',
                            style: TextStyle(
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

              // --- VISUALISASI SPEKTROGRAM / WAVEFORM AKUSTIK INTERAKTIF + PLAYER AUDIO ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
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
                                Expanded(
                                  child: Text(
                                    isPauseSegment
                                        ? 't=${currentSec.toStringAsFixed(1)} dtk: Jeda Reflektif (Hening)'
                                        : 't=${currentSec.toStringAsFixed(1)} dtk: Sedang Berbicara Aktif',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${ins.videoDurationSec.toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Kanvas Gelombang Suara Interaktif (Sentuh/Geser akurat sesuai lebar kanvas)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width =
                              constraints.maxWidth > 0 ? constraints.maxWidth : 1.0;
                          return GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _userIsScrubbing = true;
                                _scrubProgress =
                                    (details.localPosition.dx / width)
                                        .clamp(0.0, 1.0);
                              });
                            },
                            onHorizontalDragEnd: (_) async {
                              final target = _scrubProgress;
                              await _seekToNormalized(target, audioState);
                              if (mounted && isThisOwned) {
                                setState(() => _userIsScrubbing = false);
                              }
                            },
                            onTapDown: (details) async {
                              final norm =
                                  (details.localPosition.dx / width).clamp(0.0, 1.0);
                              setState(() {
                                _userIsScrubbing = !isThisOwned;
                                _scrubProgress = norm;
                              });
                              await _seekToNormalized(norm, audioState);
                            },
                            child: SizedBox(
                              height: 88,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _AudioWaveformPainter(
                                  bars: bars,
                                  progress: effectiveProgress,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Legenda Warna Gelombang
                      const Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LegendDot(
                                color: Color(0xFF38BDF8),
                                label: 'Suara Berbicara',
                              ),
                              SizedBox(width: 10),
                              _LegendDot(
                                color: Color(0xFFF59E0B),
                                label: 'Jeda Hening',
                              ),
                            ],
                          ),
                          Text(
                            'Ketuk / geser gelombang untuk lompat waktu',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bar Kontrol Pemutar Audio Rekaman Klien
                      _buildAudioPlayerBar(
                        audioPath: audioPath,
                        audioState: audioState,
                        isThisOwned: isThisOwned,
                        isThisPlaying: isThisPlaying,
                        effectiveProgress: effectiveProgress,
                        posDuration: posDuration,
                        durDuration: durDuration,
                        durMs: durMs,
                      ),
                    ],
                  ),
                ),
              ),

          if (!widget.isSimpleMode) ...[
            // --- KONTUR FREKUENSI FUNDAMENTAL (PITCH F0 SPARKLINE - MODE TEKNIS) ---
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
                        const Expanded(
                          child: Text(
                            'Kontur Nada Dasar F0 (COVAREP / Pitch):',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _slateDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'F0: ${ins.avgPitchHz.toStringAsFixed(0)} Hz (±${ins.pitchStdHz.toStringAsFixed(1)} Hz) • Jitter ${ins.jitterPct.toStringAsFixed(2)}%',
                          style: const TextStyle(
                            fontSize: 10.5,
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
          ] else
            const SizedBox(height: 10),

          // --- RINGKASAN OBSERVASI PROSODI VOKAL ---
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
                          'Observasi Karakter Suara: ${ins.vocalProsodyTitle}',
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

          // --- METRIK AKUSTIK KLINIS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildAcousticStatBox(
                    title: 'Waktu Bicara',
                    value: '${ins.voicedRatioPct.toStringAsFixed(0)}%',
                    subtitle: 'Aktif berbicara',
                    color: _brandTeal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAcousticStatBox(
                    title: 'Waktu Jeda',
                    value: '${ins.pauseRatioPct.toStringAsFixed(0)}%',
                    subtitle: 'Jeda berpikir',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAcousticStatBox(
                    title: 'Kestabilan Vokal',
                    value: ins.jitterPct < 2.0 ? 'Stabil' : 'Fluktuatif',
                    subtitle: 'Kualitas nada',
                    color: _brandBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildAudioPlayerBar({
    required String? audioPath,
    required ClinicalAudioPlaybackState audioState,
    required bool isThisOwned,
    required bool isThisPlaying,
    required double effectiveProgress,
    required Duration posDuration,
    required Duration durDuration,
    required int durMs,
  }) {
    if (audioPath == null) {
      return Container(
        key: const ValueKey('audio_waveform_unavailable_notice'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.volume_off_rounded,
              color: Color(0xFF94A3B8),
              size: 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Audio rekaman tidak tersedia di penyimpanan perangkat (hanya metrik prosodi).',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isWav = ClinicalMediaService.isWavPath(audioPath);
    final statusLabel = isThisPlaying
        ? 'Memutar Rekaman Suara'
        : (isThisOwned && posDuration > Duration.zero
            ? 'Audio Dijeda'
            : 'Putar Rekaman Suara');

    return Container(
      key: const ValueKey('audio_waveform_player_bar'),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isThisPlaying
              ? const Color(0xFF38BDF8).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Material(
                color: isThisPlaying ? _brandTeal : _brandBlue,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('audio_waveform_play_btn'),
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final startMs = (!isThisOwned &&
                            _userIsScrubbing &&
                            durMs > 0)
                        ? (_scrubProgress * durMs).round()
                        : null;
                    setState(() => _userIsScrubbing = false);
                    await _audioPlayer.togglePlayPause(
                      audioPath,
                      startPositionMs: startMs,
                    );
                  },
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      isThisPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              if (isThisOwned) ...[
                const SizedBox(width: 6),
                Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const ValueKey('audio_waveform_stop_btn'),
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      setState(() {
                        _userIsScrubbing = false;
                        _scrubProgress = 0.0;
                      });
                      await _audioPlayer.stop();
                    },
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.stop_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isWav
                                ? const Color(0xFF0D9488).withValues(alpha: 0.32)
                                : const Color(0xFF0284C7).withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isWav ? 'WAV 16kHz' : 'MP4 AAC',
                            style: TextStyle(
                              color: isWav
                                  ? const Color(0xFF5EEAD4)
                                  : const Color(0xFF7DD3FC),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatClock(posDuration)} / ${_formatClock(durDuration)}',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5.5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 11,
                        ),
                        activeTrackColor: const Color(0xFF38BDF8),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        key: const ValueKey('audio_waveform_slider'),
                        value: effectiveProgress.clamp(0.0, 1.0),
                        onChanged: (val) {
                          setState(() {
                            _userIsScrubbing = true;
                            _scrubProgress = val;
                          });
                        },
                        onChangeEnd: (val) async {
                          await _seekToNormalized(val, audioState);
                          if (mounted && isThisOwned) {
                            setState(() => _userIsScrubbing = false);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isThisOwned && audioState.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              audioState.errorMessage!,
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
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
              color: Color(0xFF64748B),
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
      final normY =
          ((pitchValues[i] - minHz) / (maxHz - minHz)).clamp(0.05, 0.95);
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
