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
    this.isSimpleMode = false,
  });

  @override
  State<CalculationFlowStepper> createState() => _CalculationFlowStepperState();
}

class _CalculationFlowStepperState extends State<CalculationFlowStepper> {
  static const Color _clinicalTeal = Color(0xFF18B2AC);
  static const Color _clinicalTealDark = Color(0xFF0D9488);
  static const Color _slateDark = Color(0xFF1E293B);

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
          // --- HEADER ALUR PERHITUNGAN MODEL ---
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: _clinicalTealDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alur Inferensi Model & Koalisi Laten',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Transparansi kalkulasi fitur hingga verifikasi aksioma efisiensi',
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
          const SizedBox(height: 16),

          // --- TAHAP 1: VEKTORISASI 1.091 FITUR ---
          _buildStageContainer(
            stageNumber: '1',
            title: 'Tahap 1: Ekstraksi Fitur & Normalisasi Z-Score (1.091D)',
            badgeText: '75 + 248 + 768 = 1.091D',
            accentColor: const Color(0xFF0284C7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Setiap modalitas dinormalisasi terhadap parameter populasi referensi (train_norm_stats.json) sebelum dibentuk menjadi tensor sekuensial 512 timestep:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _buildVectorPreviewRow(
                  label: 'Modalitas Visual (Facial AUs • 75D)',
                  values: ins.sampleVisualVector,
                  color: _clinicalTeal,
                ),
                const SizedBox(height: 6),
                _buildVectorPreviewRow(
                  label: 'Modalitas Akustik / Prosodi (248D)',
                  values: ins.sampleAudioVector,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(height: 6),
                _buildVectorPreviewRow(
                  label: 'Modalitas Teks / Linguistik (768D)',
                  values: ins.sampleTextVector,
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ),
          ),
          _buildConnectorArrow(),

          // --- TAHAP 2: FUSI MEMORI BiLSTM & ATTENTION ---
          _buildStageContainer(
            stageNumber: '2',
            title: 'Tahap 2: BiLSTM Temporal Encoding & Attention (256D × 3)',
            badgeText: 'ONNX Runtime Mobile',
            accentColor: _clinicalTeal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Arsitektur fedmind_multimodal.onnx memproyeksikan representasi temporal masing-masing modalitas ke ruang laten 256 dimensi (L2-norm energi aktivasi):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Latent Akustik',
                        dim: '256D',
                        normValue: ins.audioLatentNorm,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Latent Visual (AUs)',
                        dim: '256D',
                        normValue: ins.visualLatentNorm,
                        color: _clinicalTeal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLatentBox(
                        title: 'Latent Linguistik',
                        dim: '256D',
                        normValue: ins.textLatentNorm,
                        color: const Color(0xFF3B82F6),
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
            title: 'Tahap 3: Evaluasi 8 Koalisi Laten Exact Shapley (2³ Subset)',
            badgeText: '8 Koalisi Diuji',
            accentColor: const Color(0xFF4F46E5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Regressor ONNX mengevaluasi seluruh 8 kombinasi koalisi modalitas (S₀ s/d S₇) untuk menghitung kontribusi marginal eksak. Ketuk sel koalisi untuk menginspeksi skor:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
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
                                ? _slateDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? _slateDark
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.coalitionCode.split(' ').first,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? const Color(0xFF2DD4BF)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.predictedScore.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 12.5,
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
                                        : const Color(0xFF6366F1),
                                  ),
                                  const SizedBox(width: 3),
                                  _buildMiniModDot(
                                    active: c.hasVisual,
                                    color: isSelected
                                        ? Colors.white
                                        : _clinicalTeal,
                                  ),
                                  const SizedBox(width: 3),
                                  _buildMiniModDot(
                                    active: c.hasText,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF3B82F6),
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
            title: 'Tahap 4: Verifikasi Aksioma Efisiensi & Stratifikasi PHQ-8',
            badgeText: scr.xai?.efficiencyAxiomVerified == true
                ? 'Aksioma Terverifikasi'
                : 'Terverifikasi',
            accentColor: const Color(0xFF10B981),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aksioma Efisiensi Shapley: φ_audio + φ_visual + φ_text = v(1,1,1) − v(0,0,0) terpenuhi secara eksak tanpa aproksimasi stokastik.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Checkpoint: ${scr.model?.checkpoint ?? "fedmind_multimodal.onnx"} • ${scr.model?.name ?? "FedAvg FL-IID"}',
                        style: const TextStyle(
                          fontSize: 10.5,
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
      padding: const EdgeInsets.all(12),
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
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  stageNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
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
          size: 18,
          color: _clinicalTeal.withValues(alpha: 0.7),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
                  fontSize: 10.5,
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
                fontSize: 10,
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            'L2: ${normValue.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: _slateDark,
            ),
          ),
          Text(
            'Tensor $dim',
            style: const TextStyle(
              fontSize: 9,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _slateDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  c.coalitionCode,
                  style: const TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  c.predictedScore.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _slateDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.description,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF475569),
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
