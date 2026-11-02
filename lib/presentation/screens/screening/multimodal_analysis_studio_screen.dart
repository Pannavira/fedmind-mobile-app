import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/clinical_constants.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../../data/models/screening_models.dart';
import '../../widgets/multimodal_inspection/audio_waveform_card.dart';
import '../../widgets/multimodal_inspection/face_modality_card.dart';
import '../../widgets/multimodal_inspection/speech_transcript_card.dart';
import '../../widgets/xai_pipeline/calculation_flow_stepper.dart';
import '../../widgets/xai_pipeline/interactive_shapley_balance.dart';
import '../result/screening_result_screen.dart';

class MultimodalAnalysisStudioScreen extends StatefulWidget {
  final ScreeningResponse result;
  final MultimodalInspectionData inspection;
  final String? localVideoPath;
  final bool isFromResultScreen;

  const MultimodalAnalysisStudioScreen({
    super.key,
    required this.result,
    required this.inspection,
    this.localVideoPath,
    this.isFromResultScreen = false,
  });

  @override
  State<MultimodalAnalysisStudioScreen> createState() =>
      _MultimodalAnalysisStudioScreenState();
}

class _MultimodalAnalysisStudioScreenState
    extends State<MultimodalAnalysisStudioScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _slateDark = Color(0xFF0F172A);

  late TabController _tabController;
  bool _isSimpleMode = true;
  double _videoPlaybackProgress = 0.25;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.result.prediction?.phq8Score ?? 0.0;
    final riskCat = widget.result.prediction?.riskCategory ?? 'low';
    final riskColor = ClinicalConstants.getRiskColor(riskCat);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        bottomNavigationBar: _buildBottomActionBar(context, riskColor, score),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF18B2AC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Baris Navigasi Atas & Switch Bahasa Mudah
                          Row(
                            children: [
                              Material(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Studio Analisis & Kalkulasi AI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      'Peserta: ${widget.result.participantId} • Transparansi Penuh On-Device',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.88),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle Mode Mudah vs Teknis
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSimpleMode = !_isSimpleMode;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isSimpleMode
                                            ? Icons.lightbulb_rounded
                                            : Icons.science_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _isSimpleMode
                                            ? 'Bahasa Mudah'
                                            : 'Mode Teknis',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Tab Selector (Inspeksi Modalitas vs Proses Kalkulasi Model)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: _brandTealDark,
                              unselectedLabelColor: Colors.white,
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              tabs: const [
                                Tab(
                                  height: 40,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sensors_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '1. Deteksi Wajah, Suara & Teks',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Tab(
                                  height: 40,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calculate_outlined, size: 16),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '2. Proses Kalkulasi AI',
                                          overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // --- TAB 1: INSPEKSI 3 MODALITAS RIIL ---
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickOverviewBanner(),
                    const SizedBox(height: 16),
                    FaceModalityCard(
                      inspection: widget.inspection,
                      isSimpleMode: _isSimpleMode,
                      onVideoProgressChanged: (prog) {
                        setState(() {
                          _videoPlaybackProgress = prog;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    AudioWaveformCard(
                      inspection: widget.inspection,
                      isSimpleMode: _isSimpleMode,
                      playbackProgress: _videoPlaybackProgress,
                    ),
                    const SizedBox(height: 16),
                    SpeechTranscriptCard(
                      inspection: widget.inspection,
                      isSimpleMode: _isSimpleMode,
                    ),
                    const SizedBox(height: 16),
                    _buildNextTabCalloutCard(),
                  ],
                ),
              ),

              // --- TAB 2: PROSES KALKULASI MODEL AI & SHAPLEY ---
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InteractiveShapleyBalance(
                      screening: widget.result,
                      isSimpleMode: _isSimpleMode,
                    ),
                    const SizedBox(height: 16),
                    CalculationFlowStepper(
                      inspection: widget.inspection,
                      screening: widget.result,
                      isSimpleMode: _isSimpleMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOverviewBanner() {
    final ins = widget.inspection;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
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
                  ins.isFromRealVideo
                      ? 'Sinyal Video Anda Berhasil Diekstrak Secara Riil'
                      : 'Pratinjau Sinyal Multimodal Siap Diinspeksi',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _slateDark,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Periksa deteksi wajah, gelombang suara, dan transkrip cerita Anda di bawah ini sebelum melihat cara AI menghitung skor.',
                  style: TextStyle(
                    fontSize: 11.5,
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

  Widget _buildNextTabCalloutCard() {
    return Material(
      color: const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _tabController.animateTo(1);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _brandTeal.withValues(alpha: 0.45)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: _brandTealDark,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Penasaran Bagaimana Ketiga Sinyal Ini Dihitung?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ketuk di sini untuk membuka Tab 2 dan melihat timbangan kalkulasi model AI secara langsung.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _brandTealDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    Color riskColor,
    double score,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Ringkasan Skor Mini di Kiri
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: riskColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Skor PHQ-8',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${score.toStringAsFixed(2)} / 24',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: riskColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.isFromResultScreen) {
                      Navigator.of(context).pop();
                    } else if (_tabController.index == 0) {
                      _tabController.animateTo(1);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScreeningResultScreen(
                            result: widget.result,
                            localVideoPath: widget.localVideoPath,
                            inspectionData: widget.inspection,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    widget.isFromResultScreen
                        ? Icons.check_circle_outline_rounded
                        : (_tabController.index == 0
                            ? Icons.calculate_rounded
                            : Icons.assignment_turned_in_rounded),
                    size: 19,
                  ),
                  label: Text(
                    widget.isFromResultScreen
                        ? 'Kembali ke Ringkasan Hasil'
                        : (_tabController.index == 0
                            ? 'Lihat Kalkulasi AI (Tab 2)'
                            : 'Buka Laporan Lengkap'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
