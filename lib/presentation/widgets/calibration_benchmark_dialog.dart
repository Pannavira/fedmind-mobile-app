import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/screening_provider.dart';

class CalibrationBenchmarkDialog extends StatefulWidget {
  const CalibrationBenchmarkDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CalibrationBenchmarkDialog(),
    );
  }

  @override
  State<CalibrationBenchmarkDialog> createState() =>
      _CalibrationBenchmarkDialogState();
}

class _CalibrationBenchmarkDialogState
    extends State<CalibrationBenchmarkDialog> {
  bool _isRunning = true;
  String _statusMessage = 'Memuat riwayat video dari penyimpanan lokal...';
  List<CalibrationBenchmarkEntry> _entries = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBenchmark());
  }

  Future<void> _runBenchmark() async {
    try {
      final provider = context.read<ScreeningProvider>();
      final results = await provider.runHistoryCalibrationBenchmark(
        onStatus: (msg) {
          if (!mounted) return;
          setState(() => _statusMessage = msg);
        },
      );
      if (!mounted) return;
      setState(() {
        _entries = results;
        _isRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Uji Kalibrasi Riwayat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (!_isRunning)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Tutup',
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: _isRunning
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: Color(0xFF0D9488)),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Skor asli di database tidak diubah; ini hanya evaluasi Before vs After di memori.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              )
            : _error != null
                ? Text(
                    'Gagal menjalankan benchmark: $_error',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  )
                : _entries.isEmpty
                    ? const Text('Belum ada riwayat pemeriksaan lokal.')
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 440),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, idx) =>
                              _buildEntryCard(_entries[idx]),
                        ),
                      ),
      ),
      actions: _isRunning
          ? null
          : [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRunning = true;
                    _error = null;
                    _statusMessage = 'Mengulang benchmark...';
                  });
                  _runBenchmark();
                },
                child: const Text('Uji Ulang'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Selesai'),
              ),
            ],
    );
  }

  Widget _buildEntryCard(CalibrationBenchmarkEntry e) {
    final leg = e.legacy;
    final cal = e.calibrated;
    final delta = (leg != null && cal != null)
        ? (cal.phq8Score - leg.phq8Score)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.participantId,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${e.durationSec.toStringAsFixed(1)}s • ${e.transcriptChars} ch',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (e.errorMessage != null)
            Text(
              e.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            )
          else if (leg != null && cal != null) ...[
            Text(
              'PHQ-8: Tersimpan ${e.saved.phq8Score.toStringAsFixed(2)} '
              '| Before ${leg.phq8Score.toStringAsFixed(2)} (${leg.riskCategory}) '
              '→ After ${cal.phq8Score.toStringAsFixed(2)} (${cal.riskCategory})'
              '${delta != null ? ' [${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}]' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Before audio: S1=${leg.coalitionScores.length > 1 ? leg.coalitionScores[1].toStringAsFixed(2) : '-'} '
              'sev=${leg.audioSeverity.toStringAsFixed(2)} pause=${(leg.pauseRatio * 100).toStringAsFixed(0)}% '
              'F0=${leg.pitchMean.toStringAsFixed(0)}±${leg.pitchStd.toStringAsFixed(0)} rms=${leg.rms.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 2),
            Text(
              'After audio : S1=${cal.coalitionScores.length > 1 ? cal.coalitionScores[1].toStringAsFixed(2) : '-'} '
              'sev=${cal.audioSeverity.toStringAsFixed(2)} pause=${(cal.pauseRatio * 100).toStringAsFixed(0)}% '
              'F0=${cal.pitchMean.toStringAsFixed(0)}±${cal.pitchStd.toStringAsFixed(0)} actRms=${cal.actRms.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E)),
            ),
          ],
        ],
      ),
    );
  }
}
