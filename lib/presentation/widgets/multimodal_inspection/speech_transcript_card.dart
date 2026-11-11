import 'package:flutter/material.dart';

import '../../../data/models/multimodal_inspection_models.dart';

class SpeechTranscriptCard extends StatelessWidget {
  final MultimodalInspectionData inspection;
  final bool isSimpleMode;

  const SpeechTranscriptCard({
    super.key,
    required this.inspection,
    this.isSimpleMode = true,
  });

  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _slateDark = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER MODALITAS TEKS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brandPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.subtitles_rounded,
                    color: _brandPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              inspection.isWhisperTranscribed
                                  ? 'Transkrip Whisper & MentalBERT 768D'
                                  : (inspection.isExplicitTranscript
                                      ? 'Transkrip & Analisis Kata'
                                      : 'Sintesis Tuturan & Perilaku Vokal'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _slateDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: inspection.isWhisperTranscribed
                                  ? const Color(0xFFD1FAE5)
                                  : (inspection.isExplicitTranscript
                                      ? const Color(0xFFEDE9FE)
                                      : const Color(0xFFCCFBF1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inspection.isWhisperTranscribed
                                  ? 'Whisper Base (ID ➔ EN)'
                                  : (inspection.isExplicitTranscript
                                      ? 'Verbatim'
                                      : 'Sintesis Akustik & Visual'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: inspection.isWhisperTranscribed
                                    ? const Color(0xFF065F46)
                                    : (inspection.isExplicitTranscript
                                        ? _brandPurple
                                        : const Color(0xFF0F766E)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inspection.isWhisperTranscribed
                            ? 'Transkripsi tuturan Bahasa Indonesia & translasi otomatis ke Bahasa Inggris (MentalBERT)'
                            : (inspection.isExplicitTranscript
                                ? 'Analisis kata kunci percakapan dan ekspresi semantik emosi klien'
                                : 'Profil observasi wicara & afek yang disintesis dari biometrik video klien'),
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
          ),

          // --- SEGMEN TRANSKRIP BERTANDA AFEK EMOSI ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        inspection.isWhisperTranscribed
                            ? Icons.record_voice_over_rounded
                            : (inspection.isExplicitTranscript
                                ? Icons.format_quote_rounded
                                : Icons.graphic_eq_rounded),
                        size: 16,
                        color: inspection.isWhisperTranscribed
                            ? const Color(0xFF059669)
                            : (inspection.isExplicitTranscript
                                ? _brandPurple
                                : const Color(0xFF0D9488)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          inspection.isWhisperTranscribed
                              ? 'Transkrip Tuturan Klien (Whisper On-Device):'
                              : (inspection.isExplicitTranscript
                                  ? 'Transkrip Percakapan Klien (Verbatim):'
                                  : 'Sintesis Tuturan & Perilaku Vokal Video:'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _slateDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!inspection.isExplicitTranscript) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Diekstraksi secara otomatis dari fluktuasi pitch (Hz), pola jeda bicara, serta aktivasi FACS wajah.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ...inspection.transcriptSegments.map((seg) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (inspection.isExplicitTranscript
                                            ? _brandPurple
                                            : const Color(0xFF0D9488))
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    seg.timeRangeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: inspection.isExplicitTranscript
                                          ? _brandPurple
                                          : const Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    seg.prosodyNote,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              inspection.isExplicitTranscript
                                  ? '"${seg.text}"'
                                  : seg.text,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                                fontStyle: inspection.isExplicitTranscript
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                                height: 1.45,
                              ),
                            ),
                            if (seg.translatedText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'MentalBERT (EN)',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF4338CA),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '"${seg.translatedText}"',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // --- MARKER PSIKOLINGUISTIK YANG DITEMUKAN ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSimpleMode
                      ? 'Penanda Leksikal & Afek Kognitif Terdeteksi:'
                      : 'Token Leksikon Psikolinguistik Terdeteksi (MentalBERT Embedding):',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _slateDark,
                  ),
                ),
                const SizedBox(height: 8),
                if (inspection.detectedKeywords.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Tidak ada penanda leksikon afek depresif khusus yang terdeteksi secara dominan.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: inspection.detectedKeywords.map((kw) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sell_outlined,
                              size: 12,
                              color: _brandPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              kw,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5B21B6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // --- INTERPRETASI PSIKOLINGUISTIK KLINIS ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_alt_rounded,
                        size: 16,
                        color: _brandPurple,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Evaluasi Psikolinguistik: ${inspection.linguisticTitle}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inspection.linguisticDescription,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4C1D95),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
