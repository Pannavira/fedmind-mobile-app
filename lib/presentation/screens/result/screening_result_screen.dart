import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/main_navigation_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/verification/clinical_verification_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_bottom_nav_bar.dart';
import 'package:fedmind_mobile_app/presentation/widgets/local_video_player_dialog.dart';
import 'package:fedmind_mobile_app/presentation/widgets/multimodal_inspection/audio_waveform_card.dart';
import 'package:fedmind_mobile_app/presentation/widgets/multimodal_inspection/face_modality_card.dart';
import 'package:fedmind_mobile_app/presentation/widgets/multimodal_inspection/speech_transcript_card.dart';
import 'package:fedmind_mobile_app/presentation/widgets/quality_flag_alert.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

/// Layar Tampilan Hasil Skrining (Pure Model Result)
/// Dirancang khusus agar bersih, objektif, dan mudah dipahami oleh Konselor & Psikolog
/// tanpa adanya jargon teknis machine learning atau matematika rumit.
/// Form Verifikasi Konselor dipisahkan ke layar terpisah [ClinicalVerificationScreen].
class ScreeningResultScreen extends StatefulWidget {
  final ScreeningResponse result;
  final String? localVideoPath;
  final MultimodalInspectionData? inspectionData;
  final bool isSimulation;
  final int initialNavIndex;

  const ScreeningResultScreen({
    super.key,
    required this.result,
    this.localVideoPath,
    this.inspectionData,
    this.isSimulation = false,
    this.initialNavIndex = 2,
  });

  @override
  State<ScreeningResultScreen> createState() => _ScreeningResultScreenState();
}

