import 'package:flutter/material.dart';
import '../../data/models/screening_models.dart';

class QualityFlagAlert extends StatelessWidget {
  final QualityFlags? flags;

  const QualityFlagAlert({super.key, required this.flags});

  @override
  Widget build(BuildContext context) {
    if (flags == null) return const SizedBox.shrink();

    final hasWarning = flags!.lowTextInformation ||
        flags!.poorAudioQuality ||
        flags!.poorVisualQuality;

    if (!hasWarning) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kualitas Sinyal Multimodal Valid (Semua sensor optimal).',
                style: TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final warnings = <String>[];
    if (flags!.lowTextInformation) {
      warnings.add('Variasi/kuantitas teks sangat rendah (jawaban terlalu singkat)');
    }
    if (flags!.poorAudioQuality) {
      warnings.add('Sinyal audio mendekati nol / energi vokal minim');
    }
    if (flags!.poorVisualQuality) {
      warnings.add('Dinamika wajah minim variasi / statis');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
              SizedBox(width: 8),
              Text(
                'Peringatan Integritas Sinyal Multimodal:',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(
                '• $w',
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (flags!.details != null && flags!.details!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(
                'Detail: ${flags!.details}',
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
