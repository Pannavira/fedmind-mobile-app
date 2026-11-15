import 'dart:isolate';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'onnx_asset_loader.dart';
import 'unigram_tokenizer.dart';

/// Layanan embedding kalimat dwibahasa (Indonesia & Inggris) 768D secara penuh on-device
/// berbasis Student `intfloat/multilingual-e5-small` INT4 yang didistilasi ke ruang vektor
/// Teacher `mental/mental-bert-base-uncased` (tanpa bergantung pada Google ML Kit Translate).
class OnDeviceMentalBertService {
  static const String modelAssetPath =
      'assets/models/multilingual_e5/multilingual_e5_mentalbert_int4.onnx';
  static const String tokenizerAssetPath =
      'assets/models/multilingual_e5/tokenizer.json';
  static const int maxLength = 512;
  static const int chunkStride = 256;
  static const int embeddingDim = 768;

  static final OnnxRuntime _ort = OnnxRuntime();
  static OrtSession? _session;
  static UnigramTokenizer? _tokenizer;
  static Future<void>? _initFuture;
  static String? _lastError;

  @visibleForTesting
  static Future<OrtSession> Function(String assetPath)? sessionLoaderOverride;

  @visibleForTesting
  static Future<String> Function(String assetPath)? assetLoaderOverride;

  static bool get isInitialized => _session != null && _tokenizer != null;
  static bool get isVocabLoaded => _tokenizer != null;
  static String? get lastError => _lastError;

  /// Memuat `tokenizer.json` dan `multilingual_e5_mentalbert_int4.onnx` ke memori (concurrency-safe).
  static Future<void> initialize() => _ensureReady();

  /// Memuat hanya `tokenizer.json` jika belum dimuat (berguna untuk tokenisasi & pengujian).
  static Future<void> ensureVocabLoaded() async {
    if (_tokenizer != null) return;
    final loader = assetLoaderOverride ?? rootBundle.loadString;
    final rawJson = await loader(tokenizerAssetPath);
    if (rawJson.length > 500000) {
      _tokenizer = await Isolate.run(
        () => UnigramTokenizer.fromJsonString(rawJson),
      );
    } else {
      _tokenizer = UnigramTokenizer.fromJsonString(rawJson);
    }
  }

  static Future<void> _ensureReady() async {
    if (_session != null && _tokenizer != null) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    final future = () async {
      try {
        _lastError = null;
        await ensureVocabLoaded();
        final sessionLoader = sessionLoaderOverride ??
            (path) => OnnxAssetLoader.createSessionFromAsset(_ort, path);
        _session ??= await sessionLoader(modelAssetPath);
      } catch (e) {
        _lastError = e.toString();
        rethrow;
      } finally {
        _initFuture = null;
      }
    }();

    _initFuture = future;
    await future;
  }

  /// Melepas sesi ONNX Runtime dan tokenizer dari memori.
  static Future<void> dispose() async {
    final session = _session;
    _session = null;
    _tokenizer = null;
    _initFuture = null;
    _lastError = null;
    if (session != null) {
      await session.close();
    }
  }

  @visibleForTesting
  static Future<List<int>> encodeTokenIdsForTest(String text) async {
    await ensureVocabLoaded();
    return _tokenizer!.encodeIds(text, maxLength: maxLength);
  }

  @visibleForTesting
  static Future<List<List<int>>> encodeChunksForTest(String text) async {
    await ensureVocabLoaded();
    return _tokenizer!.encodeChunks(
      text,
      maxLength: maxLength,
      chunkStride: chunkStride,
    );
  }

  /// Menghasilkan vektor semantik 768D langsung dari teks Bahasa Indonesia ataupun Inggris
  /// dengan sliding-window chunking + mean-pooling saat panjang > 512 token.
  static Future<List<double>> embedText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return List<double>.filled(embeddingDim, 0.0);
    }

    await _ensureReady();

    final chunks = _tokenizer!.encodeChunks(
      trimmed,
      maxLength: maxLength,
      chunkStride: chunkStride,
    );
    if (chunks.length == 1) {
      return _runChunk(chunks.first);
    }

    final acc = List<double>.filled(embeddingDim, 0.0);
    for (final chunkIds in chunks) {
      final chunkEmb = await _runChunk(chunkIds);
      for (int i = 0; i < embeddingDim; i++) {
        acc[i] += chunkEmb[i];
      }
    }
    final invCount = 1.0 / chunks.length;
    for (int i = 0; i < embeddingDim; i++) {
      final v = acc[i] * invCount;
      acc[i] = v.isFinite ? v : 0.0;
    }
    return acc;
  }

  /// Alias kompatibilitas yang meneruskan langsung ke [embedText] dwibahasa.
  static Future<List<double>> embedEnglish(String text) => embedText(text);

  static Future<List<double>> _runChunk(List<int> tokenIds) async {
    final padId = _tokenizer?.padId ?? 1;
    final inputIds = Int64List(maxLength);
    final attentionMask = Int64List(maxLength);
    for (int i = 0; i < maxLength; i++) {
      if (i < tokenIds.length) {
        inputIds[i] = tokenIds[i];
        attentionMask[i] = 1;
      } else {
        inputIds[i] = padId;
        attentionMask[i] = 0;
      }
    }

    final idOrt = await OrtValue.fromList(inputIds, [1, maxLength]);
    final maskOrt = await OrtValue.fromList(attentionMask, [1, maxLength]);
    Map<String, OrtValue>? outputs;

    try {
      outputs = await _session!.run({
        'input_ids': idOrt,
        'attention_mask': maskOrt,
      });
      final embTensor = outputs['sentence_embedding'] ?? outputs.values.first;
      final flat = await embTensor.asFlattenedList();
      final out = List<double>.filled(embeddingDim, 0.0);
      for (int i = 0; i < min(embeddingDim, flat.length); i++) {
        final v = (flat[i] as num).toDouble();
        out[i] = v.isFinite ? v : 0.0;
      }
      return out;
    } catch (e) {
      debugPrint('[Multilingual-MentalBERT] inference failed: $e');
      rethrow;
    } finally {
      await idOrt.dispose();
      await maskOrt.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    }
  }
}
