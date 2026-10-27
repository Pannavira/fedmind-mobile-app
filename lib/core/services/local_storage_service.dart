import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String _folderName = 'clinical_patient_recordings';

  /// Mendapatkan direktori privat aplikasi untuk video konseling
  static Future<Directory> _getRecordingsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Menyalin dan menyimpan file rekaman ke folder privat lokal HP
  /// Menghasilkan path permanen di dalam aplikasi
  static Future<String> saveClinicalVideo({
    required String sourceFilePath,
    required String participantId,
  }) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw 'Berkas video sumber tidak ditemukan di path: $sourceFilePath';
    }

    final dir = await _getRecordingsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedPid = participantId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final targetPath = '${dir.path}/REC_${sanitizedPid}_$timestamp.mp4';

    final targetFile = await sourceFile.copy(targetPath);
    debugPrint('[LOCAL_STORAGE] Video klinis berhasil disimpan privat di: ${targetFile.path}');
    return targetFile.path;
  }

  /// Memeriksa apakah berkas video lokal ada di path yang diberikan
  static Future<bool> videoFileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    final file = File(filePath);
    return await file.exists();
  }

  /// Menghapus video lokal secara manual jika konselor menginginkannya
  static Future<bool> deleteLocalVideo(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[LOCAL_STORAGE] Video berhasil dihapus: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[LOCAL_STORAGE] Gagal menghapus video: $e');
      return false;
    }
  }

  /// Mendapatkan ukuran file video dalam Megabytes (MB)
  static Future<double> getFileSizeInMb(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024);
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
