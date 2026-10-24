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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Atribusi Modalitas (Exact Shapley)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Dominan: ${attribution.dominantModality.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Perbandingan persentase kontribusi pasien dengan rujukan kohort (${ref.cohort}).',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // Bar Chart Perbandingan Pasien vs Global
            SizedBox(
              height: 190,
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
                          '$modalityName\n${isPatient ? "Pasien" : "Global"}: ${rod.toY.toStringAsFixed(1)}%',
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
                          switch (value.toInt()) {
                            case 0:
                              label = 'Teks';
                              break;
                            case 1:
                              label = 'Visual';
                              break;
                            case 2:
                              label = 'Audio';
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value % 25 == 0) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
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
                      strokeWidth: 1,
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
                    // Visual (index 1)
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
                    // Audio (index 2)
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

            // Legenda Warna
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  color: ClinicalConstants.textModalityColor,
                  label: 'Pasien (Teks)',
                ),
                const SizedBox(width: 12),
                _buildLegendItem(
                  color: ClinicalConstants.visualModalityColor,
                  label: 'Pasien (Visual)',
                ),
                const SizedBox(width: 12),
                _buildLegendItem(
                  color: ClinicalConstants.audioModalityColor,
                  label: 'Pasien (Audio)',
                ),
                const SizedBox(width: 12),
                _buildLegendItem(
                  color: const Color(0xFFCBD5E1),
                  label: 'Global Cohort',
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Tabel Nilai Eksak Shapley (phi)
            const Text(
              'Nilai Kontribusi Shapley Eksak (φ):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Teks',
                    pct: attribution.textPct,
                    shap: attribution.shapValues.text,
                    color: ClinicalConstants.textModalityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Visual',
                    pct: attribution.visualPct,
                    shap: attribution.shapValues.visual,
                    color: ClinicalConstants.visualModalityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildShapValueCard(
                    title: 'Audio',
                    pct: attribution.audioPct,
                    shap: attribution.shapValues.audio,
                    color: ClinicalConstants.audioModalityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '* Nilai (+) mendorong skor ke arah depresi, nilai (-) menurunkan estimasi risiko.',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildShapValueCard({
    required String title,
    required double pct,
    required double shap,
    required Color color,
  }) {
    final isPositive = shap >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          Text(
            'φ: ${isPositive ? "+" : ""}${shap.toStringAsFixed(3)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPositive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}
