import 'package:flutter/material.dart';

import '../../../core/services/on_device_whisper_service.dart';

/// Daftar persyaratan runtime on-device beserta status ketersediaannya di perangkat.
class RuntimeRequirementsSection extends StatefulWidget {
  const RuntimeRequirementsSection({super.key});

  @override
  State<RuntimeRequirementsSection> createState() =>
      _RuntimeRequirementsSectionState();
}

class _RuntimeRequirementsSectionState
    extends State<RuntimeRequirementsSection> {
  bool _loading = true;
  bool _downloading = false;
  bool _translate = false;
  bool _whisper = false;
  bool _vad = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final t = await OnDeviceWhisperService.isTranslationReady();
    final w = await OnDeviceWhisperService.isWhisperModelPresent();
    final v = await OnDeviceWhisperService.isVadModelPresent();
    if (!mounted) return;
    setState(() {
      _translate = t;
      _whisper = w;
      _vad = v;
      _loading = false;
    });
  }

  Future<void> _downloadTranslate() async {
    setState(() => _downloading = true);
    await OnDeviceWhisperService.downloadTranslationModels();
    if (!mounted) return;
    setState(() => _downloading = false);
    await _check();
  }

  Widget _row(String title, String subtitle, bool ok, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(
                  ok ? 'Tersedia di perangkat' : subtitle,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (!ok && action != null) action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOk = _translate && _whisper && _vad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist_rounded, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Persyaratan Perangkat',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (_loading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Periksa ulang',
                onPressed: _check,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
          ],
        ),
        if (!_loading) ...[
          Text(
            allOk
                ? 'Perangkat ini memenuhi semua persyaratan.'
                : 'Perangkat belum memenuhi semua persyaratan.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: allOk ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 4),
          _row(
            'Model Terjemahan ID→EN (ML Kit)',
            'Belum terunduh (±30 MB per bahasa)',
            _translate,
            action: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: _downloadTranslate, child: const Text('Unduh')),
          ),
          _row(
            'Model Whisper Small-ID',
            'Belum terunduh (±264 MB, diunduh saat transkripsi pertama)',
            _whisper,
          ),
          _row(
            'Model Silero VAD',
            'Belum terunduh (±1 MB, diunduh saat transkripsi pertama)',
            _vad,
          ),
        ],
      ],
    );
  }
}

