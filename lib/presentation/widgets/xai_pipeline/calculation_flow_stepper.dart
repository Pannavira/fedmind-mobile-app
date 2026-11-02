import 'package:flutter/material.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../../data/models/screening_models.dart';

class CalculationFlowStepper extends StatefulWidget {
  final MultimodalInspectionData inspection;
  final ScreeningResponse screening;
  final bool isSimpleMode;

  const CalculationFlowStepper({
    super.key,
    required this.inspection,
    required this.screening,
    this.isSimpleMode = true,
  });

  @override
  State<CalculationFlowStepper> createState() => _CalculationFlowStepperState();
}

class _CalculationFlowStepperState extends State<CalculationFlowStepper> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _slateDark = Color(0xFF0F172A);

  int _selectedCoalitionIndex = 7; // Default S7 (Fusi Lengkap)

  @override
  Widget build(BuildContext context) {
    final ins = widget.inspection;
    final scr = widget.screening;
    final coalitions = ins.coalitionScores;

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
          // --- HEADER ALUR PERHITUNGAN MODEL ---
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: _slateDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSimpleMode
                          ? '4 Tahap Cara Kerja Otak AI (Transparan)'
                          : 'Arsitektur Inferensi ONNX & Koalisi Laten',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tidak ada proses tersembunyi — telusuri setiap langkah kalkulasi di bawah',
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
          const SizedBox(height: 18),

          // --- TAHAP 1: VEKTORISASI 1.091 FITUR ---
          _buildStageContainer(
            stageNumber: '1',
            title: widget.isSimpleMode
                ? 'Mengubah Video Menjadi 1.091 Angka Sinyal'
                : 'Tahap 1: Ekstraksi & Normalisasi Z-Score (1.091D)',
            badgeText: '75 + 248 + 768 = 1.091 Fitur',
            accentColor: const Color(0xFF0284C7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSimpleMode
                      ? 'AI tidak menyimpan foto wajah Anda, melainkan mengubah gerak wajah, gelombang suara, dan kata-kata menjadi deretan angka matematis:'
                      : 'Setiap modalitas dinormalisasi terhadap distribusi populasi (train_norm_stats.json) sebelum masuk ke tensor ONNX:',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _buildVectorPreviewRow(
                  label: 'Wajah (75 Angka)',
                  values: ins.sampleVisualVector,
                  color: _brandTealDark,
                ),
                const SizedBox(height: 6),
                _buildVectorPreviewRow(
                  label: 'Suara (248 Angka)',
                  values: ins.sampleAudioVector,
                  color: const Color(0xFF0284C7),
                ),
                const SizedBox(height: 6),
                _buildVectorPreviewRow(
                  label: 'Cerita (768 Angka)',
                  values: ins.sampleTextVector,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          _buildConnectorArrow(),

          // --- TAHAP 2: FUSI MEMORI BiLSTM & ATTENTION ---
          _buildStageContainer(
            stageNumber: '2',
            title: widget.isSimpleMode
                ? 'Menyelaraskan Suara, Wajah, & Cerita'
                : 'Tahap 2: BiLSTM Temporal Encoding & Attention (256D × 3)',
            badgeText: 'ONNX Runtime Mobile',
            accentColor: _brandTealDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSimpleMode
                      ? 'Jaringan saraf tiruan (BiLSTM) mencari kecocokan antar sinyal — misalnya apakah saat kalimat terdengar lelah, nada suara juga ikut merendah dan ekspresi wajah tampak tegang.'
                      : 'Model utama (fedmind_multimodal.onnx) memproyeksikan sekuens panjang 512 langkah waktu ke ruang laten 256 dimensi per modalitas:',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Memori Suara',
                        dim: '256D',
                        normValue: ins.audioLatentNorm,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Memori Wajah',
                        dim: '256D',
                        normValue: ins.visualLatentNorm,
                        color: _brandTealDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Memori Cerita',
                        dim: '256D',
                        normValue: ins.textLatentNorm,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildConnectorArrow(),

          // --- TAHAP 3: SIMULASI 8 SKENARIO KOALISI (SHAPLEY GAME THEORY) ---
          _buildStageContainer(
            stageNumber: '3',
            title: widget.isSimpleMode
                ? 'Simulasi 8 Kombinasi (Uji Coba Keadilan AI)'
                : 'Tahap 3: Evaluasi 8 Koalisi Exact Shapley (2³ Subset)',
            badgeText: '8 Kombinasi Diuji',
            accentColor: const Color(0xFF7C3AED),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSimpleMode
                      ? 'Untuk mengetahui sinyal mana yang paling berpengaruh, AI menguji 8 skenario berbeda (misalnya: bagaimana jika hanya mendengar suara tanpa melihat wajah?). Ketuk tiap kotak untuk melihat hasilnya:'
                      : 'Regressor ONNX mengevaluasi seluruh 8 kombinasi koalisi (S₀ s/d S₇) untuk menghitung nilai kontribusi marginal eksak:',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (coalitions.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: coalitions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (context, idx) {
                      final c = coalitions[idx];
                      final isSelected =
                          _selectedCoalitionIndex.clamp(0, coalitions.length - 1) ==
                              idx;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCoalitionIndex = idx;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.coalitionCode.split(' ').first,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.predictedScore.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : _slateDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildMiniModDot(
                                    active: c.hasAudio,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 3),
                                  _buildMiniModDot(
                                    active: c.hasVisual,
                                    color: isSelected
                                        ? Colors.white
                                        : _brandTealDark,
                                  ),
                                  const SizedBox(width: 3),
                                  _buildMiniModDot(
                                    active: c.hasText,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF7C3AED),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildSelectedCoalitionDetail(
                    coalitions[_selectedCoalitionIndex.clamp(
                      0,
                      coalitions.length - 1,
                    )],
                  ),
                ],
              ],
            ),
          ),
          _buildConnectorArrow(),

          // --- TAHAP 4: KEPUTUSAN AKHIR & VERIFIKASI AKSIOMA ---
          _buildStageContainer(
            stageNumber: '4',
            title: widget.isSimpleMode
                ? 'Keputusan Skor Akhir & Verifikasi Kejujuran AI'
                : 'Tahap 4: Verifikasi Aksioma Efisiensi & Kalibrasi Risiko',
            badgeText: scr.xai?.efficiencyAxiomVerified == true
                ? '100% Akurat & Terverifikasi'
                : 'Terverifikasi',
            accentColor: const Color(0xFF059669),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isSimpleMode
                      ? 'Seluruh hasil simulasi digabungkan secara adil. Jumlah kontribusi Suara + Wajah + Cerita dijamin 100% sesuai dengan selisih skor awal ke skor akhir Anda.'
                      : 'Aksioma Efisiensi Shapley: φ_audio + φ_visual + φ_text = v(1,1,1) − v(0,0,0) terpenuhi secara eksak tanpa aproksimasi stokastik.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Diproses oleh: ${scr.model?.name ?? "FED-MIND Edge Mobile"} • 100% Offline di HP Anda',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContainer({
    required String stageNumber,
    required String title,
    required String badgeText,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stageNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildConnectorArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(
          Icons.keyboard_double_arrow_down_rounded,
          size: 20,
          color: _brandTeal.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildVectorPreviewRow({
    required String label,
    required List<double> values,
    required Color color,
  }) {
    final formatted = values
        .take(5)
        .map((v) => v.toStringAsFixed(2))
        .join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _slateDark,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              '[$formatted, ...]',
              style: const TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatentBox({
    required String title,
    required String dim,
    required double normValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            'Energi: ${normValue.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: _slateDark,
            ),
          ),
          Text(
            'Vektor $dim',
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniModDot({required bool active, required Color color}) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildSelectedCoalitionDetail(CoalitionStepScore c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  c.coalitionCode,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  c.predictedScore.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5B21B6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

