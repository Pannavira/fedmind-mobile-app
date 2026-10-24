import 'package:flutter/material.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/widgets/modality_shapley_chart.dart';
import 'package:fedmind_mobile_app/presentation/widgets/quality_flag_alert.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

class ScreeningResultScreen extends StatelessWidget {
  final ScreeningResponse result;

  const ScreeningResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final prediction = result.prediction;
    final attribution = result.patientModalityAttribution;
    final riskCategory = prediction?.riskCategory;
    final phqScore = prediction?.phq8Score ?? 0.0;
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hasil Skrining ${result.participantId}'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hasil skrining tersimpan aman di database server.'),
                ),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KARTU UTAMA SKOR PHQ-8 & STRATIFIKASI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID Pasien: ${result.participantId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sesi: ${result.screeningId.length > 8 ? result.screeningId.substring(0, 8) : result.screeningId}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        RiskBadge(riskCategory: riskCategory, isLarge: true),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Meteran Skor PHQ-8
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: (phqScore / ClinicalConstants.scoreMax).clamp(0.0, 1.0),
                            strokeWidth: 12,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              phqScore.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: riskColor,
                              ),
                            ),
                            const Text(
                              'PHQ-8 Score (0-24)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Keterangan Triase & Proxy Probabilitas
                    Text(
                      ClinicalConstants.getRiskLabel(riskCategory),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ClinicalConstants.getRiskDescription(riskCategory),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),

                    // Baris Indikator Tambahan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDetailStat(
                            label: 'Triase Biner',
                            value: prediction?.binaryPrediction == 'depression_risk'
                                ? 'RISIKO DEPRESI'
                                : 'NON-DEPRESI',
                            valueColor: prediction?.binaryPrediction == 'depression_risk'
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          _buildDetailStat(
                            label: 'Sigmoid Proxy',
                            value: '${((prediction?.riskProbabilityProxy ?? 0) * 100).toStringAsFixed(1)}%',
                            valueColor: const Color(0xFF1E293B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. EXPLAINABLE AI (XAI) CHART
            if (attribution != null)
              ModalityShapleyChart(
                attribution: attribution,
                globalReference: result.globalReference,
              ),
            const SizedBox(height: 16),

            // 3. QUALITY FLAGS INTEGRITAS SINYAL
            QualityFlagAlert(flags: result.qualityFlags),
            const SizedBox(height: 16),

            // 4. NARASI KLINIS SINTETIS DOKTER
            if (result.clinicalNarrative != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notes, color: Color(0xFF1E3A8A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sintesis Narasi Klinis',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.clinicalNarrative!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 5. METADATA MODEL & VERIFIKASI XAI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audit & Verifikasi Ilmiah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow(
                      'Model Active',
                      '${result.model?.name ?? "Baseline"} (${result.model?.modelId ?? "centralized"})',
                    ),
                    _buildMetaRow(
                      'Metode XAI',
                      '${result.xai?.method ?? "Exact Shapley"} (${result.xai?.numCoalitions ?? 8} koalisi)',
                    ),
                    _buildMetaRow(
                      'Aksioma Efisiensi',
                      result.xai?.efficiencyAxiomVerified == true ? 'Terverifikasi (100% Eksak)' : 'Estimasi',
                    ),
                    _buildMetaRow(
                      'Baseline E[f(X)]',
                      result.xai?.baselineExpectedValue.toStringAsFixed(3) ?? '-',
                    ),
                    _buildMetaRow(
                      'Checksum SHA-256',
                      result.model?.checksum.isNotEmpty == true
                          ? result.model!.checksum.substring(0, 12)
                          : '-',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. DISCLAIMER RESMI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.disclaimer ??
                          'Hasil instrumen ini BUKAN diagnosis medis final dan wajib ditinjau klinisi profesional.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }
}
