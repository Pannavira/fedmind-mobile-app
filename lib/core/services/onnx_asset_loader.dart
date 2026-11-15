import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// Helper pemuat aset ONNX yang memastikan file di direktori cache selalu
/// sinkron dengan aset APK terbaru (mencegah `flutter_onnxruntime` memakai
/// cache model lama bernama sama setelah pembaruan model).
class OnnxAssetLoader {
  /// Memuat [OrtSession] dari [assetKey] dengan verifikasi kesesuaian byte
  /// terhadap cache lokal sebelum membuka sesi ONNX Runtime.
  static Future<OrtSession> createSessionFromAsset(
    OnnxRuntime ort,
    String assetKey, {
    OrtSessionOptions? options,
  }) async {
    if (kIsWeb) {
      return ort.createSessionFromAsset(assetKey, options: options);
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = assetKey.split('/').last;
    final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    final metaFile = File('$filePath.meta');

    final data = await rootBundle.load(assetKey);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final signature = '$assetKey|${bytes.lengthInBytes}|${_fingerprint(bytes)}';

    bool cacheValid = false;
    if (await file.exists() && await metaFile.exists()) {
      try {
        final existingLen = await file.length();
        final existingMeta = await metaFile.readAsString();
        cacheValid =
            existingLen == bytes.lengthInBytes && existingMeta == signature;
      } catch (_) {
        cacheValid = false;
      }
    }

    if (!cacheValid) {
      await _writeAtomically(file, metaFile, bytes, signature);
      debugPrint(
        '[ONNX_LOADER] Extracted updated asset $fileName (${bytes.lengthInBytes} bytes)',
      );
    } else {
      debugPrint(
        '[ONNX_LOADER] Verified cached asset $fileName (${bytes.lengthInBytes} bytes)',
      );
    }

    try {
      return await ort.createSession(filePath, options: options);
    } catch (e) {
      if (!cacheValid) rethrow;
      debugPrint(
        '[ONNX_LOADER] Re-extracting $fileName after load failure: $e',
      );
      await _writeAtomically(file, metaFile, bytes, signature);
      return await ort.createSession(filePath, options: options);
    }
  }

  static Future<void> _writeAtomically(
    File file,
    File metaFile,
    Uint8List bytes,
    String signature,
  ) async {
    await file.parent.create(recursive: true);
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmpFile.rename(file.path);
    await metaFile.writeAsString(signature, flush: true);
  }

  /// Menghitung fingerprint deterministik cepat (FNV-1a tersampel + ujung file)
  /// agar perubahan bobot model berukuran sama tetap terdeteksi.
  static String _fingerprint(Uint8List bytes) {
    final len = bytes.lengthInBytes;
    if (len == 0) return '0';
    int hash = 0x811c9dc5;
    final step = len > 4096 ? len ~/ 2048 : 1;
    for (int i = 0; i < len; i += step) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final tailStart = len > 64 ? len - 64 : 0;
    for (int i = tailStart; i < len; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

