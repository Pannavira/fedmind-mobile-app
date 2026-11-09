import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/datasources/sample_patient_data.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../providers/screening_provider.dart';
import '../result/screening_result_screen.dart';
import '../screening/multimodal_analysis_studio_screen.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _slateDark = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  String _selectedCase = 'P600'; // 'P600', 'SYNTH', 'ARTIFACT'
  String _participantId = 'P600';
  Map<String, dynamic>? _selectedPayload;
  MultimodalInspectionData? _inspectionPreview;

  final _noteController = TextEditingController(
    text: 'Sesi simulasi benchmark evaluasi model ONNX dan konkordansi XAI.',
  );
  final _transcriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadP600Case();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _loadP600Case() async {
    final data = await SamplePatientData.loadP600Features();
    if (!mounted) return;

    final vis = (data['visual_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final aud = (data['audio_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final txt = (data['text_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    setState(() {
      _selectedCase = 'P600';
      _participantId = 'P600';
      _selectedPayload = data;
      _transcriptController.text =
          'I feel exhausted lately and have trouble focusing on daily routines.';
      _inspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: _participantId,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _noteController.text.trim(),
        clientTranscript: _transcriptController.text.trim(),
      );
    });
  }

  void _loadSyntheticCase({required bool simulateNoise}) {
    final pid = simulateNoise ? 'P-NOISE-09' : 'P-SYNTH-04';
    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: simulateNoise,
    );

    final vis = (data['visual_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final aud = (data['audio_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final txt = (data['text_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    setState(() {
      _selectedCase = simulateNoise ? 'ARTIFACT' : 'SYNTH';
      _participantId = pid;
      _selectedPayload = data;
      _transcriptController.text = simulateNoise
          ? '[Audio terdegradasi / SNR rendah] Kondisi lingkungan bising saat sesi konseling.'
          : 'Saya merasa baik-baik saja hari ini, aktivitas berjalan normal.';
      _inspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: _participantId,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _noteController.text.trim(),
        clientTranscript: _transcriptController.text.trim(),
      );
    });
  }

  Future<void> _runSimulation({bool openStudioFirst = false}) async {
    final provider = context.read<ScreeningProvider>();
    if (_selectedPayload == null) return;

    final audioFeat = (_selectedPayload!['audio_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final visualFeat = (_selectedPayload!['visual_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final textFeat = (_selectedPayload!['text_features'] as List)
        .map((e) => (e as num).toDouble())
        .toList();

    final inspection = _inspectionPreview ??
        MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: _participantId,
          visualFeatures: visualFeat,
          audioFeatures: audioFeat,
          textFeatures: textFeat,
          userNote: _noteController.text.trim(),
          clientTranscript: _transcriptController.text.trim(),
        );

    final success = await provider.executeLocalOnDeviceScreening(
      participantId: _participantId,
      textFeatures: textFeat,
      audioFeatures: audioFeat,
      visualFeatures: visualFeat,
      counselorNote: _noteController.text.trim(),
      transcription: _transcriptController.text.trim(),
      inspectionData: inspection,
      sessionType: 'simulation',
      isSimulation: true,
    );

    if (!mounted) return;

    if (success && provider.currentScreening != null) {
      if (openStudioFirst && provider.currentInspectionData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MultimodalAnalysisStudioScreen(
              result: provider.currentScreening!,
              inspection: provider.currentInspectionData!,
              isSimulation: true,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScreeningResultScreen(
              result: provider.currentScreening!,
              inspectionData: provider.currentInspectionData,
              isSimulation: true,
            ),
          ),
        );
      }
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            // Header Teal Gradient
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brandTeal, _brandTealDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.science_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Simulasi & Benchmark',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Uji dataset standar E-DAIC & validasi XAI',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Golden Case',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Pilih Skenario Kasus Uji
                  _buildSectionCard(
                    title: 'Pilih Skenario Kasus Uji',
                    subtitle:
                        'Gunakan kasus benchmark standar untuk menguji respon model',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _buildScenarioTile(
                          id: 'P600',
                          title: 'Golden Case P600 (E-DAIC Reference)',
                          subtitle:
                              'Skor 9.69 (Borderline), Dominan Visual FACS. Kasus standar emas penelitian.',
                          isSelected: _selectedCase == 'P600',
                          badge: 'Ground Truth',
                          onTap: provider.isExecuting ? null : _loadP600Case,
                        ),
                        const SizedBox(height: 10),
                        _buildScenarioTile(
                          id: 'SYNTH',
                          title: 'Pasien Sintetis Terkalibrasi',
                          subtitle:
                              'Fitur afektif normal/mild untuk menguji sensitivitas model pada kasus tanpa depresi.',
                          isSelected: _selectedCase == 'SYNTH',
                          badge: 'Normal / Mild',
                          onTap: provider.isExecuting
                              ? null
                              : () => _loadSyntheticCase(simulateNoise: false),
                        ),
                        const SizedBox(height: 10),
                        _buildScenarioTile(
                          id: 'ARTIFACT',
                          title: 'Uji Artefak & Degradasi Akustik',
                          subtitle:
                              'Simulasi SNR mikrofon rendah untuk menguji ketahanan model terhadap derau.',
                          isSelected: _selectedCase == 'ARTIFACT',
                          badge: 'Stress Test',
                          onTap: provider.isExecuting
                              ? null
                              : () => _loadSyntheticCase(simulateNoise: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Vektor Modalitas yang Terload
                  _buildSectionCard(
                    title: 'Status Vektor Biometrik Terkalibrasi',
                    subtitle: 'Spesifikasi fitur multimodal yang siap diuji',
                    icon: Icons.layers_outlined,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildFeatureMetric(
                              label: 'Visual (FACS)',
                              dim: '75 Dimensi',
                              status: 'AUs Siap',
                              icon: Icons.face_rounded,
                              color: const Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 8),
                            _buildFeatureMetric(
                              label: 'Audio (Prosodi)',
                              dim: '248 Dimensi',
                              status: _selectedCase == 'ARTIFACT'
                                  ? 'Low SNR'
                                  : 'COVAREP Siap',
                              icon: Icons.graphic_eq_rounded,
                              color: _selectedCase == 'ARTIFACT'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            _buildFeatureMetric(
                              label: 'Teks (MentalBERT)',
                              dim: '768 Dimensi',
                              status: 'Semantik Siap',
                              icon: Icons.text_fields_rounded,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCFBF1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kasus Aktif: $_participantId',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _brandTealDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Transkrip Verbatim: "${_transcriptController.text}"',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF134E4A),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Tombol Eksekusi Simulasi
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C0F172A),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Eksekusi Inferensi Simulasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _slateDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Jalankan model ONNX on-device untuk menghitung estimasi skor PHQ-8 dan dekomposisi Shapley.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : () => _runSimulation(openStudioFirst: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandTeal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(
                              provider.isExecuting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: Text(
                              provider.isExecuting
                                  ? 'Menjalankan Inferensi...'
                                  : 'Jalankan Simulasi On-Device',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : () => _runSimulation(openStudioFirst: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _slateDark,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.biotech_rounded, size: 18),
                            label: const Text(
                              'Buka Studio Observasi XAI',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Catatan Sandbox: Tidak disimpan ke database pasien
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: _textSecondary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sesi simulasi tidak disimpan ke riwayat database & tidak memerlukan verifikasi klinisi.',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _softMintBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _brandTealDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildScenarioTile({
    required String id,
    required String title,
    required String subtitle,
    required bool isSelected,
    required String badge,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _brandTeal : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _brandTeal : const Color(0xFF94A3B8),
                  width: 2,
                ),
                color: isSelected ? _brandTeal : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? _brandTealDark : _slateDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _brandTeal.withValues(alpha: 0.15)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? _brandTealDark : _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                      height: 1.35,
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

  Widget _buildFeatureMetric({
    required String label,
    required String dim,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _slateDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dim,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              status,
              style: const TextStyle(
                fontSize: 9,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

