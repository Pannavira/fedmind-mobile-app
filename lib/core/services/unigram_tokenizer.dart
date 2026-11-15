import 'dart:convert';
import 'dart:math';

/// Entri potongan kosakata (subword piece) pada model SentencePiece Unigram.
class UnigramPieceEntry {
  final int id;
  final double score;

  const UnigramPieceEntry(this.id, this.score);
}

/// Parser dan encoder SentencePiece Unigram berbasis HuggingFace `tokenizer.json`
/// (untuk `intfloat/multilingual-e5-small` yang didistilasi ke ruang MentalBERT).
class UnigramTokenizer {
  final Map<String, UnigramPieceEntry> _vocabScores;
  final int maxPieceCodePoints;
  final int bosId;
  final int padId;
  final int eosId;
  final int unkId;
  final double unkPenalty;
  final String metaspace;
  final bool addPrefixSpace;

  const UnigramTokenizer._(
    this._vocabScores, {
    required this.maxPieceCodePoints,
    required this.bosId,
    required this.padId,
    required this.eosId,
    required this.unkId,
    required this.unkPenalty,
    required this.metaspace,
    required this.addPrefixSpace,
  });

  /// Membangun [UnigramTokenizer] langsung dari isi JSON `tokenizer.json`.
  factory UnigramTokenizer.fromJsonString(String rawJson) {
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final model = decoded['model'] as Map<String, dynamic>;
    final vocabRaw = model['vocab'] as List<dynamic>;

    int bosId = 0;
    int padId = 1;
    int eosId = 2;
    int unkId = (model['unk_id'] as num?)?.toInt() ?? 3;

    final specialContents = <String>{};
    final addedRaw = decoded['added_tokens'] as List<dynamic>?;
    if (addedRaw != null) {
      for (final item in addedRaw) {
        if (item is Map<String, dynamic>) {
          final content = item['content'] as String? ?? '';
          final id = (item['id'] as num?)?.toInt();
          if (content.isNotEmpty) {
            specialContents.add(content);
          }
          if (content == '<s>' && id != null) bosId = id;
          if (content == '<pad>' && id != null) padId = id;
          if (content == '</s>' && id != null) eosId = id;
          if (content == '<unk>' && id != null) unkId = id;
        }
      }
    }

    String metaspace = '\u2581'; // '▁'
    bool addPrefixSpace = true;
    final preTok = decoded['pre_tokenizer'] as Map<String, dynamic>?;
    if (preTok != null && preTok['type'] == 'Metaspace') {
      metaspace = preTok['replacement'] as String? ?? '\u2581';
      addPrefixSpace = preTok['add_prefix_space'] as bool? ?? true;
    }

    final vocabScores = <String, UnigramPieceEntry>{};
    int maxLen = 1;
    double minScore = 0.0;

    for (int idx = 0; idx < vocabRaw.length; idx++) {
      final pair = vocabRaw[idx] as List<dynamic>;
      final piece = pair[0] as String;
      if (specialContents.contains(piece)) continue;
      final score = (pair[1] as num).toDouble();
      vocabScores[piece] = UnigramPieceEntry(idx, score);
      final cpLen = piece.runes.length;
      if (cpLen > maxLen) maxLen = cpLen;
      if (score < minScore) minScore = score;
    }

    return UnigramTokenizer._(
      vocabScores,
      maxPieceCodePoints: maxLen,
      bosId: bosId,
      padId: padId,
      eosId: eosId,
      unkId: unkId,
      unkPenalty: minScore - 10.0,
      metaspace: metaspace,
      addPrefixSpace: addPrefixSpace,
    );
  }

  /// Normalisasi ringan yang setara dengan precompiled NFKC + whitespace collapse SentencePiece.
  static String normalizeText(String raw) {
    if (raw.isEmpty) return '';
    final buf = StringBuffer();
    bool prevSpace = true;

    for (final rune in raw.runes) {
      int r = rune;
      // Fullwidth ASCII variants (U+FF01..U+FF5E -> U+0021..U+007E)
      if (r >= 0xFF01 && r <= 0xFF5E) {
        r -= 0xFEE0;
      } else if (r == 0x00A0 ||
          r == 0x1680 ||
          (r >= 0x2000 && r <= 0x200A) ||
          r == 0x2028 ||
          r == 0x2029 ||
          r == 0x202F ||
          r == 0x205F ||
          r == 0x3000 ||
          r == 0x09 ||
          r == 0x0A ||
          r == 0x0B ||
          r == 0x0C ||
          r == 0x0D ||
          r == 0x20) {
        r = 0x20;
      } else if (r == 0xFEFF || (r >= 0x200B && r <= 0x200D)) {
        continue;
      }

      if (r == 0x20) {
        if (!prevSpace) {
          buf.writeCharCode(0x20);
          prevSpace = true;
        }
      } else {
        buf.writeCharCode(r);
        prevSpace = false;
      }
    }
    return buf.toString().trim();
  }

