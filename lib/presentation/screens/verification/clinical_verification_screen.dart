import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

/// Layar terpisah khusus verifikasi konselor / klinisi (Human-in-the-Loop)
/// Memisahkan proses audit klinis, evaluasi ground-truth, dan pencatatan SOAP
/// dari tampilan hasil murni model skrining.
class ClinicalVerificationScreen extends StatefulWidget {
  final ScreeningResponse screening;
  final MultimodalInspectionData? inspectionData;
  final String? localVideoPath;

  const ClinicalVerificationScreen({
    super.key,
    required this.screening,
    this.inspectionData,
    this.localVideoPath,
  });

  @override
  State<ClinicalVerificationScreen> createState() =>
      _ClinicalVerificationScreenState();
}

class _ClinicalVerificationScreenState
    extends State<ClinicalVerificationScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);

  late String _concordanceStatus; // valid, overestimated, underestimated, artifact
  late double _groundTruthPhq8;
  late bool _visualPlausible;
  late bool _audioPlausible;
  late bool _textPlausible;
  late bool _isVerified;
  bool _isSaving = false;

  late final TextEditingController _soapSubjectiveCtrl;
  late final TextEditingController _soapObjectiveCtrl;
  late final TextEditingController _soapAssessmentCtrl;
  late final TextEditingController _soapPlanCtrl;

  @override
  void initState() {
    super.initState();
    final ver = widget.screening.clinicalVerification;
    final modelScore = widget.screening.prediction?.phq8Score ?? 0.0;
    final riskCat = widget.screening.prediction?.riskCategory ?? 'low';
    final domMod =
        widget.screening.patientModalityAttribution?.dominantModality ?? 'visual';

    _isVerified = ver?.isVerified ?? false;
    _concordanceStatus = ver?.concordanceStatus ?? 'valid';
    _groundTruthPhq8 = ver?.groundTruthPhq8 ??
        modelScore.roundToDouble().clamp(0.0, 24.0);
    _visualPlausible = ver?.visualPlausible ??
        (widget.screening.qualityFlags?.poorVisualQuality != true);
    _audioPlausible = ver?.audioPlausible ??
        (widget.screening.qualityFlags?.poorAudioQuality != true);
    _textPlausible = ver?.textPlausible ??
        (widget.screening.qualityFlags?.lowTextInformation != true);

    _soapSubjectiveCtrl = TextEditingController(
      text: (ver?.soapSubjective.isNotEmpty == true)
          ? ver!.soapSubjective
          : (widget.screening.initialCounselorNote?.isNotEmpty == true
              ? widget.screening.initialCounselorNote!
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

  double get _modelPhq8 => widget.screening.prediction?.phq8Score ?? 0.0;
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

  Future<void> _saveVerification() async {
    setState(() {
      _isSaving = true;
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
      screening: widget.screening,
      verification: verification,
      inspectionData: widget.inspectionData,
      videoPath: widget.localVideoPath,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
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

    if (ok) {
      Navigator.pop(context, true);
    }
  }

  void _copySoapResumeToClipboard(BuildContext context) {
    final prediction = widget.screening.prediction;
    final riskCategory = prediction?.riskCategory ?? 'low';
    final domMod =
        widget.screening.patientModalityAttribution?.dominantModality ?? 'visual';
    final sign = _deviationDelta >= 0 ? '+' : '';

    final soapResume = '''
=== RESUME KLINIS FORMAT SOAP & AUDIT MODEL CDSS ===
ID Klien / RM     : ${widget.screening.participantId}
ID Sesi           : ${widget.screening.screeningId}
Waktu Pemeriksaan : ${_formatDate(widget.screening.createdAt ?? '')}

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
    final screening = widget.screening;
    final prediction = screening.prediction;
    final riskCategory = prediction?.riskCategory ?? 'low';
    final riskColor = ClinicalConstants.getRiskColor(riskCategory);
    final isSim = screening.isSimulation;

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
              'Verifikasi Konselor: ${screening.participantId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const Text(
              'Lembar Validasi & Catatan Klinis Mandiri',
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
            tooltip: 'Salin Format SOAP',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Status Referensi Model AI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 18,
                            color: _brandTealDark,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Referensi Hasil Estimasi AI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isVerified
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isVerified
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          _isVerified ? 'Sudah Diverifikasi' : 'Belum Diverifikasi',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _isVerified
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        _modelPhq8.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '/ 24.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      RiskBadge(riskCategory: riskCategory),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Waktu Sesi: ${_formatDate(screening.createdAt ?? "")}',
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // FORM VERIFIKASI KLINIS
            Container(
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_outlined, color: _brandTeal, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Evaluasi Ahli Klinis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tentukan kesesuaian hasil model dengan wawancara dan observasi klinis langsung Anda.',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 18),

                  // A. Kesesuaian Prediksi Model (Concordance Pills)
                  const Text(
                    '1. Kesesuaian Prediksi Model:',
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
                  const SizedBox(height: 20),

                  // B. Input Skor PHQ-8 Aktual
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          '2. Skor PHQ-8 Aktual (Asesmen Riil):',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                  const SizedBox(height: 16),

                  // C. Validitas Modalitas Sensor
                  const Text(
                    '3. Validitas Sensor saat Observasi:',
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
                        label: 'Visual (Wajah)',
                        value: _visualPlausible,
                        onChanged: (v) => setState(() => _visualPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        label: 'Akustik (Suara)',
                        value: _audioPlausible,
                        onChanged: (v) => setState(() => _audioPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        label: 'Linguistik (Teks)',
                        value: _textPlausible,
                        onChanged: (v) => setState(() => _textPlausible = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // D. Catatan SOAP Terstruktur
                  const Text(
                    '4. Catatan Klinis Standar (SOAP):',
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
                    label: 'Assessment (Analisis Konselor)',
                    controller: _soapAssessmentCtrl,
                  ),
                  const SizedBox(height: 10),
                  _buildSoapInput(
                    badge: 'P',
                    label: 'Plan (Rencana Tindak Lanjut)',
                    controller: _soapPlanCtrl,
                  ),
                  const SizedBox(height: 22),

                  // Tombol Simpan
                  if (isSim)
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
                            Icons.science_outlined,
                            size: 18,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sesi Simulasi • Verifikasi Hanya Disimpan Lokal',
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
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveVerification,
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
                              ? Icons.check_circle_outline_rounded
                              : Icons.save_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _isSaving
                              ? 'Menyimpan...'
                              : (_isVerified
                                  ? 'Perbarui Verifikasi Rekam Medis'
                                  : 'Simpan Verifikasi ke Rekam Medis'),
                          style: const TextStyle(
                            fontSize: 13.5,
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
}

