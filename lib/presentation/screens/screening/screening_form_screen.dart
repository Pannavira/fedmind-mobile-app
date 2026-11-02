import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/datasources/sample_patient_data.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../providers/screening_provider.dart';
import '../../widgets/local_video_player_dialog.dart';
import 'clinical_camera_screen.dart';
import 'multimodal_analysis_studio_screen.dart';

class ScreeningFormScreen extends StatefulWidget {
  const ScreeningFormScreen({super.key});

  @override
  State<ScreeningFormScreen> createState() => _ScreeningFormScreenState();
}

class _ScreeningFormScreenState extends State<ScreeningFormScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  final _participantIdController = TextEditingController(text: 'P600');
  final _counselorNoteController = TextEditingController();

  String _selectedSessionType = 'Pemeriksaan Awal';
  final List<String> _sessionTypes = [
    'Pemeriksaan Awal',
    'Pemantauan Rutin',
    'Konsultasi Lanjutan',
  ];

  // State sumber data pemeriksaan
  Map<String, dynamic>? _selectedPayload;
  String _dataSourceTitle = 'Contoh Data Standar Siap Digunakan';
  String _dataSourceSubtitle =
      'Anda dapat langsung melihat hasil simulasi atau merekam video baru.';

  // State video lokal & pratinjau modalitas riil di perangkat
  String? _localVideoPath;
  ExtractedMultimodalFeatures? _extractedVideoFeatures;
  MultimodalInspectionData? _liveInspectionPreview;
  bool _isExtractingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadP600GoldenCase();
  }

  @override
  void dispose() {
    _participantIdController.dispose();
    _counselorNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadP600GoldenCase() async {
    setState(() {
      _localVideoPath = null;
      _extractedVideoFeatures = null;
    });

    final data = await SamplePatientData.loadP600Features();

    if (!mounted) return;
    final pid = data['participant_id']?.toString() ?? 'P600';
    final vis = (data['visual_features'] as List).map((e) => (e as num).toDouble()).toList();
    final aud = (data['audio_features'] as List).map((e) => (e as num).toDouble()).toList();
    final txt = (data['text_features'] as List).map((e) => (e as num).toDouble()).toList();

    setState(() {
      _selectedPayload = data;
      _participantIdController.text = pid;
      _dataSourceTitle = 'Data Contoh Standar (P600)';
      _dataSourceSubtitle =
          'Simulasi siap digunakan untuk melihat contoh hasil & kalkulasi AI.';
      _liveInspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: pid,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _counselorNoteController.text.trim(),
      );
    });
  }

  void _generateRandomSynthetic() {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PESERTA_01'
        : _participantIdController.text.trim();

    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: false,
    );

    final vis = (data['visual_features'] as List).map((e) => (e as num).toDouble()).toList();
    final aud = (data['audio_features'] as List).map((e) => (e as num).toDouble()).toList();
    final txt = (data['text_features'] as List).map((e) => (e as num).toDouble()).toList();

    setState(() {
      _selectedPayload = data;
      _localVideoPath = null;
      _extractedVideoFeatures = null;
      _dataSourceTitle = 'Simulasi Kondisi Acak';
      _dataSourceSubtitle =
          'Data simulasi cerita, suara, dan ekspresi wajah siap dianalisis.';
      _liveInspectionPreview =
          MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: pid,
        visualFeatures: vis,
        audioFeatures: aud,
        textFeatures: txt,
        userNote: _counselorNoteController.text.trim(),
      );
    });
  }

  Future<void> _openCameraRecording() async {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PESERTA_01'
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
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PESERTA_01'
        : _participantIdController.text.trim();

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
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
          content: Text('Gagal memuat video dari galeri: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _processLocalVideo(String videoPath) async {
    final sizeMb = await LocalStorageService.getFileSizeInMb(videoPath);
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PESERTA_01'
        : _participantIdController.text.trim();

    setState(() {
      _localVideoPath = videoPath;
      _selectedPayload = null;
      _isExtractingPreview = true;
      _dataSourceTitle =
          'Memindai Wajah, Suara & Transkrip Video (${sizeMb.toStringAsFixed(1)} MB)...';
      _dataSourceSubtitle =
          'Mengekstrak modalitas wajah, gelombang suara & teks secara on-device...';
    });

    try {
      final extracted = await MultimodalExtractorService.extractFromLocalVideo(
        videoPath: videoPath,
        participantId: pid,
        userNote: _counselorNoteController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _extractedVideoFeatures = extracted;
        _liveInspectionPreview = extracted.inspectionData;
        _isExtractingPreview = false;
        _dataSourceTitle =
            'Video Siap Dianalisis (${sizeMb.toStringAsFixed(1)} MB)';
        _dataSourceSubtitle = extracted.extractionSummary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Modalitas video berhasil dipindai: ${extracted.facesDetected}/${extracted.framesAnalyzed} frame wajah & gelombang suara siap!',
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
            'Video Rekaman Tersimpan (${sizeMb.toStringAsFixed(1)} MB)';
        _dataSourceSubtitle =
            'Tersimpan aman di perangkat • Siap dianalisis tanpa internet.';
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

  Future<void> _submitScreening() async {
    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon isi Nama Panggilan atau Kode Peserta terlebih dahulu.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_localVideoPath == null && _selectedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan rekam video atau pilih contoh data terlebih dahulu.',
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
      inspectionData = MultimodalExtractorService.buildInspectionFromSampleFeatures(
        participantId: participantId,
        visualFeatures: visualFeat,
        audioFeatures: audioFeat,
        textFeatures: textFeat,
        userNote: _counselorNoteController.text.trim(),
      );
    }

    final success = await provider.executeLocalOnDeviceScreening(
      participantId: participantId,
      textFeatures: textFeat,
      audioFeatures: audioFeat,
      visualFeatures: visualFeat,
      counselorNote: _counselorNoteController.text.trim(),
      inspectionData: inspectionData,
    );

    if (!mounted) return;

    if (success &&
        provider.currentScreening != null &&
        provider.currentInspectionData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultimodalAnalysisStudioScreen(
            result: provider.currentScreening!,
            inspection: provider.currentInspectionData!,
            localVideoPath: _localVideoPath,
          ),
        ),
      );
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
        backgroundColor: _brandTeal,
        bottomNavigationBar: _buildStickyBottomBar(provider),
        body: CustomScrollView(
          slivers: [
            // --- HEADER BANNER SELARAS DENGAN DASHBOARD ---
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  '100% Offline & Rahasia',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Cek Kondisi Mental',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ikuti 2 langkah mudah berikut dengan tenang. Seluruh rekaman diproses langsung di HP Anda.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- SHEET PUTIH MELENGKUNG ---
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LANGKAH 1: IDENTITAS & CERITA SINGKAT
                    _buildStepCard(
                      stepNumber: '1',
                      title: 'Data Diri & Perasaan Saat Ini',
                      subtitle: 'Bantu kami mengenali sesi pemeriksaan Anda',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nama Panggilan / Kode Peserta',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _participantIdController,
                            enabled: !provider.isExecuting,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Contoh: Budi, Sari, atau P600',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: _brandTealDark,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tujuan Pemeriksaan',
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
                            children: _sessionTypes.map((type) {
                              final isSelected = _selectedSessionType == type;
                              return GestureDetector(
                                onTap: provider.isExecuting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedSessionType = type;
                                        });
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _brandTeal
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? _brandTeal
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : _textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ceritakan Perasaan atau Keluhan Anda (Opsional)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _counselorNoteController,
                            maxLines: 3,
                            enabled: !provider.isExecuting,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: _textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Tulis apa yang sedang Anda rasakan, misalnya sulit tidur, mudah lelah, atau pikiran yang sedang membebani...',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // LANGKAH 2: REKAMAN EKSPRESI & SUARA
                    _buildStepCard(
                      stepNumber: '2',
                      title: 'Rekaman Wajah & Suara',
                      subtitle:
                          'Rekam video singkat (±45 detik) sambil bercerita dengan santai',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tombol Utama Rekam Video (Full-width, menonjol)
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF18B2AC), Color(0xFF0D9488)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _brandTeal.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: provider.isExecuting
                                    ? null
                                    : _openCameraRecording,
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.20,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.videocam_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Mulai Rekam Video',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Buka kamera depan & ikuti panduan cerita',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tombol Pilih dari Galeri
                          OutlinedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _pickVideoFromGallery,
                            icon: const Icon(
                              Icons.video_library_outlined,
                              size: 18,
                            ),
                            label: const Text('Pilih Video dari Galeri HP'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _brandTealDark,
                              side: const BorderSide(
                                color: Color(0xFFCCFBF1),
                                width: 1.4,
                              ),
                              backgroundColor: _softMintBg.withValues(
                                alpha: 0.45,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status Kesiapan Data / Video
                          _buildDataReadinessBox(),
                          const SizedBox(height: 14),

                          // Opsi Simulasi Cepat (Ramah Pengguna)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 15,
                                      color: _textSecondary,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Ingin mencoba tanpa merekam video?',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: _textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDemoPillButton(
                                        label: 'Contoh Standar',
                                        icon: Icons.verified_outlined,
                                        onTap: provider.isExecuting
                                            ? null
                                            : _loadP600GoldenCase,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildDemoPillButton(
                                        label: 'Simulasi Acak',
                                        icon: Icons.shuffle_rounded,
                                        onTap: provider.isExecuting
                                            ? null
                                            : _generateRandomSynthetic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (provider.isExecuting) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _softMintBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF99F6E4)),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: provider.executionProgress,
                                minHeight: 6,
                                color: _brandTealDark,
                                backgroundColor: const Color(0xFFCCFBF1),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              provider.executionStatusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _brandTealDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: _softMintBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _brandTealDark,
                  ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildDataReadinessBox() {
    final isVideo = _localVideoPath != null;
    final preview = _liveInspectionPreview;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isExtractingPreview
                      ? Icons.sync_rounded
                      : Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dataSourceSubtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF047857),
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
                    size: 28,
                  ),
                  tooltip: 'Putar Video',
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isExtractingPreview)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                color: _brandTealDark,
                backgroundColor: Color(0xFFCCFBF1),
              ),
            )
          else if (preview != null) ...[
            // --- PANEL PRATINJAU MODALITAS RIIL LANGSUNG SAAT UPLOAD VIDEO ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1FAE5)),
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
                            Icons.sensors_rounded,
                            size: 15,
                            color: _brandTealDark,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Pratinjau Sinyal Modalitas Terdeteksi:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _softMintBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isVideo ? 'Video Riil' : 'Mode Simulasi',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _brandTealDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 1. Pratinjau Deteksi Wajah
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.face_retouching_natural_rounded,
                        size: 15,
                        color: _brandTealDark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Wajah (${preview.faceDetectionRatePct.toStringAsFixed(0)}% Terdeteksi): ${preview.facialAffectTitle}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Pratinjau Gelombang Suara Mini (Audio Waveform)
                  Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Gelombang Suara (${preview.avgPitchHz.toStringAsFixed(0)} Hz • ${preview.voicedRatioPct.toStringAsFixed(0)}% Bicara):',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: preview.audioWaveformBars.take(32).map((amp) {
                        final isPause = amp < 0.14;
                        return Container(
                          width: 3.5,
                          height: (amp * 22).clamp(3.0, 22.0),
                          decoration: BoxDecoration(
                            color: isPause
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF38BDF8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Pratinjau Transkrip Teks
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.subtitles_rounded,
                        size: 15,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Transkrip: "${preview.fullTranscript}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              Expanded(
                child: _buildAspectReadyChip(
                  label: 'Wajah Terdeteksi',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildAspectReadyChip(
                  label: 'Gelombang Suara',
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildAspectReadyChip(
                  label: 'Transkrip Teks',
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAspectReadyChip({
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: _brandTealDark),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoPillButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _brandTealDark),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _brandTealDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(ScreeningProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: provider.isExecuting ? null : _submitScreening,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: Icon(
              provider.isExecuting
                  ? Icons.hourglass_top_rounded
                  : Icons.analytics_outlined,
              size: 20,
            ),
            label: Text(
              provider.isExecuting
                  ? 'Mengekstrak Modalitas & Menghitung Model AI...'
                  : 'Analisis Modalitas & Lihat Kalkulasi AI',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
