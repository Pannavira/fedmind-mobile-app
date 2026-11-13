import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// On-device MentalBERT mean-pooled sentence embedding (768D), aligned with edge service.
class OnDeviceMentalBertService {
  static const String modelAssetPath =
      'assets/models/mentalbert/mentalbert_mean_pool_int4.onnx';
  static const String vocabAssetPath = 'assets/models/mentalbert/vocab.txt';
  static const int maxLength = 512;
  static const int chunkStride = 256;
  static const int embeddingDim = 768;
  static const int _maxInputCharsPerWord = 200;

  static final OnnxRuntime _ort = OnnxRuntime();
  static OrtSession? _session;
  static Map<String, int>? _vocab;
  static int _padId = 0;
  static int _unkId = 100;
  static int _clsId = 101;
  static int _sepId = 102;
  static Future<void>? _initFuture;
  static String? _lastError;

  @visibleForTesting
  static Future<OrtSession> Function(String assetPath)? sessionLoaderOverride;

  @visibleForTesting
  static Future<String> Function(String assetPath)? assetLoaderOverride;

  static bool get isInitialized => _session != null && _vocab != null;
  static bool get isVocabLoaded => _vocab != null;
  static String? get lastError => _lastError;

  /// Loads `vocab.txt` and `mentalbert_mean_pool_int4.onnx` into memory (concurrency-safe).
  static Future<void> initialize() => _ensureReady();

