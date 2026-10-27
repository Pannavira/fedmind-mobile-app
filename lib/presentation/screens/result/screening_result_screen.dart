import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/widgets/local_video_player_dialog.dart';
import 'package:fedmind_mobile_app/presentation/widgets/modality_shapley_chart.dart';
import 'package:fedmind_mobile_app/presentation/widgets/quality_flag_alert.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

class ScreeningResultScreen extends StatefulWidget {
  final ScreeningResponse result;
  final String? localVideoPath;

  const ScreeningResultScreen({
    super.key,
    required this.result,
    this.localVideoPath,
  });

  @override
  State<ScreeningResultScreen> createState() => _ScreeningResultScreenState();
}

class _ScreeningResultScreenState extends State<ScreeningResultScreen> {
  final TextEditingController _counselorActionNoteController = TextEditingController();
  bool _isTechnicalAuditExpanded = false;

  @override
  void dispose() {
    _counselorActionNoteController.dispose();
    super.dispose();
  }

  void _copyClinicalSummary(BuildContext context) {
    final prediction = widget.result.prediction;
    final riskCategory = prediction?.riskCategory ?? 'unknown';
    final phqScore = prediction?.phq8Score.toStringAsFixed(2) ?? '0.00';
    final dominantMod = widget.result.patientModalityAttribution?.dominantModality ?? '-';

    final summary = '''
=== RINGKASAN ASESMEN KLINIS FED-MIND ===
ID Pasien: ${widget.result.participantId}
ID Sesi: ${widget.result.screeningId}
Estimasi PHQ-8: $phqScore / 24.0
Kategori Risiko: ${ClinicalConstants.getRiskLabel(riskCategory)}
Modalitas Dominan: ${dominantMod.toUpperCase()}
Narasi Klinis: ${widget.result.clinicalNarrative ?? '-'}
Rekomendasi Konseling: ${ClinicalConstants.getCounselingGuidance(riskCategory)}
Catatan Tambahan Konselor: ${_counselorActionNoteController.text.trim()}
========================================
''';

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan asesmen klinis berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF0F766E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final prediction = result.prediction;
    final attribution = result.patientModalityAttribution;
    final riskCategory = prediction?.riskCategory;
    final phqScore = prediction?.phq8Score ?? 0.0;
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil Asesmen: ${result.participantId}'),
            const Text(
              'Laporan Keputusan Klinis & Explainable AI',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _copyClinicalSummary(context),
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Salin Ringkasan Rekam Medis',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KARTU UTAMA SKOR PHQ-8 & STRATIFIKASI KLINIS
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  size: 15,
                                  color: Color(0xFF0F766E),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'ID: ${result.participantId}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sesi: ${result.screeningId.length > 8 ? result.screeningId.substring(0, 8) : result.screeningId}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        RiskBadge(riskCategory: riskCategory, isLarge: true),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Meteran Skor PHQ-8
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 146,
                          height: 146,
                          child: CircularProgressIndicator(
                            value: (phqScore / ClinicalConstants.scoreMax).clamp(0.0, 1.0),
                            strokeWidth: 13,
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
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: riskColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'PHQ-8 (Skala 0–24)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Keterangan Triase & Stratifikasi
                    Text(
                      ClinicalConstants.getRiskLabel(riskCategory),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: riskColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ClinicalConstants.getRiskDescription(riskCategory),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Indikator Triase Biner & Sigmoid Proxy
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            value:
                                '${((prediction?.riskProbabilityProxy ?? 0) * 100).toStringAsFixed(1)}%',
                            valueColor: const Color(0xFF0F172A),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Panduan Intervensi Konseling Psikolog
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA), // Teal 50
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.psychology_rounded,
                                color: Color(0xFF0F766E),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ClinicalConstants.getCounselingActionTitle(riskCategory),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ClinicalConstants.getCounselingGuidance(riskCategory),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF115E59),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.localVideoPath != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.video_library_rounded,
                          color: Color(0xFF0F766E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rekaman Sesi Tersimpan di HP',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Privat di memori HP konselor (Tidak diunggah)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          LocalVideoPlayerDialog.show(
                            context,
                            videoPath: widget.localVideoPath!,
                            participantId: result.participantId,
                          );
                        },
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                        label: const Text('Tonton', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notes_rounded, color: Color(0xFF0F766E), size: 19),
                              SizedBox(width: 8),
                              Text(
                                'Sintesis Narasi Klinis',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: result.clinicalNarrative!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Narasi klinis berhasil disalin!'),
                                  backgroundColor: Color(0xFF0F766E),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 13),
                            label: const Text('Salin Narasi', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          result.clinicalNarrative!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 5. CATATAN INTERVENSI KONSELOR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Catatan Rencana Sesi Konselor',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _counselorActionNoteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Tulis catatan rencana intervensi konseling, tindak lanjut sesi, atau observasi kualitatif...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. METADATA MODEL & VERIFIKASI XAI (COLLAPSIBLE AUDIT)
            Card(
              child: ExpansionTile(
                initiallyExpanded: _isTechnicalAuditExpanded,
                onExpansionChanged: (val) {
                  setState(() {
                    _isTechnicalAuditExpanded = val;
                  });
                },
                leading: const Icon(Icons.verified_outlined, color: Color(0xFF0F766E), size: 20),
                title: const Text(
                  'Audit Ilmiah & Verifikasi Aksioma',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Akurasi 8 koalisi laten dan efisiensi Shapley',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 6),
                        _buildMetaRow(
                          'Model Aktif',
                          '${result.model?.name ?? "Baseline"} (${result.model?.modelId ?? "centralized"})',
                        ),
                        _buildMetaRow(
                          'Arsitektur Model',
                          result.model?.architecture ?? 'Late-Fusion Attention',
                        ),
                        _buildMetaRow(
                          'Metode XAI',
                          '${result.xai?.method ?? "Exact Shapley"} (${result.xai?.numCoalitions ?? 8} koalisi)',
                        ),
                        _buildMetaRow(
                          'Aksioma Efisiensi',
                          result.xai?.efficiencyAxiomVerified == true
                              ? 'Terverifikasi (100% Eksak)'
                              : 'Estimasi Stokastik',
                        ),
                        _buildMetaRow(
                          'Baseline E[f(X)]',
                          result.xai?.baselineExpectedValue.toStringAsFixed(3) ?? '-',
                        ),
                        _buildMetaRow(
                          'Checksum SHA-256',
                          result.model?.checksum.isNotEmpty == true
                              ? result.model!.checksum.substring(0, 16)
                              : '-',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 7. DISCLAIMER MEDIS RESMI
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.disclaimer ??
                          'PEMBERITAHUAN KLINIS: Hasil instrumen FED-MIND ini merupakan Clinical Decision Support (CDS) dan BUKAN diagnosis medis/psikiatri otonom. Keputusan intervensi medis tetap menjadi wewenang dan tanggung jawab klinisi profesional.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.45,
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
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
