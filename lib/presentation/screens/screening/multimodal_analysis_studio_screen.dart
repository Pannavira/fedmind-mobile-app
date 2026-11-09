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
  final bool isSimulation;

  const MultimodalAnalysisStudioScreen({
    super.key,
    required this.result,
    required this.inspection,
    this.localVideoPath,
    this.isFromResultScreen = false,
    this.isSimulation = false,
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
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _textSecondary = Color(0xFF64748B);

  late TabController _tabController;
  final bool _isSimpleMode = false;
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
        backgroundColor: _softBg,
        bottomNavigationBar: _buildBottomActionBar(context, riskColor, score),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
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
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top bar: Tombol kembali, judul & identitas pasien
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
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Studio Observasi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'ID Pasien: ${widget.result.participantId} • Triangulasi Sinyal & XAI',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.90),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Tab Selector (Kapsul Modern & Bersih)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: _brandTealDark,
                              unselectedLabelColor: Colors.white,
                              labelStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              tabs: const [
                                Tab(
                                  height: 38,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.sensors_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text('Sinyal Multimodal'),
                                    ],
                                  ),
                                ),
                                Tab(
                                  height: 38,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.balance_rounded, size: 16),
                                      SizedBox(width: 6),
                                      Text('Atribusi XAI'),
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
              // --- TAB 1: INSPEKSI 3 MODALITAS KLINIS ---
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  ],
                ),
              ),

              // --- TAB 2: PROSES KALKULASI MODEL AI & SHAPLEY ---
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
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

  Widget _buildBottomActionBar(
    BuildContext context,
    Color riskColor,
    double score,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Ringkasan Skor Mini di Kiri
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimasi PHQ-8',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _textSecondary,
                    ),
                  ),
                  Text(
                    '${score.toStringAsFixed(1)} / 24',
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
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.isFromResultScreen) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScreeningResultScreen(
                            result: widget.result,
                            localVideoPath: widget.localVideoPath,
                            inspectionData: widget.inspection,
                            isSimulation:
                                widget.isSimulation || widget.result.isSimulation,
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 18,
                  ),
                  label: Text(
                    widget.isFromResultScreen
                        ? 'Kembali ke Hasil Asesmen'
                        : 'Buka Hasil & Verifikasi',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
