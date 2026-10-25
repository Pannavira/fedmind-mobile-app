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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4), // Emerald 50
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)), // Emerald 200
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF059669),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integritas Sinyal Sesi Valid',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kualitas tensor teks, akustik suara, & video ekspresi memenuhi standar baku inferensi.',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final warnings = <Map<String, dynamic>>[];
    if (flags!.lowTextInformation) {
      warnings.add({
        'title': 'Kuantitas Transkrip Teks Rendah',
        'desc': 'Respons verbal terlalu singkat atau leksikon afektif minim.',
        'icon': Icons.chat_bubble_outline,
      });
    }
    if (flags!.poorAudioQuality) {
      warnings.add({
        'title': 'Kualitas Sinyal Audio Lemah',
        'desc': 'Energi vokal rendah, volume mikrofon tidak memadai, atau derau latar belakang.',
        'icon': Icons.mic_off_outlined,
      });
    }
    if (flags!.poorVisualQuality) {
      warnings.add({
        'title': 'Dinamika Ekspresi Wajah Rendah',
        'desc': 'Mikro-ekspresi fasial minim atau oklusi pencahayaan/kamera.',
        'icon': Icons.videocam_off_outlined,
      });
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Catatan Validitas Sinyal Multimodal:',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    w['icon'] as IconData,
                    size: 16,
                    color: const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w['title'] as String,
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          w['desc'] as String,
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (flags!.details != null && flags!.details!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Detail Diagnostik: ${flags!.details}',
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
