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
        return ClinicalConstants.clinicalTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = globalReference ??
        GlobalReferenceAttribution(
          cohort: 'E-DAIC Clinical Benchmark (N=56)',
          textPct: 61.8,
          visualPct: 33.8,
          audioPct: 4.4,
          dominantModality: 'text',
        );

    final dominantColor = _getModalityColor(attribution.dominantModality);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: Color(0xFF0D9488),
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atribusi Modalitas XAI (Exact Shapley Value)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: dominantColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dominantColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Dominan: ${ClinicalConstants.getModalityCompactName(attribution.dominantModality)}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: dominantColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Komparasi bobot kontribusi sinyal pasien terhadap distribusi referensi kohort klinis (${ref.cohort}).',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Bar Chart Perbandingan Pasien vs Global
            SizedBox(
              height: 185,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final modalityName = groupIndex == 0
                            ? 'Modalitas Teks / Linguistik'
                            : (groupIndex == 1
                                ? 'Modalitas Visual (Facial AUs)'
                                : 'Modalitas Akustik / Prosodi Audio');
                        final isPatient = rodIndex == 0;
                        return BarTooltipItem(
                          '$modalityName\n${isPatient ? "Sesi Klien" : "Referensi Kohort"}: ${rod.toY.toStringAsFixed(1)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
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
                              label = 'Teks / Linguistik';
                              icon = Icons.notes_rounded;
                              col = ClinicalConstants.textModalityColor;
                              break;
                            case 1:
                              label = 'Visual (AUs)';
                              icon = Icons.face_retouching_natural_rounded;
                              col = ClinicalConstants.visualModalityColor;
                              break;
                            case 2:
                              label = 'Akustik / Prosodi';
                              icon = Icons.graphic_eq_rounded;
                              col = ClinicalConstants.audioModalityColor;
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 12, color: col),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
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
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
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
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.textPct,
                          color: ClinicalConstants.textModalityColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: ref.textPct,
                          color: const Color(0xFFCBD5E1),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.visualPct,
                          color: ClinicalConstants.visualModalityColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: ref.visualPct,
                          color: const Color(0xFFCBD5E1),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: attribution.audioPct,
                          color: ClinicalConstants.audioModalityColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: ref.audioPct,
                          color: const Color(0xFFCBD5E1),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Color Legend
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 10,
                runSpacing: 4,
                children: [
                  _buildLegendItem(
                    color: ClinicalConstants.textModalityColor,
                    label: 'Modalitas Teks / Linguistik',
                  ),
                  _buildLegendItem(
                    color: ClinicalConstants.visualModalityColor,
                    label: 'Modalitas Visual (Facial AUs)',
                  ),
                  _buildLegendItem(
                    color: ClinicalConstants.audioModalityColor,
                    label: 'Modalitas Akustik / Prosodi',
                  ),
                  _buildLegendItem(
                    color: const Color(0xFFCBD5E1),
                    label: 'Referensi Kohort (E-DAIC)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Exact Shapley Decomposition Values (phi)
            const Text(
              'Nilai Dekomposisi Marginal Exact Shapley (φ):',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Modalitas Teks',
                    subtitle: 'Linguistik (768D)',
                    pct: attribution.textPct,
                    shap: attribution.shapValues.text,
                    color: ClinicalConstants.textModalityColor,
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Modalitas Visual',
                    subtitle: 'Facial AUs (75D)',
                    pct: attribution.visualPct,
                    shap: attribution.shapValues.visual,
                    color: ClinicalConstants.visualModalityColor,
                    icon: Icons.face_retouching_natural_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Modalitas Akustik',
                    subtitle: 'Prosodi Audio (248D)',
                    pct: attribution.audioPct,
                    shap: attribution.shapValues.audio,
                    color: ClinicalConstants.audioModalityColor,
                    icon: Icons.graphic_eq_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Clinical Explanation
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xFF0D9488)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interpretasi Klinis XAI: Nilai φ positif (+) mengindikasikan fitur modalitas meningkatkan estimasi keparahan PHQ-8 terhadap baseline E[f(X)], sedangkan nilai φ negatif (−) bertindak sebagai faktor protektif penurun skor.',
                      style: TextStyle(
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
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
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
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
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
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
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
                fontWeight: FontWeight.w800,
                color: isPositive ? const Color(0xFFDC2626) : const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
