import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mic_session_service.dart';

/// Layanan utilitas media klinis native:
/// - Menjaga layar tetap menyala selama perekaman klinis (`FLAG_KEEP_SCREEN_ON`)
/// - Menggabungkan track audio `.wav` hasil [MicSessionService] ke berkas `.mp4`
///   secara lossless pada track video sehingga pemutaran ulang video bersuara
///   tanpa mengubah input ekstraksi fitur model.
class ClinicalMediaService {
  ClinicalMediaService._();

  static const MethodChannel _channel =
      MethodChannel('com.fedmind.edge/multimodal_extractor');

  /// Mengaktifkan atau menonaktifkan keep-screen-on pada window Android aktif.
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'setKeepScreenOn',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // Aman di lingkungan unit test / desktop.
    } catch (_) {}
  }

  /// Menggabungkan [wavPath] ke dalam [videoPath] secara lossless untuk track video.
  /// File `.wav` sidecar tetap dipertahankan utuh di disk.
  static Future<bool> muxAudioIntoMp4({
    required String videoPath,
    required String wavPath,
  }) async {
    if (!Platform.isAndroid || videoPath.isEmpty || wavPath.isEmpty) {
      return false;
    }
    if (!File(videoPath).existsSync() || !File(wavPath).existsSync()) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'muxAudioIntoMp4',
        {
          'videoPath': videoPath,
          'wavPath': wavPath,
        },
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memastikan berkas `.mp4` lama maupun baru memiliki track audio sebelum diputar
  /// apabila berkas `.wav` pendampingnya masih tersedia di disk.
  static Future<bool> ensureVideoHasAudio(String videoPath) async {
    if (!Platform.isAndroid || videoPath.trim().isEmpty) {
      return false;
    }
    final cleanPath = videoPath.trim();
    if (!File(cleanPath).existsSync()) {
      return false;
    }
    final sidecarWav = MicSessionService.sidecarWavPath(cleanPath);
    final wavExists = File(sidecarWav).existsSync();
    try {
      final result = await _channel.invokeMethod<bool>(
        'ensureVideoHasAudio',
        {
          'videoPath': cleanPath,
          'wavPath': wavExists ? sidecarWav : null,
        },
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memilih berkas audio terbaik yang masih tersedia di disk untuk diputar:
  /// prioritas `.wav` sidecar 16 kHz (kualitas asli mikrofon), fallback ke `.mp4`.
  static String? resolvePlayableAudioPath(String? videoPath) {
    if (videoPath == null || videoPath.trim().isEmpty) {
      return null;
    }
    final cleanPath = videoPath.trim();
    if (cleanPath.toLowerCase().endsWith('.wav')) {
      final wavFile = File(cleanPath);
      if (wavFile.existsSync() && wavFile.lengthSync() > 44) {
        return cleanPath;
      }
      return null;
    }

    final sidecarWav = MicSessionService.sidecarWavPath(cleanPath);
    final sidecarFile = File(sidecarWav);
    if (sidecarFile.existsSync() && sidecarFile.lengthSync() > 44) {
      return sidecarWav;
    }

    final videoFile = File(cleanPath);
    if (videoFile.existsSync() && videoFile.lengthSync() > 0) {
      return cleanPath;
    }
    return null;
  }

  static bool isWavPath(String? path) =>
      path != null && path.toLowerCase().endsWith('.wav');
}

/// Snapshot status pemutaran audio klinis dari `ClinicalAudioPlayer` native.
@immutable
class ClinicalAudioPlaybackState {
  const ClinicalAudioPlaybackState({
    this.path,
    this.isPlaying = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  static const empty = ClinicalAudioPlaybackState();

  final String? path;
  final bool isPlaying;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final String? errorMessage;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool ownsPath(String? candidate) => candidate != null && path == candidate;

  bool isPlayingPath(String? candidate) =>
      candidate != null && path == candidate && isPlaying;
}

/// Wrapper MethodChannel khusus pemutar audio native (`com.fedmind.edge/audio_player`)
/// agar tidak menimpa handler `com.fedmind.edge/multimodal_extractor`.
class ClinicalAudioPlayerService {
  ClinicalAudioPlayerService._();

  static final ClinicalAudioPlayerService instance =
      ClinicalAudioPlayerService._();

  static const MethodChannel _channel =
      MethodChannel('com.fedmind.edge/audio_player');

  final ValueNotifier<ClinicalAudioPlaybackState> state =
      ValueNotifier<ClinicalAudioPlaybackState>(
    ClinicalAudioPlaybackState.empty,
  );

  bool _handlerRegistered = false;

  void ensureListening() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  Future<dynamic> _handleNativeEvent(MethodCall call) async {
    if (call.method != 'onAudioEvent') return null;
    final args = call.arguments;
    if (args is! Map) return null;

    final type = args['type']?.toString();
    final path = args['path']?.toString() ?? state.value.path;
    if (type == 'error') {
      state.value = ClinicalAudioPlaybackState(
        path: path,
        isPlaying: false,
        isCompleted: false,
        position: state.value.position,
        duration: state.value.duration,
        errorMessage: args['message']?.toString() ?? 'Gagal memutar audio.',
      );
      return null;
    }

    if (type == 'state') {
      final st = args['state']?.toString() ?? 'stopped';
      final posMs = (args['positionMs'] as num?)?.toInt() ?? 0;
      final durMs = (args['durationMs'] as num?)?.toInt() ?? 0;
      state.value = ClinicalAudioPlaybackState(
        path: st == 'stopped' ? null : path,
        isPlaying: st == 'playing',
        isCompleted: st == 'completed',
        position: Duration(milliseconds: posMs.clamp(0, 86400000)),
        duration: Duration(milliseconds: durMs.clamp(0, 86400000)),
        errorMessage: null,
      );
    }
    return null;
  }

  Future<bool> play(String path, {int? positionMs}) async {
    ensureListening();
    if (!Platform.isAndroid || path.trim().isEmpty) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('playAudio', {
        'path': path,
        'positionMs': ?positionMs,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      state.value = ClinicalAudioPlaybackState(
        path: path,
        isPlaying: false,
        errorMessage: 'Pemutar audio tidak tersedia: $e',
      );
      return false;
    }
  }

  Future<void> pause() async {
    ensureListening();
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('pauseAudio');
    } on MissingPluginException {
      // Aman di unit test / non-Android.
    } catch (_) {}
  }

  Future<void> seek(int positionMs) async {
    ensureListening();
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('seekAudio', {
        'positionMs': positionMs < 0 ? 0 : positionMs,
      });
    } on MissingPluginException {
      // Aman di unit test / non-Android.
    } catch (_) {}
  }

  Future<void> stop() async {
    ensureListening();
    if (!Platform.isAndroid) {
      state.value = ClinicalAudioPlaybackState.empty;
      return;
    }
    try {
      await _channel.invokeMethod<bool>('stopAudio');
    } on MissingPluginException {
      state.value = ClinicalAudioPlaybackState.empty;
    } catch (_) {}
  }

  Future<void> togglePlayPause(String path, {int? startPositionMs}) async {
    if (state.value.isPlayingPath(path)) {
      await pause();
    } else {
      await play(path, positionMs: startPositionMs);
    }
  }
}
