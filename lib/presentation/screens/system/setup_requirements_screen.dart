import 'package:flutter/material.dart';

import '../../../core/services/on_device_whisper_service.dart';

/// Gerbang persyaratan awal: aplikasi hanya dapat dipakai setelah model
/// terjemahan on-device (ML Kit ID→EN) terunduh.
class SetupGate extends StatefulWidget {
  final Widget child;
  const SetupGate({super.key, required this.child});

  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _SetupGateState extends State<SetupGate> {
  bool _checking = true;
  bool _ready = false;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ready = await OnDeviceWhisperService.isTranslationReady();
    if (!mounted) return;
    setState(() {
      _ready = ready;
      _checking = false;
    });
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    final ok = await OnDeviceWhisperService.downloadTranslationModels();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _ready = ok;
      if (!ok) {
        _error = 'Unduhan gagal. Pastikan koneksi internet aktif lalu coba lagi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.translate, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Persyaratan Awal',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aplikasi memerlukan model terjemahan Indonesia → Inggris '
                '(Google ML Kit, ±30 MB per bahasa) agar transkrip dapat '
                'diproses MentalBERT. Unduh sekali; setelah itu berjalan offline.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_downloading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text('Mengunduh model terjemahan…',
                    textAlign: TextAlign.center),
              ] else
                FilledButton.icon(
                  onPressed: _download,
                  icon: const Icon(Icons.download),
                  label: const Text('Unduh Model Terjemahan'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

