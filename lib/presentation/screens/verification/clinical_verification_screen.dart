import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/core/services/validation_export_service.dart';
import 'package:fedmind_mobile_app/data/models/multimodal_inspection_models.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/main_navigation_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_bottom_nav_bar.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

class _Phq8ItemSpec {
  final String key;
  final String title;
  final String desc;

  const _Phq8ItemSpec({
    required this.key,
    required this.title,
    required this.desc,
  });
}

/// Layar terpisah khusus verifikasi konselor / klinisi (Human-in-the-Loop)
/// Dirancang sederhana, intuitif, ramah pengguna, dan dilengkapi navigasi bawah terintegrasi.
class ClinicalVerificationScreen extends StatefulWidget {
  final ScreeningResponse screening;
  final MultimodalInspectionData? inspectionData;
  final String? localVideoPath;
  final int initialNavIndex;

  const ClinicalVerificationScreen({
    super.key,
    required this.screening,
    this.inspectionData,
    this.localVideoPath,
    this.initialNavIndex = 3,
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

  static const List<String> _validatorRoles = [
    'Psikolog Klinis',
    'Psikiater',
    'Peneliti Klinis',
    'Konselor Tersertifikasi',
  ];

  static const List<_Phq8ItemSpec> _phq8ItemSpecs = [
    _Phq8ItemSpec(
      key: 'q1_anhedonia',
      title: '1. Anhedonia / Kehilangan Minat',
      desc: 'Kurang berminat atau kurang bergairah dalam melakukan apapun.',
    ),
    _Phq8ItemSpec(
      key: 'q2_depressed_mood',
      title: '2. Suasana Hati Depresif',
      desc: 'Merasa murung, sedih, atau putus asa.',
    ),
    _Phq8ItemSpec(
      key: 'q3_sleep',
      title: '3. Gangguan Tidur',
      desc: 'Sulit tidur, mudah terbangun, atau terlalu banyak tidur.',
    ),
    _Phq8ItemSpec(
      key: 'q4_fatigue',
      title: '4. Kelelahan / Kurang Energi',
      desc: 'Merasa lelah atau kurang bertenaga.',
    ),
    _Phq8ItemSpec(
      key: 'q5_appetite',
      title: '5. Perubahan Nafsu Makan',
      desc: 'Kurang nafsu makan atau terlalu banyak makan.',
    ),
    _Phq8ItemSpec(
      key: 'q6_worthlessness',
      title: '6. Perasaan Tidak Berharga',
      desc: 'Kurang percaya diri, merasa gagal, atau mengecewakan diri/keluarga.',
    ),
    _Phq8ItemSpec(
      key: 'q7_concentration',
      title: '7. Kesulitan Konsentrasi',
      desc: 'Sulit berkonsentrasi saat membaca atau menonton.',
    ),
    _Phq8ItemSpec(
      key: 'q8_psychomotor',
      title: '8. Perubahan Psikomotor',
      desc: 'Bergerak/berbicara sangat lambat atau justru sangat gelisah.',
    ),
  ];

  late int _currentNavIndex;
  String? _concordanceStatus; // valid, overestimated, underestimated, artifact
  late Map<String, int?> _phq8Items;
  double? _legacyGroundTruth;
  late bool _visualPlausible;
  late bool _audioPlausible;
  late bool _textPlausible;
  late bool _isVerified;
  bool _isSaving = false;

  late String _validatorRole;
  late final TextEditingController _validatorNameCtrl;
  late final TextEditingController _soapSubjectiveCtrl;
  late final TextEditingController _soapObjectiveCtrl;
  late final TextEditingController _soapAssessmentCtrl;
  late final TextEditingController _soapPlanCtrl;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex.clamp(0, 4);

    final ver = widget.screening.clinicalVerification;
    final hasExistingVerification = ver != null && ver.isVerified;

    _isVerified = hasExistingVerification;
    _concordanceStatus = hasExistingVerification ? ver.concordanceStatus : null;

    _phq8Items = {
      for (final key in ValidationExportService.phq8ItemKeys)
        key: ver?.phq8ItemScores?[key],
    };
    _legacyGroundTruth =
        (hasExistingVerification && ver.phq8ItemScores == null)
            ? ver.groundTruthPhq8
            : null;

    _visualPlausible = ver?.visualPlausible ??
        (widget.screening.qualityFlags?.poorVisualQuality != true);
    _audioPlausible = ver?.audioPlausible ??
        (widget.screening.qualityFlags?.poorAudioQuality != true);
    _textPlausible = ver?.textPlausible ??
        (widget.screening.qualityFlags?.lowTextInformation != true);

    final existingRole = ver?.validatorRole;
    _validatorRole =
        (existingRole != null && _validatorRoles.contains(existingRole))
            ? existingRole
            : _validatorRoles.first;

    _validatorNameCtrl = TextEditingController(
      text: ver?.validatorName ?? '',
    )..addListener(() => setState(() {}));

    _soapSubjectiveCtrl = TextEditingController(
      text: hasExistingVerification && ver.soapSubjective.isNotEmpty
          ? ver.soapSubjective
          : (widget.screening.initialCounselorNote?.trim() ?? ''),
    );

    _soapObjectiveCtrl = TextEditingController(
      text: hasExistingVerification ? ver.soapObjective : '',
    );

    _soapAssessmentCtrl = TextEditingController(
      text: hasExistingVerification ? ver.soapAssessment : '',
    );

    _soapPlanCtrl = TextEditingController(
      text: hasExistingVerification ? ver.soapPlan : '',
    );
  }

  @override
  void dispose() {
    _validatorNameCtrl.dispose();
    _soapSubjectiveCtrl.dispose();
    _soapObjectiveCtrl.dispose();
    _soapAssessmentCtrl.dispose();
    _soapPlanCtrl.dispose();
    super.dispose();
  }

  double get _modelPhq8 => widget.screening.prediction?.phq8Score ?? 0.0;

  int get _completedPhq8ItemsCount =>
      _phq8Items.values.where((v) => v != null).length;

  bool get _allPhq8ItemsCompleted =>
      _completedPhq8ItemsCount == ValidationExportService.phq8ItemKeys.length;

  int get _partialPhq8Sum =>
      _phq8Items.values.fold<int>(0, (sum, v) => sum + (v ?? 0));

  double? get _effectiveGroundTruthPhq8 {
    if (_allPhq8ItemsCompleted) {
      return _partialPhq8Sum.toDouble();
    }
    return _legacyGroundTruth;
  }

  double? get _deviationDelta {
    final gt = _effectiveGroundTruthPhq8;
    if (gt == null) return null;
    return _modelPhq8 - gt;
  }

  String get _groundTruthRiskCategory {
    final gt = _effectiveGroundTruthPhq8 ?? 0.0;
    if (gt >= 15.0) return 'high';
    if (gt >= 9.4) return 'moderate';
    if (gt >= 8.0) return 'borderline';
    return 'low';
  }

  bool get _canSave =>
      _concordanceStatus != null &&
      _effectiveGroundTruthPhq8 != null &&
      _validatorNameCtrl.text.trim().isNotEmpty;

  String _getRiskDescriptionShort(String riskCat) {
    switch (riskCat.toLowerCase()) {
      case 'low':
        return 'Minimal / Risiko Rendah (0–7.9)';
      case 'borderline':
        return 'Subklinis / Ringan (8.0–9.3)';
      case 'moderate':
        return 'Gejala Sedang (9.4–14.9)';
      case 'high':
        return 'Gejala Berat (15.0–24.0)';
      default:
        return 'Minimal / Risiko Rendah (0–7.9)';
    }
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
    if (!_canSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lengkapi status kesesuaian AI, seluruh 8 butir PHQ-8, dan nama validator terlebih dahulu.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final provider = context.read<ScreeningProvider>();
    final gtScore = _effectiveGroundTruthPhq8!;
    final delta = _modelPhq8 - gtScore;
    final valName = _validatorNameCtrl.text.trim();
    final phqMap = _allPhq8ItemsCompleted
        ? _phq8Items.map((k, v) => MapEntry(k, v!))
        : null;

    final verification = ClinicalVerificationData(
      isVerified: true,
      concordanceStatus: _concordanceStatus!,
      groundTruthPhq8: gtScore,
      deviationDelta: double.parse(delta.toStringAsFixed(2)),
      visualPlausible: _visualPlausible,
      audioPlausible: _audioPlausible,
      textPlausible: _textPlausible,
      soapSubjective: _soapSubjectiveCtrl.text.trim(),
      soapObjective: _soapObjectiveCtrl.text.trim(),
      soapAssessment: _soapAssessmentCtrl.text.trim(),
      soapPlan: _soapPlanCtrl.text.trim(),
      verifiedBy: '$valName ($_validatorRole)',
      verifiedAt: DateTime.now().toIso8601String(),
      phq8ItemScores: phqMap,
      validatorName: valName,
      validatorRole: _validatorRole,
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
    final gt = _effectiveGroundTruthPhq8;
    final delta = _deviationDelta;
    final sign = (delta != null && delta >= 0) ? '+' : '';
    final gtLine = gt != null
        ? '${gt.toStringAsFixed(0)} / 24.0 (${ClinicalConstants.getRiskLabel(_groundTruthRiskCategory)})'
        : 'Belum dinilai ($_completedPhq8ItemsCount/8 butir)';
    final deltaLine = delta != null
        ? '$sign${delta.toStringAsFixed(1)} poin PHQ-8'
        : 'Belum tersedia';
    final itemBreakdown = _allPhq8ItemsCompleted
        ? '\n• Rincian 8 Butir : ${ValidationExportService.phq8ItemKeys.asMap().entries.map((e) => 'P${e.key + 1}=${_phq8Items[e.value]}').join(', ')}'
        : '';
    final validatorText = _validatorNameCtrl.text.trim().isNotEmpty
        ? '${_validatorNameCtrl.text.trim()} ($_validatorRole)'
        : _validatorRole;

    final soapResume = '''
=== RINGKASAN VERIFIKASI KLINIS (FORMAT SOAP) ===
ID Pasien / RM    : ${widget.screening.participantId}
ID Sesi           : ${widget.screening.screeningId}
Waktu Pemeriksaan : ${_formatDate(widget.screening.createdAt ?? '')}
Validator         : $validatorText

[PERBANDINGAN HASIL]
• Estimasi Model AI  : ${_modelPhq8.toStringAsFixed(1)} / 24.0 (${ClinicalConstants.getRiskLabel(riskCategory)})
• Skor Penilaian Ahli: $gtLine$itemBreakdown
• Selisih (Δ)        : $deltaLine
• Kesesuaian Hasil   : ${ClinicalConstants.getConcordanceLabel(_concordanceStatus)}
• Pengamatan Dominan : ${ClinicalConstants.getModalityClinicalName(domMod)}

[KUALITAS REKAMAN SESI]
• Pengamatan Wajah  : ${_visualPlausible ? 'Jelas & Memadai' : 'Kurang Jelas / Terhalang'}
• Kualitas Suara    : ${_audioPlausible ? 'Jernih & Terdengar' : 'Kurang Jelas / Bising'}
• Respon Percakapan : ${_textPlausible ? 'Memadai & Relevan' : 'Terlalu Sedikit Informasi'}

[CATATAN KONSELING (SOAP)]
S (Keluhan Pasien)  : ${_soapSubjectiveCtrl.text.trim()}
O (Temuan & AI)     : ${_soapObjectiveCtrl.text.trim()}
A (Kesimpulan Ahli) : ${_soapAssessmentCtrl.text.trim()}
P (Rencana Lanjutan): ${_soapPlanCtrl.text.trim()}
=================================================
''';

    Clipboard.setData(ClipboardData(text: soapResume));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan verifikasi berhasil disalin ke Clipboard.'),
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
    final gtRiskColor = ClinicalConstants.getRiskColor(_groundTruthRiskCategory);
    final isSim = screening.isSimulation;
    final provider = context.watch<ScreeningProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verifikasi Ahli',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            Text(
              'ID: ${screening.participantId} • ${_formatDate(screening.createdAt ?? "")}',
              style: const TextStyle(
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
            tooltip: 'Salin Ringkasan Verifikasi',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CARD PERBANDINGAN SKOR (AI vs AHLI)
            _buildComparisonCard(
              screening: screening,
              riskCategory: riskCategory,
              riskColor: riskColor,
              gtRiskColor: gtRiskColor,
            ),
            const SizedBox(height: 16),

            // 2. CARD FORM EVALUASI & PENILAIAN AHLI
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rate_review_outlined,
                          color: _brandTealDark, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Evaluasi Hasil Pemeriksaan',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tentukan kesesuaian estimasi AI dengan hasil observasi langsung Anda:',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // A. Penilaian Kesesuaian AI
                  const Text(
                    '1. Apakah hasil analisis AI sesuai?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildConcordancePill(
                        keyName: 'valid',
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Sesuai / Cocok',
                        color: const Color(0xFF10B981),
                      ),
                      _buildConcordancePill(
                        keyName: 'overestimated',
                        icon: Icons.trending_up_rounded,
                        label: 'Hasil Terlalu Tinggi',
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildConcordancePill(
                        keyName: 'underestimated',
                        icon: Icons.trending_down_rounded,
                        label: 'Hasil Terlalu Rendah',
                        color: const Color(0xFFF97316),
                      ),
                      _buildConcordancePill(
                        keyName: 'artifact',
                        icon: Icons.report_problem_outlined,
                        label: 'Kualitas Rekaman Kurang',
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // B. Penilaian 8 Butir PHQ-8 Aktual Ahli (Wajib Diisi)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          '2. Penilaian Klinis 8 Butir PHQ-8 (Wajib):',
                          style: TextStyle(
                            fontSize: 13,
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
                          color: _effectiveGroundTruthPhq8 != null
                              ? _softMintBg
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _effectiveGroundTruthPhq8 != null
                                ? const Color(0xFF99F6E4)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          _allPhq8ItemsCompleted
                              ? '$_partialPhq8Sum / 24'
                              : (_legacyGroundTruth != null
                                  ? '${_legacyGroundTruth!.toInt()} / 24'
                                  : '$_completedPhq8ItemsCount / 8 butir'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _effectiveGroundTruthPhq8 != null
                                ? _brandTealDark
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_effectiveGroundTruthPhq8 != null)
                    Text(
                      'Kategori: ${_getRiskDescriptionShort(_groundTruthRiskCategory)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: gtRiskColor,
                      ),
                    )
                  else
                    const Text(
                      'Nilai setiap butir gejala dalam 2 minggu terakhir (0–3). Skor total dihitung otomatis.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Skala: 0 = Tidak pernah • 1 = Beberapa hari • 2 = >½ waktu • 3 = Hampir setiap hari',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._phq8ItemSpecs.map(_buildPhq8ItemCard),
                  const SizedBox(height: 4),
                  // Panduan Kategori Skor (Selaras Cut-off Model 3)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('0–7.9: Minimal',
                            style: TextStyle(
                                fontSize: 10.5, color: _textSecondary)),
                        Text('8.0–9.3: Ringan',
                            style: TextStyle(
                                fontSize: 10.5, color: _textSecondary)),
                        Text('9.4–14.9: Sedang',
                            style: TextStyle(
                                fontSize: 10.5, color: _textSecondary)),
                        Text('15–24: Berat',
                            style: TextStyle(
                                fontSize: 10.5, color: _textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // C. Kualitas Pengamatan Sesi
                  const Text(
                    '3. Kualitas Pengamatan Sesi:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tandai parameter rekaman yang memenuhi standar pemeriksaan:',
                    style: TextStyle(fontSize: 11.5, color: _textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlausibilityToggle(
                        icon: Icons.face_rounded,
                        label: 'Wajah & Mimik Jelas',
                        value: _visualPlausible,
                        onChanged: (v) => setState(() => _visualPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        icon: Icons.mic_rounded,
                        label: 'Suara Terdengar Jernih',
                        value: _audioPlausible,
                        onChanged: (v) => setState(() => _audioPlausible = v),
                      ),
                      _buildPlausibilityToggle(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Percakapan Memadai',
                        value: _textPlausible,
                        onChanged: (v) => setState(() => _textPlausible = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // D. Identitas Validator Ahli (Wajib)
                  const Text(
                    '4. Identitas Validator Ahli (Wajib):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cantumkan nama/inisial dan kompetensi ahli untuk rekam audit penelitian:',
                    style: TextStyle(fontSize: 11.5, color: _textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _validatorNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(fontSize: 13, color: _textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nama Validator *',
                      hintText: 'Contoh: Dr. Rina Sari, M.Psi., Psikolog',
                      hintStyle:
                          const TextStyle(fontSize: 12, color: _textMuted),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _brandTealDark, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _validatorRoles.map((role) {
                      final isSelected = _validatorRole == role;
                      return ChoiceChip(
                        label: Text(role),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _validatorRole = role);
                          }
                        },
                        selectedColor: _softMintBg,
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: BorderSide(
                          color: isSelected
                              ? _brandTealDark
                              : const Color(0xFFE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? _brandTealDark : _textSecondary,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. CARD CATATAN KONSELING (FORMAT SOAP RAMAH PENGGUNA)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                              color: _brandTealDark, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Catatan Konseling',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _softMintBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Standar SOAP',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _brandTealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Catat observasi klinis dan rekomendasi Anda secara mandiri (tidak diisi otomatis agar penilaian tetap objektif):',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                  const SizedBox(height: 16),

                  _buildSoapInputCard(
                    badge: 'S',
                    badgeColor: const Color(0xFF0284C7),
                    title: 'Keluhan Pasien (Subjective)',
                    subtitle:
                        'Keluhan utama, durasi gejala, suasana hati, atau pemicu yang disampaikan klien.',
                    hintText:
                        'Tuliskan keluhan subjektif pasien selama wawancara...',
                    controller: _soapSubjectiveCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildSoapInputCard(
                    badge: 'O',
                    badgeColor: const Color(0xFF0D9488),
                    title: 'Temuan Pengamatan (Objective)',
                    subtitle:
                        'Observasi afek wajah, kontak mata, intonasi/tempo suara, serta catatan terhadap estimasi AI.',
                    hintText:
                        'Tuliskan pengamatan objektif klinisi selama sesi...',
                    controller: _soapObjectiveCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildSoapInputCard(
                    badge: 'A',
                    badgeColor: const Color(0xFF7C3AED),
                    title: 'Kesimpulan Ahli (Assessment)',
                    subtitle:
                        'Formulasi diagnostik / tingkat keparahan gejala berdasarkan wawancara klinis.',
                    hintText:
                        'Tuliskan asesmen klinis dan tingkat risiko menurut ahli...',
                    controller: _soapAssessmentCtrl,
                  ),
                  const SizedBox(height: 12),
                  _buildSoapInputCard(
                    badge: 'P',
                    badgeColor: const Color(0xFFD97706),
                    title: 'Saran & Tindak Lanjut (Plan)',
                    subtitle:
                        'Rencana sesi konseling, psikoterapi (CBT/ACT), edukasi, atau rujukan psikiatri.',
                    hintText:
                        'Tuliskan rencana intervensi atau rujukan lanjutan...',
                    controller: _soapPlanCtrl,
                  ),
                  const SizedBox(height: 14),

                  // Tombol Salin Ringkasan
                  OutlinedButton.icon(
                    onPressed: () => _copySoapResumeToClipboard(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandTealDark,
                      side: const BorderSide(color: Color(0xFFCCFBF1)),
                      backgroundColor: const Color(0xFFF0FDFA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 14),
                    ),
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                    label: const Text(
                      'Salin Ringkasan untuk Laporan / Rujukan',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. TOMBOL SIMPAN KE REKAM MEDIS
            if (isSim)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
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
                      'Sesi Simulasi • Verifikasi Disimpan di Memori Lokal',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (!_canSave) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Wajib dilengkapi sebelum menyimpan: ${_missingRequirementsSummary()}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || !_canSave) ? null : _saveVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTealDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    disabledForegroundColor: const Color(0xFF64748B),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    _isVerified
                        ? Icons.check_circle_outline_rounded
                        : Icons.save_outlined,
                    size: 20,
                  ),
                  label: Text(
                    _isSaving
                        ? 'Menyimpan Verifikasi...'
                        : (_isVerified
                            ? 'Perbarui Verifikasi Rekam Medis'
                            : 'Simpan Verifikasi ke Rekam Medis'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
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

  /// Card Komparasi Hasil AI vs Evaluasi Konselor
  Widget _buildComparisonCard({
    required ScreeningResponse screening,
    required String riskCategory,
    required Color riskColor,
    required Color gtRiskColor,
  }) {
    final gt = _effectiveGroundTruthPhq8;
    final delta = _deviationDelta;
    final sign = (delta != null && delta >= 0) ? '+' : '';
    final isConcordant = delta != null && delta.abs() <= 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.balance_rounded,
                      size: 19,
                      color: _brandTealDark,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Perbandingan Skor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
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
          const SizedBox(height: 14),

          // Dua Card Komparasi Berdampingan
          Row(
            children: [
              // Kolom AI
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasil Analisis AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _modelPhq8.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: riskColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '/ 24',
                            style: TextStyle(
                              fontSize: 11,
                              color: _textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RiskBadge(riskCategory: riskCategory),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Kolom Penilaian Konselor
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softMintBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Evaluasi Anda (Ahli)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brandTealDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (gt != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              gt.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: gtRiskColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '/ 24',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        RiskBadge(riskCategory: _groundTruthRiskCategory),
                      ] else ...[
                        const Text(
                          'Belum dinilai',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Isi 8 butir PHQ-8 ($_completedPhq8ItemsCount/8)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Baris Status Selisih (Tanpa Tombol Samakan Skor)
          Row(
            children: [
              Icon(
                delta == null
                    ? Icons.pending_actions_rounded
                    : (isConcordant
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded),
                size: 15,
                color: delta == null
                    ? _textSecondary
                    : (isConcordant
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  delta != null
                      ? 'Selisih: $sign${delta.toStringAsFixed(1)} poin (${isConcordant ? 'Selaras' : 'Terdapat Selisih'})'
                      : 'Pilih status kesesuaian & lengkapi 8 butir PHQ-8 di bawah.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: delta == null
                        ? _textSecondary
                        : (isConcordant
                            ? const Color(0xFF059669)
                            : const Color(0xFFB45309)),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _missingRequirementsSummary() {
    final missing = <String>[];
    if (_concordanceStatus == null) {
      missing.add('Kesesuaian AI');
    }
    if (_effectiveGroundTruthPhq8 == null) {
      missing.add('8 butir PHQ-8 ($_completedPhq8ItemsCount/8)');
    }
    if (_validatorNameCtrl.text.trim().isEmpty) {
      missing.add('Nama Validator');
    }
    return missing.join(', ');
  }

  Widget _buildPhq8ItemCard(_Phq8ItemSpec spec) {
    final selectedValue = _phq8Items[spec.key];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selectedValue != null
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFFFFBEB).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selectedValue != null
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.desc,
            style: const TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (score) {
              final isSelected = selectedValue == score;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: score < 3 ? 6 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        _phq8Items[spec.key] = score;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? _brandTealDark : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? _brandTealDark
                              : const Color(0xFFCBD5E1),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Chip Pilihan Kesesuaian AI
  Widget _buildConcordancePill({
    required String keyName,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _concordanceStatus == keyName;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _concordanceStatus = keyName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? color : _textMuted,
            ),
            const SizedBox(width: 6),
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

  /// Toggle Kondisi Rekaman Sesi
  Widget _buildPlausibilityToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: value ? _softMintBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? _brandTeal : const Color(0xFFE2E8F0),
            width: value ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: value ? _brandTealDark : _textMuted,
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 14,
              color: value ? _brandTealDark : _textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: value ? FontWeight.w700 : FontWeight.w600,
                color: value ? _brandTealDark : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Input Card Format SOAP yang Ramah Pengguna
  Widget _buildSoapInputCard({
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: _textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 7,
              style: const TextStyle(
                fontSize: 13,
                color: _textPrimary,
                height: 1.45,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
