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
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
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
                    'Integritas Sensor Multimodal Terverifikasi (Quality Check PASS)',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Modalitas Visual (Facial AUs), Modalitas Akustik / Prosodi Audio, dan Modalitas Teks / Linguistik memenuhi ambang batas SNR & variansi sinyal.',
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
        'title': 'Modalitas Teks / Linguistik: Densitas Token Rendah',
        'desc': 'Respons verbal terlalu singkat atau minim indikator leksikal afektif.',
        'icon': Icons.notes_rounded,
      });
    }
    if (flags!.poorAudioQuality) {
      warnings.add({
        'title': 'Modalitas Akustik / Prosodi Audio: SNR Suboptimal / Artefak',
        'desc': 'Energi RMS vokal rendah, gangguan kebisingan lingkungan, atau kualitas mikrofon tidak memadai.',
        'icon': Icons.mic_off_outlined,
      });
    }
    if (flags!.poorVisualQuality) {
      warnings.add({
        'title': 'Modalitas Visual (Facial Action Units / AUs): Variansi Rendah',
        'desc': 'Oklusi wajah, pencahayaan kurang optimal, atau dinamika FACS Action Units sangat datar.',
        'icon': Icons.videocam_off_outlined,
      });
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
                  'Peringatan Audit Integritas Sensor Multimodal:',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
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
                'Detail Diagnostik Sensor: ${flags!.details}',
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
