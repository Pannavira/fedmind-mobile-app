import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/clinical_constants.dart';
import '../../data/models/screening_models.dart';

class ModalityShapleyChart extends StatelessWidget {
  final PatientModalityAttribution attribution;
  final GlobalReferenceAttribution? globalReference;

  const ModalityShapleyChart({
    super.key,
    required this.attribution,
    this.globalReference,
  });

  Color _getModalityColor(String modality) {
    switch (modality.toLowerCase()) {
      case 'text':
        return ClinicalConstants.textModalityColor;
      case 'visual':
        return ClinicalConstants.visualModalityColor;
      case 'audio':
        return ClinicalConstants.audioModalityColor;
      default:
        return const Color(0xFF0F766E);
    }
  }

  String _getModalityLabel(String modality) {
    switch (modality.toLowerCase()) {
      case 'text':
        return 'Teks / Transkrip';
      case 'visual':
        return 'Visual / Ekspresi';
      case 'audio':
        return 'Audio / Akustik';
      default:
        return modality.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = globalReference ??
        GlobalReferenceAttribution(
          cohort: 'E-DAIC Test Set (N=56)',
          textPct: 61.8,
          visualPct: 33.8,
          audioPct: 4.4,
          dominantModality: 'text',
        );

    final dominantColor = _getModalityColor(attribution.dominantModality);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF0F766E),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Atribusi Modalitas (Exact Shapley)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: dominantColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dominantColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Dominan: ${_getModalityLabel(attribution.dominantModality)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: dominantColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Perbandingan bobot kontribusi sinyal sesi konseling pasien terhadap rujukan kohort klinis (${ref.cohort}).',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),

            // Bar Chart Perbandingan Pasien vs Global
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final modalityName = groupIndex == 0
                            ? 'Teks'
                            : (groupIndex == 1 ? 'Visual' : 'Audio');
                        final isPatient = rodIndex == 0;
                        return BarTooltipItem(
                          '$modalityName\n${isPatient ? "Sesi Pasien" : "Rujukan Global"}: ${rod.toY.toStringAsFixed(1)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          String label = '';
                          IconData icon = Icons.circle;
                          Color col = Colors.grey;

                          switch (value.toInt()) {
                            case 0:
                              label = 'Teks';
                              icon = Icons.text_fields_rounded;
                              col = ClinicalConstants.textModalityColor;
                              break;
                            case 1:
                              label = 'Visual';
                              icon = Icons.face_retouching_natural_rounded;
                              col = ClinicalConstants.visualModalityColor;
                              break;
                            case 2:
                              label = 'Audio';
                              icon = Icons.mic_none_rounded;
                              col = ClinicalConstants.audioModalityColor;
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 13, color: col),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          if (value % 25 == 0) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xFFF1F5F9),
                      strokeWidth: 1.2,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    // Teks (index 0)
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.textPct,
                          color: ClinicalConstants.textModalityColor,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        BarChartRodData(
                          toY: ref.textPct,
                          color: const Color(0xFFE2E8F0),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    // Visual (index 1)
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.visualPct,
                          color: ClinicalConstants.visualModalityColor,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        BarChartRodData(
                          toY: ref.visualPct,
                          color: const Color(0xFFE2E8F0),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    // Audio (index 2)
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.audioPct,
                          color: ClinicalConstants.audioModalityColor,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        BarChartRodData(
                          toY: ref.audioPct,
                          color: const Color(0xFFE2E8F0),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Legenda Warna
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(
                    color: ClinicalConstants.textModalityColor,
                    label: 'Teks Pasien',
                  ),
                  _buildLegendItem(
                    color: ClinicalConstants.visualModalityColor,
                    label: 'Visual Pasien',
                  ),
                  _buildLegendItem(
                    color: ClinicalConstants.audioModalityColor,
                    label: 'Audio Pasien',
                  ),
                  _buildLegendItem(
                    color: const Color(0xFFCBD5E1),
                    label: 'Rujukan Global',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Nilai Kontribusi Eksak Shapley (phi)
            const Text(
              'Dekomposisi Nilai Shapley Eksak (φ):',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Teks Sesi',
                    subtitle: 'Leksikal Afek',
                    pct: attribution.textPct,
                    shap: attribution.shapValues.text,
                    color: ClinicalConstants.textModalityColor,
                    icon: Icons.text_snippet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Visual Sesi',
                    subtitle: 'Ekspresi Mikro',
                    pct: attribution.visualPct,
                    shap: attribution.shapValues.visual,
                    color: ClinicalConstants.visualModalityColor,
                    icon: Icons.face_retouching_natural_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Audio Sesi',
                    subtitle: 'Prosodi Vokal',
                    pct: attribution.audioPct,
                    shap: attribution.shapValues.audio,
                    color: ClinicalConstants.audioModalityColor,
                    icon: Icons.mic_none_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Penjelasan Klinis untuk Psikolog
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA), // Teal 50
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCCFBF1)), // Teal 100
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keterangan: Nilai φ bernilai (+) meningkatkan estimasi depresi relatif terhadap baseline, sedangkan nilai (-) memberikan efek protektif (menurunkan skor).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF115E59),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildShapValueCard({
    required String title,
    required String subtitle,
    required double pct,
    required double shap,
    required Color color,
    required IconData icon,
  }) {
    final isPositive = shap >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: (isPositive ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'φ: ${isPositive ? "+" : ""}${shap.toStringAsFixed(3)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPositive ? const Color(0xFFDC2626) : const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
