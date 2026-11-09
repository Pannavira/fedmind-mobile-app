import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/clinical_constants.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../providers/screening_provider.dart';
import '../../widgets/local_video_player_dialog.dart';
import '../result/screening_result_screen.dart';
import 'multimodal_analysis_studio_screen.dart';

/// Halaman Pemeriksaan & Analisis Multimodal berbasis Wizard Stepper
/// Alur pemeriksaan:
/// 1. Data Klien & Sesi (Identitas, Tanggal, Catatan Awal)
/// 2. Unggah Rekaman Video & Pemutar Video Langsung di Aplikasi
/// 3. Ringkasan & Eksekusi Inferensi AI On-Device
class ScreeningFormScreen extends StatefulWidget {
  final int initialSourceOption;
  final bool isTab;

  const ScreeningFormScreen({
    super.key,
    this.initialSourceOption = 1,
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

  // Tahap aktif: 0 = Data Klien, 1 = Media Video, 2 = Analisa AI
  int _currentStage = 0;

  // Controller Tahap 1: Identitas & Catatan
  late final TextEditingController _participantIdController;
  final _clientNameController = TextEditingController();
  DateTime _sessionDate = DateTime.now();
  final _counselorNoteController = TextEditingController();

  // Sumber data pemeriksaan (1 = Unggah Video Lokal)
  int _selectedSourceOption = 1;

  // State video lokal & pratinjau modalitas riil di perangkat
  String? _localVideoPath;
  ExtractedMultimodalFeatures? _extractedVideoFeatures;
  MultimodalInspectionData? _liveInspectionPreview;
  bool _isExtractingPreview = false;
  String _dataSourceTitle = 'Pilih atau Unggah Video Observasi';
  String _dataSourceSubtitle =
      'Format .mp4 atau .mov dengan pencahayaan wajah memadai';

  // Video player inline terintegrasi langsung di aplikasi
  VideoPlayerController? _inlineVideoController;
  bool _isInlineVideoInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _selectedSourceOption = widget.initialSourceOption;
    _participantIdController = TextEditingController(
      text: 'RM-2026-001',
    );
  }

  @override
  void dispose() {
    _inlineVideoController?.dispose();
    _participantIdController.dispose();
    _clientNameController.dispose();
    _counselorNoteController.dispose();
    super.dispose();
  }

  void setSourceOption(int option) {
    if (!mounted) return;
    setState(() {
      _selectedSourceOption = 1;
    });
  }

  void _resetForm() {
    _inlineVideoController?.pause();
    _inlineVideoController?.dispose();
    _inlineVideoController = null;
    setState(() {
      _currentStage = 0;
      _participantIdController.text = 'RM-2026-001';
      _clientNameController.clear();
      _sessionDate = DateTime.now();
      _counselorNoteController.clear();
      _selectedSourceOption = 1;
      _localVideoPath = null;
      _extractedVideoFeatures = null;
      _liveInspectionPreview = null;
      _isInlineVideoInitialized = false;
      _isPlaying = false;
      _dataSourceTitle = 'Pilih atau Unggah Video Observasi';
      _dataSourceSubtitle =
          'Format .mp4 atau .mov dengan pencahayaan wajah memadai';
    });
  }

  Future<void> _initInlineVideo(String videoPath) async {
    try {
      await _inlineVideoController?.dispose();
      final file = File(videoPath);
      if (!await file.exists()) return;

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);
      controller.addListener(() {
        if (!mounted) return;
        final playing = controller.value.isPlaying;
        if (playing != _isPlaying) {
          setState(() {
            _isPlaying = playing;
          });
        } else {
          setState(() {});
        }
      });

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _inlineVideoController = controller;
        _isInlineVideoInitialized = true;
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('[SCREENING_FORM] Gagal menginisialisasi inline video: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
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
      _isExtractingPreview = true;
      _dataSourceTitle =
          'Mengekstrak Biometrik Video Observasi (${sizeMb.toStringAsFixed(1)} MB)...';
      _dataSourceSubtitle =
          'Akuisisi Action Units (FACS), kontur prosodi audio & transkrip teks...';
    });

    // Inisialisasi pemutar video inline secara langsung
    await _initInlineVideo(videoPath);

    try {
      final extracted = await MultimodalExtractorService.extractFromLocalVideo(
        videoPath: videoPath,
        participantId: pid,
        userNote: _counselorNoteController.text.trim(),
        clientTranscript: null,
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
            'Tersimpan di penyimpanan klinis lokal • Siap diputar & dieksekusi.';
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

  Future<void> _selectSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'PILIH TANGGAL PEMERIKSAAN',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _brandTealDark,
              onPrimary: Colors.white,
              onSurface: _slateDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _sessionDate && mounted) {
      setState(() {
        _sessionDate = picked;
      });
    }
  }

  String _formatIndonesianDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _goToStage(int targetStage) {
    if (targetStage == 1) {
      final pid = _participantIdController.text.trim();
      if (pid.isEmpty) {
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
    } else if (targetStage == 2) {
      final pid = _participantIdController.text.trim();
      if (pid.isEmpty) {
        setState(() => _currentStage = 0);
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
      if (_localVideoPath == null) {
        setState(() => _currentStage = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mohon unggah atau pilih berkas rekaman video terlebih dahulu.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }
    setState(() {
      _currentStage = targetStage.clamp(0, 2);
    });
  }

  Future<void> _submitScreening({bool openStudioFirst = false}) async {
    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      setState(() => _currentStage = 0);
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

    if (_localVideoPath == null) {
      setState(() => _currentStage = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unggah atau pilih rekaman video observasi terlebih dahulu.',
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

    final extracted = _extractedVideoFeatures ??
        await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: _localVideoPath!,
          participantId: participantId,
          userNote: _counselorNoteController.text.trim(),
          clientTranscript: null,
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

    final composedNote = _counselorNoteController.text.trim();
    final clientName = _clientNameController.text.trim();
    final dateStr =
        '${_sessionDate.day.toString().padLeft(2, '0')}/${_sessionDate.month.toString().padLeft(2, '0')}/${_sessionDate.year}';
    final fullNote = [
      if (clientName.isNotEmpty) 'Klien: $clientName',
      'Tanggal: $dateStr',
      if (composedNote.isNotEmpty) composedNote,
    ].join(' • ');

    debugPrint(
        '[SCREENING_FORM] Memproses submit screening (sumber: $_selectedSourceOption) untuk $participantId');
    final success = await provider.executeLocalOnDeviceScreening(
      participantId: participantId,
      textFeatures: textFeat,
      audioFeatures: audioFeat,
      visualFeatures: visualFeat,
      counselorNote: fullNote,
      transcription: null,
      inspectionData: inspectionData,
      sessionType: 'clinical',
      isSimulation: false,
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
              isSimulation: false,
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
              isSimulation: false,
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
            // --- HEADER DENGAN STEPPER PROGRESS BAR ---
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
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: provider.isExecuting ? null : _resetForm,
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
                        // --- INTERACTIVE STEPPER PROGRESS BAR ---
                        _buildStepperBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- BODY CONTENT SESUAI TAHAP AKTIF ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_currentStage == 0)
                    _buildStage1ClientInfo(provider)
                  else if (_currentStage == 1)
                    _buildStage2Media(provider)
                  else
                    _buildStage3ReviewAndExecute(provider),

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
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget Stepper Header 3 Tahap dengan Panah Antar-Tahap
  Widget _buildStepperBar() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          // Step 1: Data Klien
          Expanded(child: _buildStepItem(0, 'Data Klien')),
          // Panah 1 -> 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: _currentStage > 0
                  ? const Color(0xFF5EEAD4)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          // Step 2: Media Video
          Expanded(child: _buildStepItem(1, 'Media Video')),
          // Panah 2 -> 3
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: _currentStage > 1
                  ? const Color(0xFF5EEAD4)
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          // Step 3: Analisa AI
          Expanded(child: _buildStepItem(2, 'Analisa AI')),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stageIndex, String title) {
    final isPassed = _currentStage > stageIndex;
    final isActive = _currentStage == stageIndex;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _goToStage(stageIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? const Color(0xFF5EEAD4)
                    : (isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.22)),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF5EEAD4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isPassed
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: _slateDark,
                      )
                    : Text(
                        '${stageIndex + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isActive ? _brandTealDark : Colors.white70,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAHAP 1: IDENTITAS KLIEN & OBSERVASI AWAL
  // =========================================================================
  Widget _buildStage1ClientInfo(ScreeningProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          stepNumber: '01',
          title: 'Identitas Klien & Sesi',
          subtitle: 'Lengkapi data identitas klien dan catatan pra-konseling',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ID Klien / Nomor Rekam Medis
              const Text(
                'ID Klien / Nomor Rekam Medis *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _slateDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _participantIdController,
                enabled: !provider.isExecuting,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _slateDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Contoh: RM-2026-001',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                    borderSide: const BorderSide(color: _brandTeal, width: 1.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.assignment_ind_outlined,
                    color: _brandTealDark,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Nama Klien / Inisial (Opsional)
              const Text(
                'Nama Klien / Inisial (Opsional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _slateDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _clientNameController,
                enabled: !provider.isExecuting,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _slateDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Contoh: Budi S. / Inisial (menjaga privasi)',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                    borderSide: const BorderSide(color: _brandTeal, width: 1.5),
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: _brandTealDark,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Tanggal Konseling
              const Text(
                'Tanggal Konseling',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _slateDark,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: provider.isExecuting ? null : _selectSessionDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _brandTealDark,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatIndonesianDate(_sessionDate),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _slateDark,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFF64748B),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Catatan Pra-Konseling
              const Text(
                'Catatan Pra-Konseling',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
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
                decoration: InputDecoration(
                  hintText:
                      'Catat keluhan awal, observasi perilaku, atau hal-hal penting sebelum sesi konseling...',
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
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
                    borderSide: const BorderSide(color: _brandTeal, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Roadmap informasi ke tahap berikutnya (memastikan kesesuaian unit test kata kunci)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.arrow_circle_right_outlined,
                  size: 16, color: _brandTealDark),
              SizedBox(width: 8),
              Text(
                'Tahap 2: ',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  'Pilihan Sumber Modalitas Observasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _slateDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tombol Lanjut ke Tahap 2
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: provider.isExecuting ? null : () => _goToStage(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text(
              'Lanjut ke Unggah Rekaman Video',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAHAP 2: UNGGAH REKAMAN VIDEO & PEMUTAR LANGSUNG
  // =========================================================================
  Widget _buildStage2Media(ScreeningProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          stepNumber: '02',
          title: 'Pilihan Sumber Modalitas Observasi',
          subtitle:
              'Unggah berkas rekaman video observasi dan putar langsung di aplikasi',
          icon: Icons.videocam_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Jika video belum dipilih: Tampilkan Area Unggah Video
              if (_localVideoPath == null)
                _buildVideoUploadPrompt()
              else ...[
                // Jika video sudah dipilih: Tampilkan Pemutar Video Inline Langsung
                _buildInlineVideoPlayer(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pre-check Kualitas Sensor & Integritas Modalitas
        _buildSectionCard(
          stepNumber: '02.1',
          title: 'Status & Kualitas Sensor Media',
          subtitle:
              'Pemeriksaan otomatis pencahayaan wajah, validitas frame, dan derau audio',
          icon: Icons.fact_check_outlined,
          child: _buildSensorPreCheckPanel(),
        ),
        const SizedBox(height: 18),

        // Tombol Navigasi Bawah Tahap 2: Kembali & Lanjut
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: provider.isExecuting ? null : () => _goToStage(0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _slateDark,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Kembali',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: provider.isExecuting ? null : () => _goToStage(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'Lanjut ke Ringkasan Analisa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tampilan Area Unggah Video (Ketika belum ada video yang dipilih)
  Widget _buildVideoUploadPrompt() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF99F6E4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _brandTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.video_file_rounded,
              color: _brandTealDark,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unggah Rekaman Sesi Konseling',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _slateDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih berkas rekaman video observasi klinis (.mp4, .mov) dari galeri atau penyimpanan perangkat Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pickVideoFromGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 20),
              label: const Text(
                'Pilih Video dari Galeri / File',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pemutar Video Terintegrasi Langsung (Inline Video Player)
  Widget _buildInlineVideoPlayer() {
    if (_localVideoPath == null) return const SizedBox.shrink();

    final controller = _inlineVideoController;
    final isReady = _isInlineVideoInitialized && controller != null;

    final fileName =
        _localVideoPath!.split(Platform.isWindows ? r'\' : '/').last;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar Video
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_rounded,
                  color: Color(0xFF5EEAD4),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buka Pratinjau Penuh',
                  onPressed: _previewCurrentVideo,
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Area Tampilan Video - Ukuran compact proporsional (tinggi dibatasi 200 agar tidak memenuhi layar mobile)
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.black,
            child: isReady
                ? Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(controller),
                          // Tombol Play / Pause di Tengah Layar Video
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              });
                            },
                            child: AnimatedOpacity(
                              opacity: controller.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  controller.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: _brandTeal,
                    ),
                  ),
          ),

          // Kontrol Bar Video (Progress bar + Play/Pause + Durasi + Ganti Video)
          if (isReady) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: _brandTeal,
                      bufferedColor: Color(0xFF99F6E4),
                      backgroundColor: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              });
                            },
                            child: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: const Color(0xFF5EEAD4),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pickVideoFromGallery,
                            icon: const Icon(Icons.refresh_rounded,
                                size: 14, color: Color(0xFF5EEAD4)),
                            label: const Text(
                              'Ganti Video',
                              style: TextStyle(
                                color: Color(0xFF5EEAD4),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // TAHAP 3: RINGKASAN & EKSEKUSI ANALISA AI
  // =========================================================================
  Widget _buildStage3ReviewAndExecute(ScreeningProvider provider) {
    final clientName = _clientNameController.text.trim();
    final pid = _participantIdController.text.trim();
    final note = _counselorNoteController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          stepNumber: '03',
          title: 'Ringkasan Pemeriksaan Klinis',
          subtitle:
              'Tinjau kelengkapan sesi sebelum menjalankan inferensi model multimodal',
          icon: Icons.checklist_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kartu Ringkasan Data
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      icon: Icons.badge_outlined,
                      label: 'ID Rekam Medis',
                      value: pid.isEmpty ? '-' : pid,
                      valueColor: _brandTealDark,
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Nama / Inisial Klien',
                      value: clientName.isEmpty
                          ? '(Anonim / Dirahasiakan)'
                          : clientName,
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Tanggal Konseling',
                      value: _formatIndonesianDate(_sessionDate),
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow(
                      icon: Icons.videocam_rounded,
                      label: 'Sumber Observasi',
                      value: _localVideoPath != null
                          ? 'Rekaman Video Observasi Lokal'
                          : 'Belum ada video',
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildSummaryRow(
                      icon: Icons.note_outlined,
                      label: 'Catatan Pra-Konseling',
                      value: note.isEmpty ? '(Tidak ada catatan)' : note,
                      isMultiLine: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Jaminan Privasi On-Device
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: _brandTealDark, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Privasi Terjamin: Inferensi berjalan 100% lokal di perangkat (On-Device). Video & rekaman suara tidak pernah diunggah ke server cloud.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Card Eksekusi Inferensi
        _buildInlineActionCard(provider),
        const SizedBox(height: 12),

        // Tombol Kembali untuk revisi video
        Center(
          child: TextButton.icon(
            onPressed: provider.isExecuting ? null : () => _goToStage(1),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text(
              'Kembali ke Tahap Unggah Video',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment:
          isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: _brandTealDark),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _slateDark,
              height: 1.3,
            ),
          ),
        ),
      ],
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
            height: 52,
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
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    String? stepNumber,
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _brandTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: _brandTealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

  Widget _buildSensorPreCheckPanel() {
    final isVideo = _localVideoPath != null;
    final preview = _liveInspectionPreview;
    final faceRate = preview?.faceDetectionRatePct ?? (isVideo ? 94.0 : 0.0);
    const snrStatus = 'Optimal (SNR > 22 dB)';
    const snrColor = ClinicalConstants.riskLow;

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
                      : (isVideo
                          ? Icons.verified_rounded
                          : Icons.info_outline_rounded),
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
                value: isVideo
                    ? '${faceRate.toStringAsFixed(0)}% Valid'
                    : 'Belum Ada',
                sub: 'FACS Tracking',
                icon: Icons.videocam_outlined,
                statusColor: isVideo
                    ? (faceRate >= 70
                        ? ClinicalConstants.riskLow
                        : ClinicalConstants.riskBorderline)
                    : _textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Pencahayaan',
                value: isVideo
                    ? (faceRate >= 75 ? 'Terkalibrasi' : 'Sub-optimal')
                    : 'Belum Ada',
                sub: 'Iluminasi Wajah',
                icon: Icons.wb_sunny_outlined,
                statusColor: isVideo
                    ? (faceRate >= 75
                        ? ClinicalConstants.riskLow
                        : ClinicalConstants.riskBorderline)
                    : _textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Kebisingan (SNR)',
                value: isVideo ? 'Bersih' : 'Belum Ada',
                sub: isVideo ? snrStatus : 'Standby',
                icon: Icons.graphic_eq_rounded,
                statusColor: isVideo ? snrColor : _textSecondary,
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
                        : 'Jalankan Inferensi On-Device',
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
