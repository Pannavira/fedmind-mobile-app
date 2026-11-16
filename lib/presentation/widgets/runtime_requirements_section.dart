import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';

import '../../../core/services/mic_session_service.dart';
import '../../../core/services/on_device_mentalbert_service.dart';

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
  bool _android13Plus = false;
  int _sdkInt = 0;
  bool _speech = false;
  bool _mentalBert = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check({bool forceInit = false}) async {
    if (!forceInit && Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        _android13Plus = true;
        _sdkInt = 34;
        _speech = true;
        _mentalBert = OnDeviceMentalBertService.isInitialized;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final speechReq = await MicSessionService.getSpeechRequirements().timeout(
      const Duration(seconds: 2),
      onTimeout: () => (
        available: false,
        isOnDevice: false,
        sdkInt: 0,
        supportsParallelMic: false,
      ),
    );
    bool mb = OnDeviceMentalBertService.isInitialized;
    if (!mb && forceInit) {
      try {
        await OnDeviceMentalBertService.initialize();
        mb = OnDeviceMentalBertService.isInitialized;
      } catch (_) {
        mb = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _android13Plus = speechReq.supportsParallelMic;
      _sdkInt = speechReq.sdkInt;
      _speech = speechReq.available;
      _mentalBert = mb;
      _loading = false;
    });
  }

  Widget _row(String title, String subtitle, bool ok, {String? okSubtitle}) {
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ok ? (okSubtitle ?? 'Tersedia di perangkat') : subtitle,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOk = _android13Plus && _speech && _mentalBert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist_rounded, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Persyaratan Perangkat (Android 13+)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Periksa ulang',
                onPressed: () => _check(forceInit: true),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
          ],
        ),
        if (!_loading) ...[
          Text(
            allOk
                ? 'Perangkat ini memenuhi semua persyaratan validasi.'
                : 'Perangkat belum memenuhi semua persyaratan.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: allOk ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 4),
          _row(
            'Sistem Operasi Android 13+ (API 33+)',
            _sdkInt > 0
                ? 'Perangkat Anda menggunakan API $_sdkInt. Dibutuhkan Android 13+ (API 33+).'
                : 'Membutuhkan Android 13+ (API 33+) untuk perekaman + STT paralel.',
            _android13Plus,
            okSubtitle: _sdkInt > 0
                ? 'Terpenuhi (Android API $_sdkInt)'
                : 'Terpenuhi',
          ),
          _row(
            'Google Speech Recognizer (Live ASR)',
            'Layanan pengenalan suara Google (Speech-to-Text)',
            _speech,
          ),
          _row(
            'Encoder Teks Multilingual-E5 INT4 ONNX (768D)',
            OnDeviceMentalBertService.lastError ??
                'Model Multilingual-E5 ONNX belum dimuat',
            _mentalBert,
          ),
        ],
      ],
    );
  }
}