  /// Mengodekan teks menjadi daftar token ID tanpa special tokens (`<s>`/`</s>`).
  List<int> encodeBodyIds(String text) {
    final normalized = normalizeText(text);
    if (normalized.isEmpty) return const <int>[];

    final words = normalized.split(' ');
    final allIds = <int>[];

    for (int w = 0; w < words.length; w++) {
      final word = words[w];
      if (word.isEmpty) continue;
      final prefix = (w > 0 || addPrefixSpace) ? metaspace : '';
      final pieceInput = '$prefix$word';
      final wordIds = _viterbiEncodeWord(pieceInput);
      for (final id in wordIds) {
        if (id == unkId && allIds.isNotEmpty && allIds.last == unkId) {
          continue;
        }
        allIds.add(id);
      }
    }
    return allIds;
  }

  /// Mengodekan teks dengan batasan `maxLength` termasuk `<s>` dan `</s>`.
  List<int> encodeIds(String text, {int maxLength = 512}) {
    final bodyLimit = max(0, maxLength - 2);
    final bodyIds = encodeBodyIds(text);
    final sliced =
        bodyIds.length > bodyLimit ? bodyIds.sublist(0, bodyLimit) : bodyIds;
    return <int>[bosId, ...sliced, eosId];
  }

  /// Membagi teks panjang menjadi sliding-window chunks berbungkus `[bosId, ..., eosId]`.
  List<List<int>> encodeChunks(
    String text, {
    int maxLength = 512,
    int chunkStride = 256,
  }) {
    final bodyLimit = max(1, maxLength - 2);
    final bodyIds = encodeBodyIds(text);
    if (bodyIds.isEmpty) {
      return <List<int>>[
        <int>[bosId, eosId],
      ];
    }
    if (bodyIds.length <= bodyLimit) {
      return <List<int>>[
        <int>[bosId, ...bodyIds, eosId],
      ];
    }

    final chunks = <List<int>>[];
    int start = 0;
    while (start < bodyIds.length) {
      final end = min(start + bodyLimit, bodyIds.length);
      chunks.add(<int>[bosId, ...bodyIds.sublist(start, end), eosId]);
      if (end >= bodyIds.length) break;
      start += chunkStride;
    }
    return chunks;
  }

  List<int> _viterbiEncodeWord(String wordWithMetaspace) {
    final cps = wordWithMetaspace.runes.toList(growable: false);
    final n = cps.length;
    if (n == 0) return const <int>[];

    const double negInf = -1e18;
    final bestScore = List<double>.filled(n + 1, negInf);
    final bestId = List<int>.filled(n + 1, unkId);
    final bestPrev = List<int>.filled(n + 1, -1);
    bestScore[0] = 0.0;

    for (int i = 0; i < n; i++) {
      final baseScore = bestScore[i];
      if (baseScore <= negInf * 0.5) continue;

      final limit = min(n, i + maxPieceCodePoints);
      bool matchedSingle = false;
      final subBuf = StringBuffer();

      for (int j = i; j < limit; j++) {
        subBuf.writeCharCode(cps[j]);
        final sub = subBuf.toString();
        final entry = _vocabScores[sub];
        if (entry != null) {
          final cand = baseScore + entry.score;
          final nextIdx = j + 1;
          if (cand > bestScore[nextIdx]) {
            bestScore[nextIdx] = cand;
            bestId[nextIdx] = entry.id;
            bestPrev[nextIdx] = i;
          }
          if (j == i) matchedSingle = true;
        }
      }

      if (!matchedSingle) {
        final cand = baseScore + unkPenalty;
        if (cand > bestScore[i + 1]) {
          bestScore[i + 1] = cand;
          bestId[i + 1] = unkId;
          bestPrev[i + 1] = i;
        }
      }
    }

    final reversed = <int>[];
    int cur = n;
    while (cur > 0) {
      final prev = bestPrev[cur];
      if (prev < 0) break;
      reversed.add(bestId[cur]);
      cur = prev;
    }
    return reversed.reversed.toList(growable: false);
  }
}

