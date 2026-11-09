import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/core/services/multimodal_extractor_service.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/multimodal_analysis_studio_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/local_video_player_dialog.dart';
import 'package:fedmind_mobile_app/presentation/widgets/modality_shapley_chart.dart';
import 'package:fedmind_mobile_app/presentation/widgets/quality_flag_alert.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';
import 'package:fedmind_mobile_app/presentation/widgets/xai_pipeline/interactive_shapley_balance.dart';

class ScreeningResultScreen extends StatefulWidget {
  final ScreeningResponse result;
  final String? localVideoPath;
  final MultimodalInspectionData? inspectionData;
  final bool isSimulation;

  const ScreeningResultScreen({
    super.key,
    required this.result,
    this.localVideoPath,
    this.inspectionData,
    this.isSimulation = false,
  });

  @override
  State<ScreeningResultScreen> createState() => _ScreeningResultScreenState();
}

class _ScreeningResultScreenState extends State<ScreeningResultScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);

  // State Verifikasi Model Klinis (Human-in-the-Loop)
  late String _concordanceStatus; // valid, overestimated, underestimated, artifact
  late double _groundTruthPhq8;
  late bool _visualPlausible;
  late bool _audioPlausible;
  late bool _textPlausible;
  late bool _isVerified;
  bool _isSavingVerification = false;
  bool _isTechnicalAuditExpanded = false;
  bool get _isSim => widget.isSimulation || widget.result.isSimulation;

  // Controllers Catatan SOAP Terstruktur
  late final TextEditingController _soapSubjectiveCtrl;
  late final TextEditingController _soapObjectiveCtrl;
  late final TextEditingController _soapAssessmentCtrl;
  late final TextEditingController _soapPlanCtrl;

  @override
  void initState() {
    super.initState();
    final ver = widget.result.clinicalVerification;
    final modelScore = widget.result.prediction?.phq8Score ?? 0.0;
    final riskCat = widget.result.prediction?.riskCategory ?? 'low';
    final domMod =
        widget.result.patientModalityAttribution?.dominantModality ?? 'visual';

    _isVerified = ver?.isVerified ?? false;
    _concordanceStatus = ver?.concordanceStatus ?? 'valid';
    _groundTruthPhq8 = ver?.groundTruthPhq8 ??
        modelScore.roundToDouble().clamp(0.0, 24.0);
    _visualPlausible = ver?.visualPlausible ??
        (widget.result.qualityFlags?.poorVisualQuality != true);
    _audioPlausible = ver?.audioPlausible ??
        (widget.result.qualityFlags?.poorAudioQuality != true);
    _textPlausible = ver?.textPlausible ??
        (widget.result.qualityFlags?.lowTextInformation != true);

    _soapSubjectiveCtrl = TextEditingController(
      text: (ver?.soapSubjective.isNotEmpty == true)
          ? ver!.soapSubjective
          : (widget.result.initialCounselorNote?.isNotEmpty == true
              ? widget.result.initialCounselorNote!
              : 'Klien melaporkan keluhan suasana perasaan, kualitas tidur, dan kelelahan dalam 2 minggu terakhir.'),
    );

    _soapObjectiveCtrl = TextEditingController(
      text: (ver?.soapObjective.isNotEmpty == true)
          ? ver!.soapObjective
          : 'Estimasi AI PHQ-8: ${modelScore.toStringAsFixed(1)}/24.0 (${ClinicalConstants.getRiskLabel(riskCat)}). '
              'Modalitas dominan: ${ClinicalConstants.getModalityClinicalName(domMod)}.',
    );

    _soapAssessmentCtrl = TextEditingController(
      text: (ver?.soapAssessment.isNotEmpty == true)
          ? ver!.soapAssessment
          : ClinicalConstants.getRiskDescription(riskCat),
    );

    _soapPlanCtrl = TextEditingController(
      text: (ver?.soapPlan.isNotEmpty == true)
          ? ver!.soapPlan
          : ClinicalConstants.getCounselingGuidance(riskCat),
    );
  }

  @override
  void dispose() {
    _soapSubjectiveCtrl.dispose();
    _soapObjectiveCtrl.dispose();
    _soapAssessmentCtrl.dispose();
    _soapPlanCtrl.dispose();
    super.dispose();
  }

  double get _modelPhq8 => widget.result.prediction?.phq8Score ?? 0.0;

  /// Deviasi otomatis: \Delta = Prediksi Model - Skor Riil
  double get _deviationDelta => _modelPhq8 - _groundTruthPhq8;

  String get _groundTruthRiskCategory {
    if (_groundTruthPhq8 >= 15) return 'high';
    if (_groundTruthPhq8 >= 10) return 'moderate';
    if (_groundTruthPhq8 >= 8) return 'borderline';
    return 'low';
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _saveVerificationToDatabase() async {
    setState(() {
      _isSavingVerification = true;
    });

    final provider = context.read<ScreeningProvider>();
    final verification = ClinicalVerificationData(
      isVerified: true,
      concordanceStatus: _concordanceStatus,
      groundTruthPhq8: _groundTruthPhq8,
      deviationDelta: double.parse(_deviationDelta.toStringAsFixed(2)),
      visualPlausible: _visualPlausible,
      audioPlausible: _audioPlausible,
      textPlausible: _textPlausible,
      soapSubjective: _soapSubjectiveCtrl.text.trim(),
      soapObjective: _soapObjectiveCtrl.text.trim(),
      soapAssessment: _soapAssessmentCtrl.text.trim(),
      soapPlan: _soapPlanCtrl.text.trim(),
      verifiedBy: 'Konselor Klinis CDSS',
      verifiedAt: DateTime.now().toIso8601String(),
    );

    final ok = await provider.saveClinicalVerification(
      screening: widget.result,
      verification: verification,
      inspectionData: widget.inspectionData,
      videoPath: widget.localVideoPath,
    );

    if (!mounted) return;
    setState(() {
      _isSavingVerification = false;
      if (ok) _isVerified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Verifikasi klinis berhasil disimpan ke rekam medis lokal.'
              : 'Gagal menyimpan verifikasi klinis.',
        ),
        backgroundColor: ok ? _brandTealDark : const Color(0xFFDC2626),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copySoapResumeToClipboard(BuildContext context) {
    final prediction = widget.result.prediction;
    final riskCategory = prediction?.riskCategory ?? 'low';
    final domMod =
        widget.result.patientModalityAttribution?.dominantModality ?? 'visual';
    final sign = _deviationDelta >= 0 ? '+' : '';

    final soapResume = '''
=== RESUME KLINIS FORMAT SOAP & AUDIT MODEL CDSS ===
ID Klien / RM     : ${widget.result.participantId}
ID Sesi           : ${widget.result.screeningId}
Waktu Pemeriksaan : ${_formatDate(widget.result.createdAt ?? '')}
Model Checkpoint  : ${widget.result.model?.name ?? 'FedMind-Multimodal-ONNX v2.4-FL'}

[KOMPARASI DIAGNOSTIK & VERIFIKASI MODEL]
• Estimasi Model AI : ${_modelPhq8.toStringAsFixed(1)} / 24.0 (${ClinicalConstants.getRiskLabel(riskCategory)})
• Skor PHQ-8 Aktual : ${_groundTruthPhq8.toStringAsFixed(0)} / 24.0 (${ClinicalConstants.getRiskLabel(_groundTruthRiskCategory)})
• Deviasi (Δ)       : $sign${_deviationDelta.toStringAsFixed(1)} poin PHQ-8
• Tingkat Kesesuaian: ${ClinicalConstants.getConcordanceLabel(_concordanceStatus)}
• Dominan Modalitas : ${ClinicalConstants.getModalityClinicalName(domMod)}

[AUDIT VALIDITAS MODALITAS]
• Visual (Action Units) : ${_visualPlausible ? 'Valid' : 'Anomali/Artefak'}
• Akustik (Audio)       : ${_audioPlausible ? 'Valid' : 'Anomali/Artefak'}
• Linguistik (Teks)     : ${_textPlausible ? 'Valid' : 'Anomali/Artefak'}

[CATATAN KLINIS STANDAR SOAP]
S (Subjective) : ${_soapSubjectiveCtrl.text.trim()}
O (Objective)  : ${_soapObjectiveCtrl.text.trim()}
A (Assessment) : ${_soapAssessmentCtrl.text.trim()}
P (Plan)       : ${_soapPlanCtrl.text.trim()}
====================================================
''';

    Clipboard.setData(ClipboardData(text: soapResume));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume klinis SOAP berhasil disalin ke Clipboard.'),
        backgroundColor: _brandTealDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final prediction = result.prediction;
    final attribution = result.patientModalityAttribution;
    final riskCategory = prediction?.riskCategory;
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);
    final domModality = attribution?.dominantModality ?? 'visual';

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
              'Hasil Skrining & Verifikasi Model',
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
            onPressed: () => _copySoapResumeToClipboard(context),
            icon: const Icon(Icons.copy_all_rounded, color: _textSecondary),
            tooltip: 'Salin Resume SOAP',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Mode Simulasi (jika sesi berasal dari simulasi / non-clinical)
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
                            'Sesi ini hanya untuk pengujian model on-device. Data tidak disimpan ke rekam medis dan tidak masuk dalam antrean verifikasi klinisi.',
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
            // 1. KARTU HASIL UTAMA (BERSIH & MODERN)
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isVerified
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isVerified
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isVerified
                                  ? Icons.check_circle_rounded
                                  : Icons.hourglass_top_rounded,
                              size: 13,
                              color: _isVerified
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isVerified ? 'Terverifikasi' : 'Perlu Review',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _isVerified
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

                  // Nilai Skor & Badge Kategori Risiko
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _modelPhq8.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 40,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      RiskBadge(riskCategory: riskCategory),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pill Info Dominan Modalitas
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ClinicalConstants.getModalityIcon(domModality),
                          size: 16,
                          color: _brandTealDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Modalitas Dominan: ${ClinicalConstants.getModalityClinicalName(domModality)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          'Prob: ${((prediction?.riskProbabilityProxy ?? 0) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _brandTealDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Narasi Klinis
                  if (result.clinicalNarrative != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _softMintBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.clinicalNarrative!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // =================================================================
            // 2. PANEL VERIFIKASI KLINISI (HUMAN-IN-THE-LOOP)
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
                  const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: _brandTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Verifikasi Ahli & Ground-Truth',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _brandTeal,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Evaluasi apakah prediksi model selaras dengan observasi klinis Anda.',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // A. Kesesuaian Prediksi (Concordance Pills)
                  const Text(
                    'Kesesuaian Prediksi Model (Concordance):',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildConcordancePill(
                        keyName: 'valid',
                        label: 'Sesuai / Valid',
                        color: const Color(0xFF10B981),
                      ),
                      _buildConcordancePill(
                        keyName: 'overestimated',
                        label: 'Terlalu Tinggi',
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildConcordancePill(
                        keyName: 'underestimated',
                        label: 'Terlalu Rendah',
                        color: const Color(0xFFF97316),
                      ),
                      _buildConcordancePill(
                        keyName: 'artifact',
                        label: 'Anomali Sensor',
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // B. Input Skor Ground-Truth PHQ-8
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Skor PHQ-8 Aktual (Asesmen Riil):',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _softMintBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_groundTruthPhq8.toStringAsFixed(0)} / 24  (${_deviationDelta >= 0 ? '+' : ''}${_deviationDelta.toStringAsFixed(1)} Δ)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _brandTealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _brandTeal,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: _brandTealDark,
                      overlayColor: _brandTeal.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _groundTruthPhq8,
                      min: 0,
                      max: 24,
                      divisions: 24,
                      onChanged: (val) {
                        setState(() => _groundTruthPhq8 = val.roundToDouble());
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // C. Validitas Modalitas
                  const Text(
                    'Audit Validitas Sensor Multimodal:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlausibilityToggle(
                        label: 'Visual AU',
                        value: _visualPlausible,
                        onChanged: (v) => setState(() => _visualPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        label: 'Akustik Audio',
                        value: _audioPlausible,
                        onChanged: (v) => setState(() => _audioPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        label: 'Linguistik Teks',
                        value: _textPlausible,
                        onChanged: (v) => setState(() => _textPlausible = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // D. Catatan SOAP Terstruktur
                  const Text(
                    'Catatan Klinis Standar (SOAP):',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSoapInput(
                    badge: 'S',
                    label: 'Subjective (Keluhan Klien)',
                    controller: _soapSubjectiveCtrl,
                  ),
                  const SizedBox(height: 10),
                  _buildSoapInput(
                    badge: 'O',
                    label: 'Objective (Observasi & AI)',
                    controller: _soapObjectiveCtrl,
                  ),
                  const SizedBox(height: 10),
                  _buildSoapInput(
                    badge: 'A',
                    label: 'Assessment (Analisis Klinisi)',
                    controller: _soapAssessmentCtrl,
                  ),
                  const SizedBox(height: 10),
                  _buildSoapInput(
                    badge: 'P',
                    label: 'Plan (Rencana Intervensi)',
                    controller: _soapPlanCtrl,
                  ),
                  const SizedBox(height: 18),

                  // Tombol Simpan Verifikasi / Status Sesi Simulasi
                  if (_isSim)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sesi Simulasi • Tidak Masuk Antrean Verifikasi',
                            style: TextStyle(
                              fontSize: 12.5,
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
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingVerification
                            ? null
                            : _saveVerificationToDatabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandTeal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          _isVerified
                              ? Icons.check_circle_outline
                              : Icons.save_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _isSavingVerification
                              ? 'Menyimpan...'
                              : 'Simpan Verifikasi ke Rekam Medis Lokal',
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
            const SizedBox(height: 18),

            // =================================================================
            // 3. STUDIO OBSERVASI MULTIMODAL SHORTCUT (TASTE MODERN)
            // =================================================================
            _buildStudioShortcutCard(context, result),
            const SizedBox(height: 18),

            // Video player jika ada rekaman video
            if (widget.localVideoPath != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: _softMintBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: _brandTealDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekaman Observasi Sesi',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'Tersimpan aman di penyimpanan internal',
                            style: TextStyle(fontSize: 11, color: _textSecondary),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Putar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Shapley Balance
            InteractiveShapleyBalance(
              screening: result,
              isSimpleMode: false,
            ),
            const SizedBox(height: 18),

            // Modality Chart
            if (attribution != null)
              ModalityShapleyChart(
                attribution: attribution,
                globalReference: result.globalReference,
              ),
            const SizedBox(height: 18),

            // Quality Flags Alert
            QualityFlagAlert(flags: result.qualityFlags),
            const SizedBox(height: 18),

            // Telemetri Teknis Model (Collapsible)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFF1F5F9)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _isTechnicalAuditExpanded,
                onExpansionChanged: (val) => setState(() => _isTechnicalAuditExpanded = val),
                leading: const Icon(Icons.tune_rounded, color: _brandTealDark, size: 20),
                title: const Text(
                  'Telemetri Model & Baseline XAI',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: _textPrimary,
                  ),
                ),
                subtitle: const Text(
                  '8 koalisi laten & verifikasi aksioma efisiensi',
                  style: TextStyle(fontSize: 11, color: _textMuted),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      children: [
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 4),
                        _buildMetaRow(
                          'Model Checkpoint',
                          result.model?.name ?? 'FedMind-ONNX v2.4-FL',
                        ),
                        _buildMetaRow(
                          'Arsitektur Fusi',
                          result.model?.architecture ?? 'Late-Fusion Attention',
                        ),
                        _buildMetaRow(
                          'Metode XAI',
                          '${result.xai?.method ?? "Exact Shapley"} (${result.xai?.numCoalitions ?? 8} koalisi)',
                        ),
                        _buildMetaRow(
                          'Baseline E[f(X)]',
                          result.xai?.baselineExpectedValue.toStringAsFixed(3) ?? '8.420',
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
    );
  }

  Widget _buildConcordancePill({
    required String keyName,
    required String label,
    required Color color,
  }) {
    final isSelected = _concordanceStatus == keyName;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _concordanceStatus = keyName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlausibilityToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: value ? _softMintBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? _brandTeal : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: value ? _brandTealDark : _textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: value ? _brandTealDark : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoapInput({
    required String badge,
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _brandTeal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: _textPrimary, height: 1.35),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioShortcutCard(BuildContext context, ScreeningResponse result) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final provider = context.read<ScreeningProvider>();
            final ins = widget.inspectionData ??
                provider.getInspectionForScreening(result.screeningId) ??
                MultimodalExtractorService.buildInspectionFromSampleFeatures(
                  participantId: result.participantId,
                  visualFeatures: List.filled(75, 0.2),
                  audioFeatures: List.filled(248, 0.2),
                  textFeatures: List.filled(768, 0.1),
                );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MultimodalAnalysisStudioScreen(
                  result: result,
                  inspection: ins,
                  localVideoPath: widget.localVideoPath,
                  isFromResultScreen: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _softMintBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: _brandTealDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Studio Observasi Multimodal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Inspeksi Action Units wajah, prosodi suara & transkrip',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
