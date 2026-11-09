import 'package:flutter/material.dart';
import '../../../core/constants/clinical_constants.dart';
import '../../../data/models/screening_models.dart';

class InteractiveShapleyBalance extends StatelessWidget {
  final ScreeningResponse screening;
  final bool isSimpleMode;

  const InteractiveShapleyBalance({
    super.key,
    required this.screening,
    this.isSimpleMode = false,
  });

  static const Color _slateDark = Color(0xFF1E293B);
  static const Color _clinicalTeal = Color(0xFF18B2AC);

  @override
  Widget build(BuildContext context) {
    final baseline = screening.xai?.baselineExpectedValue ?? 8.42;
    final attr = screening.patientModalityAttribution;
    final shap = attr?.shapValues;
    final dAudio = shap?.audio ?? 0.0;
    final dVisual = shap?.visual ?? 0.0;
    final dText = shap?.text ?? 0.0;

    final afterAudio = (baseline + dAudio).clamp(0.0, 24.0);
    final afterVisual = (afterAudio + dVisual).clamp(0.0, 24.0);
    final finalScore =
        screening.prediction?.phq8Score ?? (afterVisual + dText).clamp(0.0, 24.0);
    final riskCategory = screening.prediction?.riskCategory ?? 'low';
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);

    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.balance_rounded,
                  color: Color(0xFF0D9488),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keseimbangan Atribusi Shapley',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kontribusi marginal tiap modalitas terhadap deviasi skor baseline',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // --- FORMULA VISUAL DEKOMPOSISI SHAPLEY ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFormulaPill(
                    title: 'Baseline E[f(X)]',
                    value: baseline.toStringAsFixed(2),
                    color: const Color(0xFF475569),
                  ),
                  _buildOperatorSign(dAudio >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'φ Akustik/Prosodi',
                    value: dAudio.abs().toStringAsFixed(2),
                    color: ClinicalConstants.audioModalityColor,
                  ),
                  _buildOperatorSign(dVisual >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'φ Visual (AUs)',
                    value: dVisual.abs().toStringAsFixed(2),
                    color: _clinicalTeal,
                  ),
                  _buildOperatorSign(dText >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'φ Teks/Linguistik',
                    value: dText.abs().toStringAsFixed(2),
                    color: ClinicalConstants.textModalityColor,
                  ),
                  _buildOperatorSign('='),
                  _buildFormulaPill(
                    title: 'Estimasi PHQ-8',
                    value: finalScore.toStringAsFixed(2),
                    color: riskColor,
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // --- TAHAPAN PERGESERAN SKOR (WATERFALL BREAKDOWN) ---
          _buildWaterfallRow(
            stepNumber: '0',
            title: 'Baseline Ekspektasi Kohort E[f(X)]',
            subtitle:
                'Titik referensi populasi standar (v₀₀₀) sebelum sinyal multimodal pasien diinjeksikan',
            deltaText: 'Prior E[f]',
            runningScore: baseline,
            barColor: const Color(0xFF64748B),
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 8),
          _buildWaterfallRow(
            stepNumber: '1',
            title: 'Modalitas Akustik / Prosodi Audio',
            subtitle: dAudio >= 0
                ? 'Parameter prosodi (pitch F0, jitter, pause ratio) meningkatkan estimasi PHQ-8 sebesar +${dAudio.toStringAsFixed(2)}'
                : 'Kestabilan prosodi & artikulasi vokal menurunkan estimasi PHQ-8 sebesar ${dAudio.toStringAsFixed(2)}',
            deltaText:
                '${dAudio >= 0 ? "+" : ""}${dAudio.toStringAsFixed(2)} (${attr?.audioPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: afterAudio,
            barColor: ClinicalConstants.audioModalityColor,
            icon: Icons.graphic_eq_rounded,
            isPositiveShift: dAudio > 0,
          ),
          const SizedBox(height: 8),
          _buildWaterfallRow(
            stepNumber: '2',
            title: 'Modalitas Visual (Facial Action Units / AUs)',
            subtitle: dVisual >= 0
                ? 'Aktivasi FACS (AU04 Brow Lowerer, AU15 Lip Depressor, hipomimia) menambah skor +${dVisual.toStringAsFixed(2)}'
                : 'Afek fasial responsif (AU12 Zygomaticus) menurunkan skor sebesar ${dVisual.toStringAsFixed(2)}',
            deltaText:
                '${dVisual >= 0 ? "+" : ""}${dVisual.toStringAsFixed(2)} (${attr?.visualPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: afterVisual,
            barColor: _clinicalTeal,
            icon: Icons.face_retouching_natural_rounded,
            isPositiveShift: dVisual > 0,
          ),
          const SizedBox(height: 8),
          _buildWaterfallRow(
            stepNumber: '3',
            title: 'Modalitas Teks / Linguistik',
            subtitle: dText >= 0
                ? 'Valensi semantik negatif & indikator keluhan psikolinguistik menambah skor +${dText.toStringAsFixed(2)}'
                : 'Konstruksi leksikal adaptif menurunkan skor sebesar ${dText.toStringAsFixed(2)}',
            deltaText:
                '${dText >= 0 ? "+" : ""}${dText.toStringAsFixed(2)} (${attr?.textPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: finalScore,
            barColor: ClinicalConstants.textModalityColor,
            icon: Icons.notes_rounded,
            isPositiveShift: dText > 0,
          ),

          const SizedBox(height: 14),

          // --- KESIMPULAN KALKULASI ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: riskColor.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    finalScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ClinicalConstants.getRiskLabel(riskCategory),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Determinan utama prediksi: ${ClinicalConstants.getModalityClinicalName(attr?.dominantModality)} '
                        '(${_getDominantPct(attr)}% bobot atribusi Shapley).',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDominantPct(PatientModalityAttribution? attr) {
    if (attr == null) return '33.3';
    switch (attr.dominantModality.toLowerCase()) {
      case 'audio':
        return attr.audioPct.toStringAsFixed(1);
      case 'visual':
        return attr.visualPct.toStringAsFixed(1);
      case 'text':
        return attr.textPct.toStringAsFixed(1);
      default:
        return attr.visualPct.toStringAsFixed(1);
    }
  }

  Widget _buildFormulaPill({
    required String title,
    required String value,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? color : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? color : color.withValues(alpha: 0.35),
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? Colors.white.withValues(alpha: 0.9) : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: isHighlighted ? Colors.white : _slateDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorSign(String op) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        op,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildWaterfallRow({
    required String stepNumber,
    required String title,
    required String subtitle,
    required String deltaText,
    required double runningScore,
    required Color barColor,
    required IconData icon,
    bool? isPositiveShift,
  }) {
    final normWidth = (runningScore / 24.0).clamp(0.05, 1.0);
    return Container(
      padding: const EdgeInsets.all(11),
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
              Icon(icon, size: 15, color: barColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _slateDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isPositiveShift == null
                      ? const Color(0xFFE2E8F0)
                      : (isPositiveShift
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isPositiveShift == null
                        ? const Color(0xFF475569)
                        : (isPositiveShift
                            ? const Color(0xFFB45309)
                            : const Color(0xFF15803D)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: normWidth,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'PHQ-8: ${runningScore.toStringAsFixed(2)} / 24',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _slateDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
