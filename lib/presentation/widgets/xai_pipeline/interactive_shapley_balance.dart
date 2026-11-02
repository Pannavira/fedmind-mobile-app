import 'package:flutter/material.dart';
import '../../../core/constants/clinical_constants.dart';
import '../../../data/models/screening_models.dart';

class InteractiveShapleyBalance extends StatelessWidget {
  final ScreeningResponse screening;
  final bool isSimpleMode;

  const InteractiveShapleyBalance({
    super.key,
    required this.screening,
    this.isSimpleMode = true,
  });

  static const Color _slateDark = Color(0xFF0F172A);
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);

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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                  color: _brandTeal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: _brandTealDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSimpleMode
                          ? 'Bagaimana AI Menghitung Skor Anda?'
                          : 'Dekomposisi Aditif Exact Shapley (E[f(X)] + ∑φᵢ)',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSimpleMode
                          ? 'Lihat bagaimana suara, wajah, dan cerita menggeser skor awal menjadi hasil akhir'
                          : 'Aksioma efisiensi terverifikasi pada 8 koalisi laten ONNX',
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
          const SizedBox(height: 16),

          // --- FORMULA VISUAL SEDERHANA DI ATAS ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFormulaPill(
                    title: 'Skor Awal',
                    value: baseline.toStringAsFixed(2),
                    color: const Color(0xFF475569),
                  ),
                  _buildOperatorSign(dAudio >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'Suara',
                    value: dAudio.abs().toStringAsFixed(2),
                    color: const Color(0xFF0284C7),
                  ),
                  _buildOperatorSign(dVisual >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'Wajah',
                    value: dVisual.abs().toStringAsFixed(2),
                    color: _brandTealDark,
                  ),
                  _buildOperatorSign(dText >= 0 ? '+' : '−'),
                  _buildFormulaPill(
                    title: 'Cerita',
                    value: dText.abs().toStringAsFixed(2),
                    color: const Color(0xFF7C3AED),
                  ),
                  _buildOperatorSign('='),
                  _buildFormulaPill(
                    title: 'Skor Akhir',
                    value: finalScore.toStringAsFixed(2),
                    color: riskColor,
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // --- TAHAPAN PERGESERAN SKOR (WATERFALL BREAKDOWN) ---
          _buildWaterfallRow(
            stepNumber: '0',
            title: 'Titik Awal Rata-rata (Baseline)',
            subtitle:
                'Nilai awal standar sebelum AI membaca rekaman wajah & suara Anda',
            deltaText: 'Awal',
            runningScore: baseline,
            barColor: const Color(0xFF64748B),
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 10),
          _buildWaterfallRow(
            stepNumber: '1',
            title: 'Kontribusi Gelombang & Nada Suara',
            subtitle: dAudio >= 0
                ? 'Pola intonasi & jeda suara menaikkan indikasi beban sebesar +${dAudio.toStringAsFixed(2)}'
                : 'Intonasi suara yang tenang & stabil menurunkan indikasi beban sebesar ${dAudio.toStringAsFixed(2)}',
            deltaText:
                '${dAudio >= 0 ? "+" : ""}${dAudio.toStringAsFixed(2)} (${attr?.audioPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: afterAudio,
            barColor: const Color(0xFF0284C7),
            icon: Icons.graphic_eq_rounded,
            isPositiveShift: dAudio > 0,
          ),
          const SizedBox(height: 10),
          _buildWaterfallRow(
            stepNumber: '2',
            title: 'Kontribusi Ekspresi & Gerak Wajah',
            subtitle: dVisual >= 0
                ? 'Dinamika ekspresi wajah & tatapan menambah skor sebesar +${dVisual.toStringAsFixed(2)}'
                : 'Ekspresi wajah yang responsif & rileks menurunkan skor sebesar ${dVisual.toStringAsFixed(2)}',
            deltaText:
                '${dVisual >= 0 ? "+" : ""}${dVisual.toStringAsFixed(2)} (${attr?.visualPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: afterVisual,
            barColor: _brandTealDark,
            icon: Icons.face_retouching_natural_rounded,
            isPositiveShift: dVisual > 0,
          ),
          const SizedBox(height: 10),
          _buildWaterfallRow(
            stepNumber: '3',
            title: 'Kontribusi Transkrip & Pilihan Kata',
            subtitle: dText >= 0
                ? 'Ungkapan keluhan dalam cerita menambah skor sebesar +${dText.toStringAsFixed(2)}'
                : 'Kalimat yang positif & tenang menurunkan skor sebesar ${dText.toStringAsFixed(2)}',
            deltaText:
                '${dText >= 0 ? "+" : ""}${dText.toStringAsFixed(2)} (${attr?.textPct.toStringAsFixed(1) ?? "0"}%)',
            runningScore: finalScore,
            barColor: const Color(0xFF7C3AED),
            icon: Icons.subtitles_rounded,
            isPositiveShift: dText > 0,
          ),

          const SizedBox(height: 16),

          // --- KESIMPULAN KALKULASI ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: riskColor.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    finalScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
                        'Hasil Akhir: ${ClinicalConstants.getRiskLabel(riskCategory)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Faktor paling berpengaruh pada sesi Anda adalah ${_translateModality(attr?.dominantModality)} '
                        '(${_getDominantPct(attr)}% dari total keputusan model).',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF334155),
                          height: 1.4,
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

  String _translateModality(String? mod) {
    switch (mod?.toLowerCase()) {
      case 'audio':
        return 'Gelombang & Nada Suara';
      case 'visual':
        return 'Ekspresi & Gerak Wajah';
      case 'text':
        return 'Transkrip Cerita & Kata';
      default:
        return 'Ekspresi & Suara';
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isHighlighted ? color : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? color : color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? Colors.white.withValues(alpha: 0.9) : color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        op,
        style: const TextStyle(
          fontSize: 16,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: barColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _slateDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPositiveShift == null
                      ? const Color(0xFFE2E8F0)
                      : (isPositiveShift
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  deltaText,
                  style: TextStyle(
                    fontSize: 10.5,
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
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: normWidth,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Skor: ${runningScore.toStringAsFixed(2)} / 24',
                style: const TextStyle(
                  fontSize: 11,
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