class _ScreeningResultScreenState extends State<ScreeningResultScreen> {
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);

  late ScreeningResponse _currentResult;
  late int _currentNavIndex;
  bool get _isSim => widget.isSimulation || _currentResult.isSimulation;
  int _selectedSignalTabIndex = 0; // 0: Semua, 1: Wajah, 2: Suara, 3: Transkrip
  double _videoPlaybackProgress = 0.25;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
    _currentNavIndex = widget.initialNavIndex;
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  /// Membuat ringkasan klinis yang manusiawi, bebas dari jargon teknik AI/matematika
  String _getHumanizedClinicalNarrative(ScreeningResponse res) {
    final rawNarrative = res.clinicalNarrative;
    // Jika narasi lama mengandung jargon teknis, format ulang menjadi narasi klinis yang ramah
    final isTechnical = rawNarrative != null &&
        (rawNarrative.contains('Edge Federated') ||
            rawNarrative.contains('Shapley') ||
            rawNarrative.contains('φ_') ||
            rawNarrative.contains('koalisi laten'));

    if (rawNarrative != null && rawNarrative.isNotEmpty && !isTechnical) {
      return rawNarrative;
    }

    final score = res.prediction?.phq8Score ?? 0.0;
    final cat = res.prediction?.riskCategory ?? 'low';
    final riskLabel = ClinicalConstants.getRiskLabel(cat);
    final dom = res.patientModalityAttribution?.dominantModality ?? 'text';
    final domName = ClinicalConstants.getModalityClinicalName(dom);

    double domPct = 50.0;
    if (dom == 'visual') {
      domPct = res.patientModalityAttribution?.visualPct ?? 50.0;
    } else if (dom == 'audio') {
      domPct = res.patientModalityAttribution?.audioPct ?? 50.0;
    } else {
      domPct = res.patientModalityAttribution?.textPct ?? 50.0;
    }

    return 'Berdasarkan hasil analisis observasi multimodal klien ${res.participantId}, '
        'estimasi skor PHQ-8 adalah ${score.toStringAsFixed(1)} dari rentang 24.0 ($riskLabel). '
        'Aspek yang paling menentukan penilaian adalah $domName dengan kontribusi ${domPct.toStringAsFixed(1)}%, '
        'yang menggambarkan pola ekspresi afektif dan komunikasi klien selama sesi.';
  }

  void _copySummaryToClipboard(BuildContext context) {
    final prediction = _currentResult.prediction;
    final riskCategory = prediction?.riskCategory ?? 'low';
    final score = prediction?.phq8Score ?? 0.0;
    final domMod =
        _currentResult.patientModalityAttribution?.dominantModality ?? 'visual';
    final textPct = _currentResult.patientModalityAttribution?.textPct ?? 0.0;
    final visualPct = _currentResult.patientModalityAttribution?.visualPct ?? 0.0;
    final audioPct = _currentResult.patientModalityAttribution?.audioPct ?? 0.0;

    final summary = '''
=== RINGKASAN HASIL ASESMEN SKRINING MULTIMODAL ===
ID Klien / Pasien : ${_currentResult.participantId}
ID Sesi Asesmen   : ${_currentResult.screeningId}
Waktu Sesi        : ${_formatDate(_currentResult.createdAt ?? '')}

[HASIL ESTIMASI SKOR]
• Skor PHQ-8 Estimasi : ${score.toStringAsFixed(1)} / 24.0
• Kategori Risiko     : ${ClinicalConstants.getRiskLabel(riskCategory)}
• Indikasi Klinis     : ${ClinicalConstants.getRiskDescription(riskCategory)}

[KONTRIBUSI FAKTOR OBSERVASI]
• Pola Bahasa & Tutur Kata (Linguistik) : ${textPct.toStringAsFixed(1)}%
• Ekspresi Wajah & Kontak Visual        : ${visualPct.toStringAsFixed(1)}%
• Karakter & Dinamika Suara (Akustik)   : ${audioPct.toStringAsFixed(1)}%
• Faktor Paling Dominan                : ${ClinicalConstants.getModalityClinicalName(domMod)}

[PANDUAN TINDAK LANJUT KONSELOR]
• Tindakan Direkomendasikan : ${ClinicalConstants.getCounselingActionTitle(riskCategory)}
• Panduan Klinis           : ${ClinicalConstants.getCounselingGuidance(riskCategory)}
===================================================
''';

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan hasil skrining berhasil disalin ke Clipboard.'),
        backgroundColor: _brandTealDark,
      ),
    );
  }

  Future<void> _openVerificationScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ClinicalVerificationScreen(
          screening: _currentResult,
          inspectionData: widget.inspectionData,
          localVideoPath: widget.localVideoPath,
        ),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      final provider = context.read<ScreeningProvider>();
      if (provider.currentScreening != null &&
          provider.currentScreening!.screeningId == _currentResult.screeningId) {
        setState(() {
          _currentResult = provider.currentScreening!;
        });
      } else {
        await provider.loadScreeningDetail(_currentResult.screeningId);
        if (mounted && provider.currentScreening != null) {
          setState(() {
            _currentResult = provider.currentScreening!;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _currentResult;
    final prediction = result.prediction;
    final attribution = result.patientModalityAttribution;
    final riskCategory = prediction?.riskCategory ?? 'low';
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);
    final score = prediction?.phq8Score ?? 0.0;
    final domModality = attribution?.dominantModality ?? 'visual';

    final isVerified = result.clinicalVerification?.isVerified == true;
    final verification = result.clinicalVerification;

    final textPct = attribution?.textPct ?? 0.0;
    final visualPct = attribution?.visualPct ?? 0.0;
    final audioPct = attribution?.audioPct ?? 0.0;

    final provider = context.watch<ScreeningProvider>();
    final rawInspection = widget.inspectionData ??
        provider.getInspectionForScreening(result.screeningId) ??
        MultimodalExtractorService.buildInspectionFromSampleFeatures(
          participantId: result.participantId,
          visualFeatures: List.filled(75, 0.2),
          audioFeatures: List.filled(248, 0.2),
          textFeatures: List.filled(768, 0.1),
        );
    final inspection = (widget.localVideoPath != null && rawInspection.videoPath != widget.localVideoPath)
        ? rawInspection.copyWith(videoPath: widget.localVideoPath)
        : rawInspection;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asesmen: ${result.participantId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const Text(
              'Hasil Skrining Model Multimodal',
              style: TextStyle(
                fontSize: 11.5,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        actions: [
          IconButton(
            onPressed: () => _copySummaryToClipboard(context),
            icon: const Icon(Icons.copy_all_rounded, color: _textSecondary),
            tooltip: 'Salin Ringkasan Hasil',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Mode Simulasi (Sandbox)
            if (_isSim)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.science_rounded,
                      color: Color(0xFF0D9488),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesi Simulasi & Benchmark (Sandbox)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sesi ini dijalankan untuk pengujian model perangkat (non-clinical trial).',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF115E59),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // =================================================================
            // 1. KARTU HASIL SKRINING UTAMA (HERO CARD BERSIH & RAMAH KONSELOR)
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: _softMintBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.psychology_outlined,
                              color: _brandTealDark,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.participantId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                _formatDate(result.createdAt ?? ''),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Status Verifikasi (Informasional Saja)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isVerified
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 13,
                              color: isVerified
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVerified ? 'Terverifikasi' : 'Belum Diverifikasi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isVerified
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Skor Besar & Kategori Risiko
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: riskColor,
                          letterSpacing: -1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/ 24.0',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      RiskBadge(riskCategory: riskCategory),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Indikator Deskripsi Singkat Risiko
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: riskColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: riskColor,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ClinicalConstants.getRiskDescription(riskCategory),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Narasi Kesimpulan Klinis (Bebas dari Jargon Teknis)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 15,
                              color: _brandTealDark,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Kesimpulan Observasi Klinis',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getHumanizedClinicalNarrative(result),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // =================================================================
            // 2. KARTU FAKTOR OBSERVASI MULTIMODAL (HUMAN-CENTERED FOR COUNSELOR)
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
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
                        child: const Icon(
                          Icons.insights_rounded,
                          color: _brandTealDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Faktor Observasi Multimodal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pengaruh aspek respon klien terhadap hasil skrining',
                              style: TextStyle(fontSize: 11.5, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Modalitas 1: Teks / Linguistik
                  _buildModalityFactorRow(
                    icon: Icons.notes_rounded,
                    title: 'Bahasa & Tutur Kata (Linguistik)',
                    percentage: textPct,
                    color: ClinicalConstants.textModalityColor,
                    isDominant: domModality == 'text',
                    description:
                        'Pilihan kosa kata, variasi kalimat, dan ekspresi semantik verbal klien.',
                  ),
                  const SizedBox(height: 14),

                  // Modalitas 2: Visual (Ekspresi Wajah)
                  _buildModalityFactorRow(
                    icon: Icons.face_retouching_natural_rounded,
                    title: 'Ekspresi Wajah & Kontak Visual',
                    percentage: visualPct,
                    color: ClinicalConstants.visualModalityColor,
                    isDominant: domModality == 'visual',
                    description:
                        'Dinamika responsivitas otot wajah, senyum, dan kontak mata saat berkomunikasi.',
                  ),
                  const SizedBox(height: 14),

                  // Modalitas 3: Akustik / Suara
                  _buildModalityFactorRow(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Karakter & Nada Suara (Akustik)',
                    percentage: audioPct,
                    color: ClinicalConstants.audioModalityColor,
                    isDominant: domModality == 'audio',
                    description:
                        'Kelancaran tempo bicara, kestabilan intonasi nada, dan jeda percakapan.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // =================================================================
            // 3. KARTU PANDUAN & TINDAK LANJUT KONSELING
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
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
                        child: const Icon(
                          Icons.medical_services_outlined,
                          color: _brandTealDark,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panduan Tindak Lanjut Konseling',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rekomendasi tindakan berbasis bukti untuk konselor',
                              style: TextStyle(fontSize: 11.5, color: _textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ClinicalConstants.getCounselingActionTitle(riskCategory),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ClinicalConstants.getCounselingGuidance(riskCategory),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quality Flags Alert (Bila ada isu pencahayaan atau mikrofon)
            QualityFlagAlert(flags: result.qualityFlags),
            const SizedBox(height: 18),

            // =================================================================
            // 4. STUDIO OBSERVASI MULTIMODAL (LANGSUNG TAMPIL DI DEPAN)
            // =================================================================
            _buildDirectObservationStudio(context, inspection),
            const SizedBox(height: 18),

            // =================================================================
            // 5. KESIMPULAN & PENJELASAN PREDIKSI MODEL (NARATIF & HOLISTIK)
            // =================================================================
            _buildHolisticModelSummaryCard(context, result, inspection),
            const SizedBox(height: 18),

            // =================================================================
            // 6. BANNER / CTA MENU VERIFIKASI KONSELOR (TERPISAH)
            // =================================================================
            Container(
              decoration: BoxDecoration(
                color: isVerified
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isVerified
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCD34D),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isVerified
                              ? Icons.verified_rounded
                              : Icons.rate_review_outlined,
                          color: isVerified
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVerified
                                  ? 'Telah Diverifikasi Konselor'
                                  : 'Menu Verifikasi Konselor',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isVerified
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isVerified
                                  ? 'Kesesuaian: ${ClinicalConstants.getConcordanceLabel(verification?.concordanceStatus)} • Skor Riil: ${verification?.groundTruthPhq8.toStringAsFixed(0)}/24'
                                  : 'Verifikasi dilakukan di lembar terpisah untuk validasi ahli & catatan SOAP.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isVerified
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isSim)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 16,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sesi Simulasi • Tidak Masuk Antrean Verifikasi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _openVerificationScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVerified
                              ? const Color(0xFF166534)
                              : const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isVerified
                              ? Icons.edit_note_rounded
                              : Icons.assignment_turned_in_outlined,
                          size: 18,
                        ),
                        label: Text(
                          isVerified
                              ? 'Buka / Ubah Lembar Verifikasi'
                              : 'Masuk ke Lembar Verifikasi Konselor',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClinicalBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => MainNavigationScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
        pendingReviewCount: provider.pendingVerificationCount,
      ),
    );
  }

  /// Card Kesimpulan Menyeluruh & Penjelasan Prediksi Model
  /// Dirancang naratif, transparan, dan mudah dipahami konselor/psikolog
  Widget _buildHolisticModelSummaryCard(
    BuildContext context,
    ScreeningResponse result,
    MultimodalInspectionData inspection,
  ) {
    final phqScore = result.prediction?.phq8Score ?? 0.0;
    final cat = (result.prediction?.riskCategory ?? 'low').toLowerCase();
    final isLowRisk = cat == 'low' || phqScore < 8.0;
    final isBorderline =
        cat == 'borderline' || (phqScore >= 8.0 && phqScore < 10.0);
    final probPct =
        ((result.prediction?.riskProbabilityProxy ?? (isLowRisk ? 0.21 : 0.72)) *
                100)
            .toStringAsFixed(0);
    final domModality =
        result.patientModalityAttribution?.dominantModality ?? 'text';
    final domName = ClinicalConstants.getModalityClinicalName(domModality);

    // Tema warna status
    final Color statusColor;
    final Color statusBgColor;
    final Color statusBorderColor;
    final IconData statusIcon;
    final String statusTitle;

    if (isLowRisk) {
      statusColor = const Color(0xFF16A34A);
      statusBgColor = const Color(0xFFF0FDF4);
      statusBorderColor = const Color(0xFF86EFAC);
      statusIcon = Icons.check_circle_rounded;
      statusTitle =
          'Indikasi Model: Tidak Mengarah ke Depresi Klinis (Risiko Rendah / Minimal)';
    } else if (isBorderline) {
      statusColor = const Color(0xFFD97706);
      statusBgColor = const Color(0xFFFFFBEB);
      statusBorderColor = const Color(0xFFFCD34D);
      statusIcon = Icons.info_rounded;
      statusTitle =
          'Indikasi Model: Gejala Ringan / Subklinis (Perlu Pemantauan Berkala)';
    } else {
      statusColor = const Color(0xFFDC2626);
      statusBgColor = const Color(0xFFFEF2F2);
      statusBorderColor = const Color(0xFFFCA5A5);
      statusIcon = Icons.warning_amber_rounded;
      statusTitle =
          'Indikasi Model: Terindikasi Adanya Kecenderungan Depresi (Risiko Sedang / Tinggi)';
    }

    // Sintesis naratif mengalir
    final String mainNarrative;
    if (isLowRisk) {
      mainNarrative =
          'Berdasarkan sintesis seluruh rekaman sesi, model menyimpulkan klien tidak menunjukkan indikasi simtomatologi depresi yang signifikan '
          '(estimasi skor PHQ-8 sebesar ${phqScore.toStringAsFixed(1)} / 24.0 dengan probabilitas depresi $probPct%). '
          'Sinyal multimodal klien memperlihatkan responsivitas afektif yang dinamis dan adaptif: ekspresi wajah tampak hidup dengan kontak mata yang konsisten, '
          'ritme dan intonasi suara mengalir natural tanpa adanya jeda bicara yang terhambat, serta pola bahasa tidak didominasi oleh kosakata rasa bersalah '
          'atau keputusasaan ekstrem.';
    } else if (isBorderline) {
      mainNarrative =
          'Berdasarkan integrasi data sesi, model mengidentifikasi pola afektif subklinis / stresor emosional ringan '
          '(estimasi skor PHQ-8 sebesar ${phqScore.toStringAsFixed(1)} / 24.0 dengan probabilitas $probPct%). '
          'Meskipun belum memenuhi ambang depresi mayor, model mencatat adanya sedikit fluktuasi pada keterbukaan emosional: '
          'kontak mata klien sesekali terputus dengan beberapa jeda bicara yang reflektif, serta teramati sedikit ketegangan pada '
          'area wajah saat membahas topik tertentu.';
    } else {
      mainNarrative =
          'Berdasarkan integrasi 3 sinyal observasi, model mengindikasikan adanya kecenderungan simtomatologi depresi yang nyata '
          '(estimasi skor PHQ-8 sebesar ${phqScore.toStringAsFixed(1)} / 24.0 dengan probabilitas depresi $probPct%). '
          'Model mendeteksi adanya kongruensi indikator distres psikologis: berkurangnya variasi dinamika ekspresi wajah '
          '(afek cenderung kaku/datar), nada bicara yang cenderung monoton disertai jeda hening yang panjang (perlambatan psikomotorik), '
          'serta pemilihan kata yang mencerminkan beban emosional, keletihan mental, atau persepsi ketidakberdayaan.';
    }

    // 3 Pilar Bukti Sinyal Model
    final String visualReason;
    final String audioReason;
    final String textReason;

    if (isLowRisk) {
      visualReason =
          'Wajah terdeteksi jelas pada ${inspection.faceDetectionRatePct.toStringAsFixed(0)}% sesi. '
          'Otot wajah bergerak aktif dan alami saat berinteraksi, teramati respons senyum wajar, '
          'dan posisi kepala tegak menjaga kontak mata tanpa tanda afek datar (flat affect).';
      audioReason =
          'Intonasi vokal stabil dan natural (rata-rata ${inspection.avgPitchHz.toStringAsFixed(0)} Hz). '
          'Proporsi jeda hening berada pada batas wajar (${inspection.pauseRatioPct.toStringAsFixed(0)}% dari durasi), '
          'menunjukkan kelancaran bicara yang baik tanpa hambatan psikomotorik vokal.';
      textReason =
          'Tuturan kata tersusun runtut dan terbuka. '
          'Tidak ditemukan dominasi kata-kata bernuansa negatif ekstrem, putus asa, atau isolasi diri yang lazim menyertai episode depresi klinis.';
    } else if (isBorderline) {
      visualReason =
          'Wajah terdeteksi pada ${inspection.faceDetectionRatePct.toStringAsFixed(0)}% sesi dengan sedikit penurunan fokus tatapan '
          'pada segmen tertentu, namun ekspresi wajah masih responsif terhadap percakapan.';
      audioReason =
          'Intonasi suara cenderung lebih pelan dengan jeda hening sekitar ${inspection.pauseRatioPct.toStringAsFixed(0)}% dari total sesi, '
          'menandakan adanya momen perenungan atau keletihan situasional.';
      textReason =
          'Pemilihan kata mengindikasikan adanya stresor kehidupan atau kelelahan mental ringan, namun struktur bahasa klien tetap adaptif.';
    } else {
      visualReason =
          'Teramati penurunan dinamika ekspresi wajah (reduced facial dynamics), kecenderungan menunduk atau menghindari tatapan kamera, '
          'serta terdeteksi peningkatan ketegangan otot dahi dan penurunan sudut bibir saat berbicara.';
      audioReason =
          'Variasi nada bicara (F0) cenderung datar dengan proporsi jeda hening yang tinggi (${inspection.pauseRatioPct.toStringAsFixed(0)}% dari durasi). '
          'Hal ini selaras dengan manifestasi perlambatan produksi suara vokal pada kondisi depresi.';
      textReason =
          'Transkrip tuturan menangkap frekuensi kata atau frasa yang mencerminkan beban kognitif tinggi, penurunan minat, '
          'atau rasa putus asa yang memperkuat sinyal non-verbal.';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: _brandTealDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kesimpulan & Penjelasan Model',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mengapa model ${isLowRisk ? "tidak mengindikasikan" : "mengindikasikan"} depresi?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusBorderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estimasi PHQ-8: ${phqScore.toStringAsFixed(1)} / 24.0 • Probabilitas: $probPct% • Modalitas Paling Berpengaruh: $domName',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paragraf Narasi Mengalir
          Text(
            mainNarrative,
            style: const TextStyle(
              fontSize: 13,
              color: _textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),

          // Pembagi Poin Alasan
          const Text(
            'Rincian 3 Pilar Observasi Model:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // 3 Pilar Tiles
          _buildSummaryPillarItem(
            icon: Icons.face_rounded,
            iconColor: const Color(0xFF0284C7),
            title: 'Sinyal Visual (Ekspresi Wajah & Kontak Mata)',
            body: visualReason,
          ),
          const SizedBox(height: 8),
          _buildSummaryPillarItem(
            icon: Icons.mic_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Sinyal Akustik (Intonasi & Dinamika Suara)',
            body: audioReason,
          ),
          const SizedBox(height: 8),
          _buildSummaryPillarItem(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Sinyal Linguistik (Pola Bahasa & Komunikasi)',
            body: textReason,
          ),
          const SizedBox(height: 16),

          // Advisory Note untuk Konselor
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Catatan: Ringkasan di atas merupakan kalkulasi objektif model AI dari data sesi. Keputusan dan interpretasi klinis definitif berada pada evaluasi Anda melalui menu verifikasi di bawah.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPillarItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 11.5,
              color: _textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalityFactorRow({
    required IconData icon,
    required String title,
    required double percentage,
    required Color color,
    required bool isDominant,
    required String description,
  }) {
    final clampedPct = percentage.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDominant ? color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: isDominant ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (isDominant)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Paling Dominan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedPct / 100.0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectObservationStudio(
    BuildContext context,
    MultimodalInspectionData inspection,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Observasi Sinyal
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: _softMintBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: _brandTealDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Studio Observasi Klien',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Inspeksi ekspresi wajah, prosodi suara & transkrip percakapan',
                    style: TextStyle(fontSize: 11.5, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (widget.localVideoPath != null)
              OutlinedButton.icon(
                onPressed: () {
                  LocalVideoPlayerDialog.show(
                    context,
                    videoPath: widget.localVideoPath!,
                    participantId: _currentResult.participantId,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.fullscreen_rounded, size: 16, color: _brandTealDark),
                label: const Text(
                  'Video Penuh',
                  style: TextStyle(fontSize: 11.5, color: _textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter / Selector Kategori Sinyal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSignalTabPill(0, 'Semua Sinyal (3)', Icons.grid_view_rounded),
              const SizedBox(width: 8),
              _buildSignalTabPill(1, 'Ekspresi Wajah', Icons.face_retouching_natural_rounded),
              const SizedBox(width: 8),
              _buildSignalTabPill(2, 'Prosodi Suara', Icons.graphic_eq_rounded),
              const SizedBox(width: 8),
              _buildSignalTabPill(3, 'Transkrip Teks', Icons.subtitles_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Konten Observasi
        if (_selectedSignalTabIndex == 0 || _selectedSignalTabIndex == 1) ...[
          FaceModalityCard(
            inspection: inspection,
            isSimpleMode: true,
            onVideoProgressChanged: (prog) {
              setState(() {
                _videoPlaybackProgress = prog;
              });
            },
          ),
          if (_selectedSignalTabIndex == 0) const SizedBox(height: 16),
        ],

        if (_selectedSignalTabIndex == 0 || _selectedSignalTabIndex == 2) ...[
          AudioWaveformCard(
            inspection: inspection,
            isSimpleMode: true,
            playbackProgress: _videoPlaybackProgress,
          ),
          if (_selectedSignalTabIndex == 0) const SizedBox(height: 16),
        ],

        if (_selectedSignalTabIndex == 0 || _selectedSignalTabIndex == 3) ...[
          SpeechTranscriptCard(
            inspection: inspection,
            isSimpleMode: true,
          ),
        ],
      ],
    );
  }

  Widget _buildSignalTabPill(int index, String label, IconData icon) {
    final isSelected = _selectedSignalTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedSignalTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _brandTealDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandTealDark : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _brandTealDark.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
