import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/clinical_constants.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/datasources/sample_patient_data.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../providers/screening_provider.dart';
import '../../widgets/local_video_player_dialog.dart';
import '../result/screening_result_screen.dart';
import 'clinical_camera_screen.dart';
import 'multimodal_analysis_studio_screen.dart';

class ScreeningFormScreen extends StatefulWidget {
  final int initialSourceOption;
  final bool isTab;

  const ScreeningFormScreen({
    super.key,
    this.initialSourceOption = 0,
    this.isTab = false,
  });

  @override
  State<ScreeningFormScreen> createState() => ScreeningFormScreenState();
}

class ScreeningFormScreenState extends State<ScreeningFormScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _slateDark = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  late final TextEditingController _participantIdController;
  final _counselorNoteController = TextEditingController();
  final _clientTranscriptController = TextEditingController();

  /// 0 = Opsi 1 (Clinical Camera), 1 = Opsi 2 (Unggah Rekaman), 2 = Opsi 3 (Dataset Uji E-DAIC / P600)
  late int _selectedSourceOption;
  String _selectedBenchmarkCase = 'P600';

  // State sumber data pemeriksaan
  Map<String, dynamic>? _selectedPayload;
  String _dataSourceTitle = 'Dataset Standar E-DAIC (Kasus P600) Siap Diuji';
  String _dataSourceSubtitle =
      'Vektor biometrik 75D FACS, 248D COVAREP/Prosodi, dan 768D MentalBERT tervalidasi.';

  // State video lokal & pratinjau modalitas riil di perangkat
  String? _localVideoPath;
  ExtractedMultimodalFeatures? _extractedVideoFeatures;
  MultimodalInspectionData? _liveInspectionPreview;
  bool _isExtractingPreview = false;

  @override
  void initState() {
    super.initState();
    _selectedSourceOption = widget.initialSourceOption.clamp(0, 2);
    _participantIdController = TextEditingController(
      text: _selectedSourceOption == 2 ? 'P600' : 'RM-2026-001',
    );
    _loadP600GoldenCase(preserveParticipantId: _selectedSourceOption != 2);
  }

  @override
  void dispose() {
    _participantIdController.dispose();
    _counselorNoteController.dispose();
    _clientTranscriptController.dispose();
    super.dispose();
  }

  void setSourceOption(int option) {
    if (!mounted) return;
    if (option == 2) {
      _loadP600GoldenCase(preserveParticipantId: false);
    } else {
      setState(() {
        _selectedSourceOption = option.clamp(0, 2);
      });
    }
  }

  Future<void> _loadP600GoldenCase({bool preserveParticipantId = false}) async {
    setState(() {
      _localVideoPath = null;
      _extractedVideoFeatures = null;
      _selectedBenchmarkCase = 'P600';
    });

    final data = await SamplePatientData.loadP600Features();

    if (!mounted) return;
    final pid = preserveParticipantId
        ? _participantIdController.text.trim()
        : (data['participant_id']?.toString() ?? 'P600');
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
      _selectedPayload = data;
      if (!preserveParticipantId) {
        _participantIdController.text = pid;
      }
      _dataSourceTitle = 'Golden Case E-DAIC (ID: P600) • Siap Diuji';
      _dataSourceSubtitle =
          'Dataset referensi terstandarisasi untuk verifikasi konkordansi model & audit Shapley XAI.';
      _liveInspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: pid,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _counselorNoteController.text.trim(),
        clientTranscript: _clientTranscriptController.text.trim(),
      );
    });
  }

  void _generateSyntheticBenchmark({bool simulateNoiseArtifact = false}) {
    final pid = simulateNoiseArtifact ? 'P-NOISE-09' : 'P-SYNTH-04';
    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: simulateNoiseArtifact,
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
      _selectedPayload = data;
      _localVideoPath = null;
      _extractedVideoFeatures = null;
      _selectedBenchmarkCase = simulateNoiseArtifact ? 'ARTIFACT' : 'SYNTH';
      _participantIdController.text = pid;
      _dataSourceTitle = simulateNoiseArtifact
          ? 'Simulasi Kasus Artefak Sensor Akustik ($pid)'
          : 'Simulasi Pasien Sintetis Terkalibrasi ($pid)';
      _dataSourceSubtitle = simulateNoiseArtifact
          ? 'Menguji ketahanan model terhadap penurunan SNR mikrofon & artefak lingkungan.'
          : 'Vektor fitur multimodal sintetis untuk pengujian sensitivitas model.';
      _liveInspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: pid,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _counselorNoteController.text.trim(),
        clientTranscript: _clientTranscriptController.text.trim(),
      );
    });
  }

  Future<void> _openCameraRecording() async {
    setState(() {
      _selectedSourceOption = 0;
    });
    final pid = _participantIdController.text.trim().isEmpty
        ? 'RM-2026-001'
        : _participantIdController.text.trim();

    final recordedVideoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicalCameraScreen(participantId: pid),
      ),
    );

    if (recordedVideoPath != null && mounted) {
      await _processLocalVideo(recordedVideoPath);
    }
  }

  Future<void> _pickVideoFromGallery() async {
    setState(() {
      _selectedSourceOption = 1;
    });
    final pid = _participantIdController.text.trim().isEmpty
        ? 'RM-2026-001'
        : _participantIdController.text.trim();

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (pickedFile == null || !mounted) return;

      final savedPath = await LocalStorageService.saveClinicalVideo(
        sourceFilePath: pickedFile.path,
        participantId: pid,
      );

      await _processLocalVideo(savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat rekaman sesi konseling: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _processLocalVideo(String videoPath) async {
    final sizeMb = await LocalStorageService.getFileSizeInMb(videoPath);
    final pid = _participantIdController.text.trim().isEmpty
        ? 'RM-2026-001'
        : _participantIdController.text.trim();

    setState(() {
      _localVideoPath = videoPath;
      _selectedPayload = null;
      _isExtractingPreview = true;
      _dataSourceTitle =
          'Mengekstrak Biometrik Video Observasi (${sizeMb.toStringAsFixed(1)} MB)...';
      _dataSourceSubtitle =
          'Akuisisi Action Units (FACS), kontur prosodi audio & transkrip teks...';
    });

    try {
      final extracted = await MultimodalExtractorService.extractFromLocalVideo(
        videoPath: videoPath,
        participantId: pid,
        userNote: _counselorNoteController.text.trim(),
        clientTranscript: _clientTranscriptController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _extractedVideoFeatures = extracted;
        _liveInspectionPreview = extracted.inspectionData;
        _isExtractingPreview = false;
        _dataSourceTitle =
            'Rekaman Observasi Tervalidasi (${sizeMb.toStringAsFixed(1)} MB)';
        _dataSourceSubtitle = extracted.extractionSummary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pre-check sensor selesai: ${extracted.facesDetected}/${extracted.framesAnalyzed} frame FACS valid & sinyal prosodi siap.',
          ),
          backgroundColor: _brandTealDark,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtractingPreview = false;
        _dataSourceTitle =
            'Rekaman Sesi Tersimpan (${sizeMb.toStringAsFixed(1)} MB)';
        _dataSourceSubtitle =
            'Tersimpan di penyimpanan klinis lokal • Siap dieksekusi oleh ONNX Runtime.';
      });
    }
  }

  Future<void> _previewCurrentVideo() async {
    if (_localVideoPath == null) return;
    final pid = _participantIdController.text.trim();
    await LocalVideoPlayerDialog.show(
      context,
      videoPath: _localVideoPath!,
      participantId: pid,
    );
  }

  Future<void> _submitScreening({bool openStudioFirst = false}) async {
    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mohon isi ID Klien / Nomor Rekam Medis terlebih dahulu.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_localVideoPath == null && _selectedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih sumber modalitas observasi (Kamera, Unggah Rekaman, atau Dataset Uji).',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    List<double> audioFeat;
    List<double> visualFeat;
    List<double> textFeat;
    MultimodalInspectionData? inspectionData;

    if (_localVideoPath != null) {
      final extracted = _extractedVideoFeatures ??
          await MultimodalExtractorService.extractFromLocalVideo(
            videoPath: _localVideoPath!,
            participantId: participantId,
            userNote: _counselorNoteController.text.trim(),
            clientTranscript: _clientTranscriptController.text.trim(),
            onProgress: (stage, progress) {
              provider.setExtractionProgress(stage, progress);
            },
          );
      audioFeat = extracted.audioFeatures;
      visualFeat = extracted.visualFeatures;
      textFeat = extracted.textFeatures;
      inspectionData = extracted.inspectionData;
      if (mounted) {
        setState(() {
          _extractedVideoFeatures = extracted;
          _liveInspectionPreview = extracted.inspectionData;
          _dataSourceSubtitle = extracted.extractionSummary;
        });
      }
    } else {
      audioFeat = (_selectedPayload!['audio_features'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      visualFeat = (_selectedPayload!['visual_features'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      textFeat = (_selectedPayload!['text_features'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      inspectionData =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: participantId,
        visualFeatures: visualFeat,
        audioFeatures: audioFeat,
        textFeatures: textFeat,
        userNote: _counselorNoteController.text.trim(),
        clientTranscript: _clientTranscriptController.text.trim(),
      );
    }

    final composedNote = _counselorNoteController.text.trim();
    final composedTranscript = _clientTranscriptController.text.trim();
    final isBenchmarkSimulation = _selectedSourceOption == 2;

    final success = await provider.executeLocalOnDeviceScreening(
      participantId: participantId,
      textFeatures: textFeat,
      audioFeatures: audioFeat,
      visualFeatures: visualFeat,
      counselorNote: composedNote,
      transcription: composedTranscript.isNotEmpty ? composedTranscript : null,
      inspectionData: inspectionData,
      sessionType: isBenchmarkSimulation ? 'simulation' : 'clinical',
      isSimulation: isBenchmarkSimulation,
    );

    if (!mounted) return;

    if (success && provider.currentScreening != null) {
      if (openStudioFirst && provider.currentInspectionData != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MultimodalAnalysisStudioScreen(
              result: provider.currentScreening!,
              inspection: provider.currentInspectionData!,
              localVideoPath: _localVideoPath,
              isSimulation: isBenchmarkSimulation,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScreeningResultScreen(
              result: provider.currentScreening!,
              localVideoPath: _localVideoPath,
              inspectionData: provider.currentInspectionData,
              isSimulation: isBenchmarkSimulation,
            ),
          ),
        );
      }
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 5),
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
        bottomNavigationBar:
            widget.isTab ? null : _buildStickyBottomBar(provider),
        body: CustomScrollView(
          slivers: [
            // --- HEADER: SESI PEMERIKSAAN BARU ---
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!widget.isTab)
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
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.biotech_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pemeriksaan Baru',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Observasi multimodal & inferensi model',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.isTab) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: provider.isExecuting
                                    ? null
                                    : () {
                                        setState(() {
                                          _participantIdController.text =
                                              'RM-2026-001';
                                          _counselorNoteController.clear();
                                          _clientTranscriptController.clear();
                                          _selectedSourceOption = 0;
                                          _localVideoPath = null;
                                          _extractedVideoFeatures = null;
                                          _loadP600GoldenCase(
                                            preserveParticipantId: true,
                                          );
                                        });
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Reset',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.memory_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ONNX Edge',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
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

            // --- BODY CONTENT ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. IDENTITAS KLIEN & OBSERVASI AWAL
                  _buildSectionCard(
                    stepNumber: '01',
                    title: 'Identitas Klien & Observasi',
                    subtitle:
                        'Nomor rekam medis klien dan catatan observasi awal',
                    icon: Icons.badge_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ID Klien / Nomor Rekam Medis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _slateDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _participantIdController,
                          enabled: !provider.isExecuting,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _slateDark,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Contoh: RM-2026-001 atau P600',
                            prefixIcon: const Icon(
                              Icons.assignment_ind_outlined,
                              color: _brandTealDark,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Reset ke ID Standar P600',
                              icon: const Icon(
                                Icons.restore_rounded,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                              onPressed: provider.isExecuting
                                  ? null
                                  : () {
                                      setState(() {
                                        _participantIdController.text = 'P600';
                                      });
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Catatan Observasi Awal Konselor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _slateDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _counselorNoteController,
                          maxLines: 3,
                          enabled: !provider.isExecuting,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _slateDark,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Catat observasi perilaku awal, penampilan umum, afek tampak, atau keluhan utama klien (Subjective/Objective awal)...',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '*Tersimpan di lembar rekam medis klinisi (SOAP Subjective).',
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                              title: const Text(
                                'Transkrip Percakapan Klien (Opsional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _brandTealDark,
                                ),
                              ),
                              subtitle: const Text(
                                'Isi jika memiliki transkrip verbatim ucapan klien. Jika kosong, sistem otomatis memproses protokol PHQ-8 standar.',
                                style: TextStyle(fontSize: 11, color: _textSecondary),
                              ),
                              children: [
                                TextField(
                                  controller: _clientTranscriptController,
                                  maxLines: 3,
                                  enabled: !provider.isExecuting,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _slateDark,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Ketik atau tempel transkrip verbatim ujaran klien di sini...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. PILIHAN SUMBER MODALITAS OBSERVASI
                  _buildSectionCard(
                    stepNumber: '02',
                    title: 'Pilihan Sumber Modalitas Observasi',
                    subtitle:
                        'Pilih metode akuisisi sinyal Visual (AUs), Akustik (Prosodi), & Teks',
                    icon: Icons.videocam_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Opsi 1: Rekam Sesi Observasi Kamera & Audio Langsung (Clinical Camera)
                        _buildModalitySourceOptionTile(
                          index: 0,
                          icon: Icons.videocam_rounded,
                          title:
                              'Opsi 1: Rekam Sesi Observasi Kamera & Audio Langsung (Clinical Camera)',
                          subtitle:
                              'Akuisisi real-time 75D Facial Action Units & PCM Audio melalui kamera klinis.',
                          badgeText: 'Live Capture',
                          onTap: provider.isExecuting
                              ? null
                              : _openCameraRecording,
                        ),
                        const SizedBox(height: 10),

                        // Opsi 2: Unggah Rekaman Sesi Konseling (Video/Audio)
                        _buildModalitySourceOptionTile(
                          index: 1,
                          icon: Icons.upload_file_rounded,
                          title:
                              'Opsi 2: Unggah Rekaman Sesi Konseling (Video/Audio)',
                          subtitle:
                              'Impor berkas dokumentasi sesi konseling dari penyimpanan lokal perangkat.',
                          badgeText: 'Local File',
                          onTap: provider.isExecuting
                              ? null
                              : _pickVideoFromGallery,
                        ),
                        const SizedBox(height: 10),

                        // Opsi 3: Evaluasi Dataset Uji Terstandarisasi (Simulasi Kasus E-DAIC / P600)
                        _buildModalitySourceOptionTile(
                          index: 2,
                          icon: Icons.science_rounded,
                          title:
                              'Opsi 3: Evaluasi Dataset Uji Terstandarisasi (Simulasi Kasus E-DAIC / P600)',
                          subtitle:
                              'Kalibrasi & verifikasi model menggunakan kasus uji standar (Golden Case P600).',
                          badgeText: 'Benchmark',
                          onTap: provider.isExecuting
                              ? null
                              : () {
                                  setState(() {
                                    _selectedSourceOption = 2;
                                  });
                                  _loadP600GoldenCase();
                                },
                        ),

                        // Sub-pilihan jika Opsi 3 aktif
                        if (_selectedSourceOption == 2) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pilih Skenario Kasus Uji Terstandarisasi:',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: _slateDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPresetCaseButton(
                                        id: 'P600',
                                        label: 'Golden Case P600',
                                        sub: 'E-DAIC Reference',
                                        isSelected:
                                            _selectedBenchmarkCase == 'P600',
                                        onTap: provider.isExecuting
                                            ? null
                                            : () => _loadP600GoldenCase(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildPresetCaseButton(
                                        id: 'SYNTH',
                                        label: 'Kasus Sintetis',
                                        sub: 'Normal / Mild',
                                        isSelected:
                                            _selectedBenchmarkCase == 'SYNTH',
                                        onTap: provider.isExecuting
                                            ? null
                                            : () => _generateSyntheticBenchmark(
                                                  simulateNoiseArtifact: false,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildPresetCaseButton(
                                        id: 'ARTIFACT',
                                        label: 'Uji Artefak Mic',
                                        sub: 'Low SNR Audio',
                                        isSelected:
                                            _selectedBenchmarkCase == 'ARTIFACT',
                                        onTap: provider.isExecuting
                                            ? null
                                            : () => _generateSyntheticBenchmark(
                                                  simulateNoiseArtifact: true,
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. PRE-CHECK KUALITAS SENSOR
                  _buildSectionCard(
                    stepNumber: '03',
                    title: 'Pre-Check Kualitas Sensor & Integritas Modalitas',
                    subtitle:
                        'Verifikasi kualitas akuisisi frame, pencahayaan wajah, dan rasio sinyal-ke-derau (SNR)',
                    icon: Icons.fact_check_outlined,
                    child: _buildSensorPreCheckPanel(),
                  ),

                  if (provider.isExecuting) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: provider.executionProgress,
                              minHeight: 7,
                              color: _brandTealDark,
                              backgroundColor: const Color(0xFFCCFBF1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            provider.executionStatusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _brandTealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.isTab) ...[
                    const SizedBox(height: 20),
                    _buildInlineActionCard(provider),
                    const SizedBox(height: 90),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineActionCard(ScreeningProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
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
                      'Eksekusi Inferensi On-Device',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    Text(
                      'Model ONNX memproses vektor FACS, Audio, & Teks',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: provider.isExecuting
                  ? null
                  : () => _submitScreening(openStudioFirst: false),
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
                    : Icons.fact_check_rounded,
                size: 20,
              ),
              label: Text(
                provider.isExecuting
                    ? 'Menjalankan Inferensi ONNX...'
                    : 'Jalankan Inferensi On-Device',
                style: const TextStyle(
                  fontSize: 13,
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
                  : () => _submitScreening(openStudioFirst: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _slateDark,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.biotech_rounded, size: 18),
              label: const Text(
                'Pratinjau Studio XAI Terlebih Dahulu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String stepNumber,
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _slateDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5EEAD4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: _brandTealDark, size: 20),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildModalitySourceOptionTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback? onTap,
  }) {
    final isSelected = _selectedSourceOption == index;
    return Material(
      color: isSelected ? const Color(0xFFF0FDFA) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _brandTeal
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : _slateDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
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
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _brandTeal.withValues(alpha: 0.15)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  isSelected ? _brandTealDark : _textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
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
      ),
    );
  }

  Widget _buildPresetCaseButton({
    required String id,
    required String label,
    required String sub,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: isSelected ? _slateDark : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _slateDark : const Color(0xFFCBD5E1),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : _slateDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isSelected
                      ? const Color(0xFF5EEAD4)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorPreCheckPanel() {
    final isVideo = _localVideoPath != null;
    final preview = _liveInspectionPreview;
    final faceRate = preview?.faceDetectionRatePct ?? 94.0;
    final isAudioArtifact = _selectedBenchmarkCase == 'ARTIFACT';
    final snrStatus = isAudioArtifact
        ? 'Artefak Derau (Low SNR)'
        : 'Optimal (SNR > 22 dB)';
    final snrColor = isAudioArtifact
        ? ClinicalConstants.riskBorderline
        : ClinicalConstants.riskLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner Status Sumber Data Aktif
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _brandTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isExtractingPreview
                      ? Icons.sync_rounded
                      : Icons.verified_rounded,
                  color: _brandTealDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dataSourceTitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dataSourceSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isVideo)
                IconButton(
                  onPressed: _previewCurrentVideo,
                  icon: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: _brandTealDark,
                    size: 26,
                  ),
                  tooltip: 'Putar Video Observasi',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 Indikator Pre-Check Kualitas Sensor: Frame, Pencahayaan, Kebisingan
        Row(
          children: [
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Kualitas Frame',
                value: '${faceRate.toStringAsFixed(0)}% Valid',
                sub: 'FACS Tracking',
                icon: Icons.videocam_outlined,
                statusColor: faceRate >= 70
                    ? ClinicalConstants.riskLow
                    : ClinicalConstants.riskBorderline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Pencahayaan',
                value: faceRate >= 75 ? 'Terkalibrasi' : 'Sub-optimal',
                sub: 'Iluminasi Wajah',
                icon: Icons.wb_sunny_outlined,
                statusColor: faceRate >= 75
                    ? ClinicalConstants.riskLow
                    : ClinicalConstants.riskBorderline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Kebisingan (SNR)',
                value: isAudioArtifact ? 'Noise Tinggi' : 'Bersih',
                sub: snrStatus,
                icon: Icons.graphic_eq_rounded,
                statusColor: snrColor,
              ),
            ),
          ],
        ),

        if (preview != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sensors_rounded,
                      size: 15,
                      color: _brandTealDark,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Telemetri Sinyal Pra-Inferensi:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _slateDark,
                        ),
                      ),
                    ),
                    Text(
                      'F0: ${preview.avgPitchHz.toStringAsFixed(0)} Hz • Voiced: ${preview.voicedRatioPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _brandTealDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '• Visual (AUs): ${preview.facialAffectTitle}\n'
                  '• Akustik: ${preview.vocalProsodyTitle}\n'
                  '• Linguistik: "${preview.fullTranscript}"',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF134E4A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSensorMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(ScreeningProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            // Tombol sekunder: Buka Studio Observasi terlebih dahulu
            OutlinedButton.icon(
              onPressed: provider.isExecuting
                  ? null
                  : () => _submitScreening(openStudioFirst: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _slateDark,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.biotech_rounded, size: 18),
              label: const Text(
                'Studio XAI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            // Tombol utama: Jalankan Inferensi & Buka Meja Verifikasi Model
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: provider.isExecuting
                      ? null
                      : () => _submitScreening(openStudioFirst: false),
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
                        : Icons.fact_check_rounded,
                    size: 19,
                  ),
                  label: Text(
                    provider.isExecuting
                        ? 'Menjalankan Inferensi ONNX...'
                        : 'Jalankan Inferensi & Verifikasi Klinis',
                    style: const TextStyle(
                      fontSize: 13,
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
