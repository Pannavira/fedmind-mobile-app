import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sesi mikrofon tunggal: satu AudioRecord native menyuplai
///  - berkas WAV (fitur akustik) dan
///  - SpeechRecognizer Android (transkrip live ala voice typing keyboard)
/// sehingga tidak ada rebutan mikrofon dengan perekam video.
class MicSessionService {
  static const MethodChannel _ch =
      MethodChannel('com.fedmind.edge/multimodal_extractor');

  static bool _handlerSet = false;
  static void Function(String transcript)? _onTranscript;
  static void Function(String message)? _onProblem;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method != 'onMicEvent') return null;
      final m = Map<String, dynamic>.from(call.arguments as Map);
      switch (m['type']) {
        case 'transcript':
          _onTranscript?.call((m['text'] as String?) ?? '');
          break;
        case 'error':
          debugPrint('[MicSession] recognizer error: ${m['code'] ?? m['message']}');
          if (m['message'] != null) _onProblem?.call(m['message'] as String);
          break;
        case 'status':
          debugPrint('[MicSession] status: ${m['message']}');
          break;
      }
      return null;
    });
  }

  /// Mulai merekam mikrofon + dictation. Melempar PlatformException bila gagal.
  static Future<void> start({
    required void Function(String transcript) onTranscript,
    void Function(String message)? onProblem,
  }) async {
    _ensureHandler();
    _onTranscript = onTranscript;
    _onProblem = onProblem;
    await _ch.invokeMethod('startMicSession');
  }

  /// Hentikan sesi. Mengembalikan transkrip final dan path WAV (bila ada).
  static Future<({String transcript, String? wavPath})> stop() async {
    final res = await _ch.invokeMethod<Map<dynamic, dynamic>>('stopMicSession');
    _onTranscript = null;
    _onProblem = null;
    final transcript = (res?['transcript'] as String?)?.trim() ?? '';
    final wav = res?['wavPath'] as String?;
    return (
      transcript: transcript,
      wavPath: (wav != null && await File(wav).exists()) ? wav : null,
    );
  }

  /// Path WAV pendamping untuk sebuah berkas video (REC_xxx.mp4 -> REC_xxx.wav)
  static String sidecarWavPath(String videoPath) =>
      videoPath.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.wav');
}