  /// Loads only `vocab.txt` if not already loaded (useful for tokenization and tests).
  static Future<void> ensureVocabLoaded() async {
    if (_vocab != null) return;
    final loader = assetLoaderOverride ?? rootBundle.loadString;
    final vocabRaw = await loader(vocabAssetPath);
    final vocab = <String, int>{};
    final lines = vocabRaw.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) vocab[token] = i;
    }
    _vocab = vocab;
    _padId = vocab['[PAD]'] ?? 0;
    _unkId = vocab['[UNK]'] ?? 100;
    _clsId = vocab['[CLS]'] ?? 101;
    _sepId = vocab['[SEP]'] ?? 102;
  }

  static Future<void> _ensureReady() async {
    if (_session != null && _vocab != null) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    final future = () async {
      try {
        _lastError = null;
        await ensureVocabLoaded();
        final sessionLoader =
            sessionLoaderOverride ?? (path) => _ort.createSessionFromAsset(path);
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

  /// Releases the ONNX session and cached vocabulary.
  static Future<void> dispose() async {
    final session = _session;
    _session = null;
    _vocab = null;
    _initFuture = null;
    _lastError = null;
    if (session != null) {
      await session.close();
    }
  }

  @visibleForTesting
  static Future<List<int>> encodeTokenIdsForTest(String text) async {
    await ensureVocabLoaded();
    return _encode(text);
  }

  @visibleForTesting
  static Future<List<List<int>>> encodeChunksForTest(String text) async {
    await ensureVocabLoaded();
    return _encodeChunks(text);
  }

  @visibleForTesting
  static Future<List<String>> tokenizeForTest(String text) async {
    await ensureVocabLoaded();
    final vocab = _vocab!;
    final revVocab = <int, String>{};
    vocab.forEach((k, v) => revVocab[v] = k);

    final out = <String>[];
    for (final token in _basicTokenize(text)) {
      for (final id in _wordPiece(token, vocab)) {
        out.add(revVocab[id] ?? '[UNK]');
      }
    }
    return out;
  }

  /// Returns 768D embedding from English clinical text (sliding-window chunking + mean-pooling when > 512 tokens).
  static Future<List<double>> embedEnglish(String englishText) async {
    final text = englishText.trim();
    if (text.isEmpty) {
      return List<double>.filled(embeddingDim, 0.0);
    }

    await _ensureReady();

    final chunks = _encodeChunks(text);
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

  static Future<List<double>> _runChunk(List<int> tokenIds) async {
    final inputIds = Int64List(maxLength);
    final attentionMask = Int64List(maxLength);
    for (int i = 0; i < maxLength; i++) {
      if (i < tokenIds.length) {
        inputIds[i] = tokenIds[i];
        attentionMask[i] = 1;
      } else {
        inputIds[i] = _padId;
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
      debugPrint('[MentalBERT] inference failed: $e');
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

  static List<int> _tokenizeAllWordPieces(String text) {
    final vocab = _vocab!;
    final wpIds = <int>[];
    for (final token in _basicTokenize(text)) {
      wpIds.addAll(_wordPiece(token, vocab));
    }
    return wpIds;
  }

  static List<List<int>> _encodeChunks(String text) {
    final allWp = _tokenizeAllWordPieces(text);
    const int windowSize = maxLength - 2; // 510 content tokens
    if (allWp.length <= windowSize) {
      return [
        [_clsId, ...allWp, _sepId],
      ];
    }

    final chunks = <List<int>>[];
    int start = 0;
    while (start < allWp.length) {
      final end = min(start + windowSize, allWp.length);
      chunks.add([_clsId, ...allWp.sublist(start, end), _sepId]);
      if (end >= allWp.length) break;
      start += chunkStride;
    }
    return chunks;
  }

  static List<int> _encode(String text) {
    final vocab = _vocab!;
    final out = <int>[_clsId];
    for (final token in _basicTokenize(text)) {
      out.addAll(_wordPiece(token, vocab));
      if (out.length >= maxLength - 1) break;
    }
    out.add(_sepId);
    if (out.length > maxLength) {
      return out.sublist(0, maxLength - 1)..add(_sepId);
    }
    return out;
  }

  /// Mirrors HuggingFace `BertTokenizer(do_lower_case=True, tokenize_chinese_chars=True)`.
  static List<String> _basicTokenize(String text) {
    final cleaned = _cleanText(text);
    final cjkPadded = _tokenizeChineseChars(cleaned);
    final normalized = _stripAccents(cjkPadded.toLowerCase());

    final tokens = <String>[];
    final buffer = StringBuffer();

    for (final rune in normalized.runes) {
      if (_isWhitespace(rune)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else if (_isPunctuation(rune)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(String.fromCharCode(rune));
      } else {
        buffer.writeCharCode(rune);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }

  static String _cleanText(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0 || rune == 0xFFFD || _isControl(rune)) {
        continue;
      }
      if (_isWhitespace(rune)) {
        sb.write(' ');
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  static String _tokenizeChineseChars(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      if (_isChineseChar(rune)) {
        sb.write(' ');
        sb.writeCharCode(rune);
        sb.write(' ');
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  static String _stripAccents(String text) {
    final sb = StringBuffer();
    for (final rune in text.runes) {
      // Skip Unicode combining diacritical marks (Mn category core range)
      if (rune >= 0x0300 && rune <= 0x036F) {
        continue;
      }
      final mapped = _accentFoldMap[rune];
      if (mapped != null) {
        sb.write(mapped);
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  static List<int> _wordPiece(String word, Map<String, int> vocab) {
    if (vocab.containsKey(word)) return [vocab[word]!];

    final chars = word.runes.map(String.fromCharCode).toList();
    if (chars.length > _maxInputCharsPerWord) {
      return [_unkId];
    }

    final ids = <int>[];
    var start = 0;
    while (start < chars.length) {
      var end = chars.length;
      String? match;
      while (start < end) {
        var piece = chars.sublist(start, end).join();
        if (start > 0) piece = '##$piece';
        if (vocab.containsKey(piece)) {
          match = piece;
          break;
        }
        end--;
      }
      if (match == null) {
        return [_unkId];
      }
      ids.add(vocab[match]!);
      start = end;
    }
    return ids;
  }

  static bool _isWhitespace(int rune) =>
      rune == 0x20 ||
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      rune == 0x00A0 ||
      rune == 0x200B ||
      rune == 0xFEFF;

  static bool _isControl(int rune) {
    if (rune == 0x09 || rune == 0x0A || rune == 0x0D) return false;
    return (rune < 0x20) || (rune >= 0x7F && rune <= 0x9F);
  }

  static bool _isPunctuation(int code) {
    if ((code >= 33 && code <= 47) ||
        (code >= 58 && code <= 64) ||
        (code >= 91 && code <= 96) ||
        (code >= 123 && code <= 126)) {
      return true;
    }
    // Unicode general punctuation (curly quotes, em/en dashes, ellipsis, etc.) & Latin-1 punctuation
    return (code >= 0x2010 && code <= 0x205E) ||
        (code >= 0x00A1 && code <= 0x00BF);
  }

  static bool _isChineseChar(int cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) ||
        (cp >= 0x3400 && cp <= 0x4DBF) ||
        (cp >= 0x20000 && cp <= 0x2A6DF) ||
        (cp >= 0x2A700 && cp <= 0x2B73F) ||
        (cp >= 0x2B740 && cp <= 0x2B81F) ||
        (cp >= 0x2B820 && cp <= 0x2CEAF) ||
        (cp >= 0xF900 && cp <= 0xFAFF) ||
        (cp >= 0x2F800 && cp <= 0x2FA1F);
  }

  static const Map<int, String> _accentFoldMap = {
    0x00E0: 'a', 0x00E1: 'a', 0x00E2: 'a', 0x00E3: 'a', 0x00E4: 'a', 0x00E5: 'a',
    0x0101: 'a', 0x0103: 'a', 0x0105: 'a',
    0x00E7: 'c', 0x0107: 'c', 0x0109: 'c', 0x010B: 'c', 0x010D: 'c',
    0x010F: 'd', 0x0111: 'd',
    0x00E8: 'e', 0x00E9: 'e', 0x00EA: 'e', 0x00EB: 'e',
    0x0113: 'e', 0x0115: 'e', 0x0117: 'e', 0x0119: 'e', 0x011B: 'e',
    0x011D: 'g', 0x011F: 'g', 0x0121: 'g', 0x0123: 'g',
    0x0125: 'h', 0x0127: 'h',
    0x00EC: 'i', 0x00ED: 'i', 0x00EE: 'i', 0x00EF: 'i',
    0x0129: 'i', 0x012B: 'i', 0x012D: 'i', 0x012F: 'i', 0x0131: 'i',
    0x0135: 'j',
    0x0137: 'k',
    0x013A: 'l', 0x013C: 'l', 0x013E: 'l', 0x0140: 'l', 0x0142: 'l',
    0x00F1: 'n', 0x0144: 'n', 0x0146: 'n', 0x0148: 'n',
    0x00F2: 'o', 0x00F3: 'o', 0x00F4: 'o', 0x00F5: 'o', 0x00F6: 'o', 0x00F8: 'o',
    0x014D: 'o', 0x014F: 'o', 0x0151: 'o',
    0x0155: 'r', 0x0157: 'r', 0x0159: 'r',
    0x015B: 's', 0x015D: 's', 0x015F: 's', 0x0161: 's', 0x00DF: 'ss',
    0x0163: 't', 0x0165: 't', 0x0167: 't',
    0x00F9: 'u', 0x00FA: 'u', 0x00FB: 'u', 0x00FC: 'u',
    0x0169: 'u', 0x016B: 'u', 0x016D: 'u', 0x016F: 'u', 0x0171: 'u', 0x0173: 'u',
    0x0175: 'w',
    0x00FD: 'y', 0x00FF: 'y', 0x0177: 'y',
    0x017A: 'z', 0x017C: 'z', 0x017E: 'z',
  };
}
