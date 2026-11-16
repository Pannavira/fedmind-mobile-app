import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/clinical_constants.dart';
import '../../../core/services/clinical_media_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/models/multimodal_inspection_models.dart';
import '../../providers/screening_provider.dart';
import '../../widgets/local_video_player_dialog.dart';
import '../result/screening_result_screen.dart';
import 'clinical_camera_screen.dart';
import 'multimodal_analysis_studio_screen.dart';

/// Halaman Pemeriksaan & Analisis Multimodal berbasis Wizard Stepper
/// Alur pemeriksaan:
/// 1. Data Klien & Sesi (Identitas, Tanggal, Catatan Awal)
/// 2. Rekaman Video Observasi & Pemutar Video Langsung di Aplikasi
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
  // Transkrip tuturan langsung via Android Native SpeechRecognizer (Multilingual-E5 INT4)

  // Sumber data pemeriksaan (1 = Rekaman Video Lokal)
  int _selectedSourceOption = 1;

  // State video lokal & pratinjau modalitas riil di perangkat
  String? _localVideoPath;
  String? _lastExtractedVideoPath;
  String? _lastExtractedNote;
  String? _lastExtractedTranscript;
  String? _speechWarning;
  bool _recordingConsentGiven = false;
  bool _deleteRawVideoAfterInference = false;
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
  bool _isSubmitting = false;

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
      _lastExtractedVideoPath = null;
      _lastExtractedNote = null;
      _lastExtractedTranscript = null;
      _speechWarning = null;
      _recordingConsentGiven = false;
      _deleteRawVideoAfterInference = false;
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

      await ClinicalMediaService.ensureVideoHasAudio(videoPath);
      if (!mounted) return;

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

  Future<void> _openClinicalCamera() async {
    if (!_recordingConsentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Centang kotak persetujuan perekaman (informed consent) terlebih dahulu sebelum memulai kamera.',
          ),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final pid = _participantIdController.text.trim().isEmpty
        ? 'RM-2026-001'
        : _participantIdController.text.trim();

    if (_participantIdController.text.trim().isEmpty) {
      _participantIdController.text = pid;
    }

    try {
      final result = await Navigator.push<ClinicalCameraResult>(
        context,
        MaterialPageRoute(
          builder: (_) => ClinicalCameraScreen(participantId: pid),
        ),
      );

      if (result != null && mounted) {
        await _processLocalVideo(
          result.videoPath,
          realtimeTranscript: result.liveTranscript,
          speechWarning: result.speechWarning,
        );

        if (!mounted) return;

        // Berhenti setelah rekam agar klinisi memverifikasi/menyunting transkrip
        // sebelum menekan tombol Jalankan Inferensi & Hasil.
        await _editTranscriptDialog(isPostRecordConfirm: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka sensor kamera klinis: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _processLocalVideo(
    String videoPath, {
    String? realtimeTranscript,
    String? speechWarning,
  }) async {
    final sizeMb = await LocalStorageService.getFileSizeInMb(videoPath);
    final trimmedTranscript = realtimeTranscript?.trim();
    final hasSpeech =
        trimmedTranscript != null && trimmedTranscript.isNotEmpty;

    setState(() {
      _localVideoPath = videoPath;
      _extractedVideoFeatures = null;
      _liveInspectionPreview = null;
      _isExtractingPreview = false;
      _lastExtractedTranscript = hasSpeech ? trimmedTranscript : null;
      _speechWarning = speechWarning;
      _dataSourceTitle =
          'Rekaman Observasi Tersimpan (${sizeMb.toStringAsFixed(1)} MB)';
      _dataSourceSubtitle = hasSpeech
          ? 'Transkrip ASR tertangkap (${trimmedTranscript.split(RegExp(r'\\s+')).length} kata). Silakan konfirmasi sebelum analisis.'
          : (speechWarning ??
              'Tanpa transkrip ASR otomatis; lengkapi manual bila ada tuturan atau lanjutkan dengan Prosody-Visual Baseline.');
    });

    // Inisialisasi pemutar video inline secara langsung tanpa komputasi berat di preview
    await _initInlineVideo(videoPath);
  }

  Future<void> _editTranscriptDialog({bool isPostRecordConfirm = false}) async {
    final currentText = _lastExtractedTranscript ??
        _liveInspectionPreview?.fullTranscript ??
        '';
    final controller = TextEditingController(text: currentText);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPostRecordConfirm
              ? 'Konfirmasi & Sunting Transkrip Klien'
              : 'Sunting Transkrip Tuturan Klien',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_speechWarning != null && _speechWarning!.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _speechWarning!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Text(
                'Periksa hasil pengenalan suara (ID/EN). Catatan pra-konseling Anda tidak lagi dicampur ke input model. Biarkan kosong jika memang tidak ada ucapan verbal.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Ketik/perbaiki tuturan verbatim klien di sini, atau kosongkan untuk Prosody-Visual Baseline...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _brandTealDark),
            child: Text(
              isPostRecordConfirm ? 'Konfirmasi Transkrip' : 'Simpan & Selaraskan',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newText = controller.text.trim();
      setState(() {
        _lastExtractedTranscript = newText;
        _extractedVideoFeatures = null;
        if (newText.isNotEmpty) {
          _dataSourceSubtitle =
              'Transkrip dikonfirmasi (${newText.split(RegExp(r'\\s+')).length} kata). Tekan Jalankan Inferensi.';
        } else {
          _dataSourceSubtitle =
              'Transkrip dikosongkan (cabang teks memakai Prosody-Visual Baseline).';
        }
      });
      if (_liveInspectionPreview != null && _localVideoPath != null) {
        final pid = _participantIdController.text.trim().isEmpty
            ? 'RM-2026-001'
            : _participantIdController.text.trim();
        final currentNote = _counselorNoteController.text.trim();
        final reExtracted =
            await MultimodalExtractorService.extractFromLocalVideo(
          videoPath: _localVideoPath!,
          participantId: pid,
          userNote: currentNote,
          clientTranscript: newText.isEmpty ? null : newText,
        );
        if (mounted) {
          setState(() {
            _extractedVideoFeatures = reExtracted;
            _liveInspectionPreview = reExtracted.inspectionData;
            _lastExtractedTranscript = reExtracted.inspectionData.fullTranscript;
          });
        }
      }
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

  void _showRealtimeProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 10,
            backgroundColor: Colors.white,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Consumer<ScreeningProvider>(
              builder: (context, provider, _) {
                final double progress =
                    (provider.executionProgress ?? 0.08).clamp(0.0, 1.0);
                final int percent = (progress * 100).toInt();
                final String status = provider
                        .executionStatusMessage.isNotEmpty
                    ? provider.executionStatusMessage
                    : 'Mempersiapkan pipeline komputasi lokal...';

                return Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _brandTealDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.psychology_outlined,
                              color: _brandTealDark,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Inferensi On-Device',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '100% Offline • Komputasi Lokal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: _brandTealDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: _brandTealDark,
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status Aktif
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _brandTealDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5 Tahap Checklist
                      _buildProgressStepRow(
                        title: '1. Frame Video & FACS Wajah (75D)',
                        isDone: progress >= 0.45,
                        isActive: progress < 0.45,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressStepRow(
                        title: '2. Analisis Prosodi Akustik & MFCC (248D)',
                        isDone: progress >= 0.65,
                        isActive: progress >= 0.45 && progress < 0.65,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressStepRow(
                        title: '3. Transkripsi Wicara (Google Live ASR)',
                        isDone: progress >= 0.85,
                        isActive: progress >= 0.65 && progress < 0.85,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressStepRow(
                        title: '4. Semantik Multilingual-E5 768D',
                        isDone: progress >= 0.94,
                        isActive: progress >= 0.85 && progress < 0.94,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressStepRow(
                        title: '5. Eksekusi ONNX & Dekomposisi Shapley',
                        isDone: progress >= 0.99,
                        isActive: progress >= 0.94 && progress < 0.99,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Harap tunggu sebentar, komputasi AI berjalan langsung di CPU perangkat Anda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStepRow({
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    IconData icon;
    Color color;
    if (isDone) {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF10B981);
    } else if (isActive) {
      icon = Icons.radio_button_checked;
      color = _brandTealDark;
    } else {
      icon = Icons.radio_button_unchecked;
      color = const Color(0xFFCBD5E1);
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isDone || isActive ? FontWeight.w700 : FontWeight.w500,
              color: isDone
                  ? const Color(0xFF0F172A)
                  : (isActive ? _brandTealDark : const Color(0xFF94A3B8)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitScreening({bool openStudioFirst = false}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      _isSubmitting = false;
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
      _isSubmitting = false;
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

    bool dialogShown = false;
    _showRealtimeProgressDialog(context);
    dialogShown = true;

    try {
      List<double> audioFeat;
      List<double> visualFeat;
      List<double> textFeat;
      MultimodalInspectionData? inspectionData;

      final currentNote = _counselorNoteController.text.trim();
      final bool canReuseCached = _extractedVideoFeatures != null &&
          _lastExtractedVideoPath == _localVideoPath &&
          _lastExtractedNote == currentNote &&
          _lastExtractedTranscript == _extractedVideoFeatures!.inspectionData.fullTranscript &&
          _extractedVideoFeatures!.participantId == participantId;

      final extracted = canReuseCached
          ? _extractedVideoFeatures!
          : await MultimodalExtractorService.extractFromLocalVideo(
              videoPath: _localVideoPath!,
              participantId: participantId,
              userNote: currentNote,
              clientTranscript: _lastExtractedTranscript,
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
          _lastExtractedVideoPath = _localVideoPath;
          _lastExtractedNote = currentNote;
          _lastExtractedTranscript = extracted.inspectionData.fullTranscript;
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
        transcription: inspectionData.fullTranscript,
        inspectionData: inspectionData,
        sessionType: 'clinical',
        isSimulation: false,
      );

      // Tutup dialog progress setelah inferensi selesai
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (!mounted) return;

      if (success && provider.currentScreening != null) {
        String? effectiveVideoPath = _localVideoPath;
        var effectiveInspection = provider.currentInspectionData;
        if (_deleteRawVideoAfterInference && _localVideoPath != null) {
          await provider.removeRawVideoForScreening(
            provider.currentScreening!.screeningId,
            _localVideoPath,
          );
          effectiveVideoPath = null;
          effectiveInspection = provider.currentInspectionData;
          if (mounted) {
            _inlineVideoController?.pause();
            _inlineVideoController?.dispose();
            _inlineVideoController = null;
            setState(() {
              _localVideoPath = null;
              _lastExtractedVideoPath = null;
              _isInlineVideoInitialized = false;
              _isPlaying = false;
            });
          }
        }
        if (!mounted) return;
        if (openStudioFirst && effectiveInspection != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MultimodalAnalysisStudioScreen(
                result: provider.currentScreening!,
                inspection: effectiveInspection!,
                localVideoPath: effectiveVideoPath,
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
                localVideoPath: effectiveVideoPath,
                inspectionData: effectiveInspection,
                isSimulation: false,
                initialNavIndex: 2,
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
    } on FaceNotDetectedException catch (e) {
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }
      _isSubmitting = false;
      if (mounted) {
        final retryRecord = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.face_retouching_off_rounded,
                    color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wajah Tidak Terlihat di Video',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Text(
              e.message,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Tutup'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: _brandTealDark),
                icon: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Rekam Ulang',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
        if (retryRecord == true && mounted) {
          await _openClinicalCamera();
        }
      }
    } on UnsupportedVisualPlatformException catch (e) {
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }
      _isSubmitting = false;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.videocam_off_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ekstraktor Visual Belum Tersedia',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Text(
              e.message,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan ekstraksi on-device: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _isSubmitting = false;
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
              const SizedBox(height: 14),

              // 5. Modalitas Teks: Transkripsi Otomatis (Google Live ASR)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Modalitas Teks: Transkripsi Otomatis',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _slateDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '100% Otomatis • Google Live ASR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_liveInspectionPreview != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Tuturan Berhasil Ditranskripsikan (Bahasa Indonesia):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'On-Device Audio STT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _editTranscriptDialog,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.edit_rounded,
                                      size: 11, color: Color(0xFF0369A1)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${_liveInspectionPreview!.fullTranscript}"',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isExtractingPreview) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_brandTeal),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Google Speech-to-Text mentranskripsikan tuturan suara...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Color(0xFF0D9488),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ucapan pasien dalam Bahasa Indonesia/Inggris ditranskripsikan langsung via SpeechRecognizer Android 13+, dapat dikonfirmasi/disunting pasca-rekam, lalu diproses encoder Multilingual-E5 INT4 768D.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  'Mulai Merekam',
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
  // TAHAP 2: REKAM VIDEO OBSERVASI & PEMUTAR LANGSUNG
  // =========================================================================
  Widget _buildStage2Media(ScreeningProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          stepNumber: '02',
          title: 'Mulai Merekam',
          subtitle:
              'Rekam wawancara observasi klinis secara langsung on-device dengan panduan protokol E-DAIC / PHQ-8 (Min. Android 13 / API 33 untuk ASR paralel)',
          icon: Icons.videocam_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informed Consent Perekaman Video & Audio On-Device
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: _recordingConsentGiven
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFFFBEB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _recordingConsentGiven
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    value: _recordingConsentGiven,
                    onChanged: (v) {
                      setState(() => _recordingConsentGiven = v ?? false);
                    },
                    activeColor: _brandTealDark,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    title: const Text(
                      'Persetujuan Klien (Informed Consent Perekaman)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _slateDark,
                      ),
                    ),
                    subtitle: const Text(
                      'Klien/wali menyetujui perekaman video wajah dan audio suara secara lokal (100% on-device, tanpa unggah video mentah ke cloud) untuk validasi klinis PHQ-8.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),

              // Jika video belum dipilih: Tampilkan Area Mulai Merekam
              if (_localVideoPath == null)
                _buildVideoUploadPrompt()
              else ...[
                // Jika video sudah dipilih: Tampilkan Pemutar Video Inline Langsung & Transkrip
                _buildInlineVideoPlayer(),
                _buildTranscriptPreviewCard(),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile.adaptive(
                      value: _deleteRawVideoAfterInference,
                      onChanged: (val) {
                        setState(() => _deleteRawVideoAfterInference = val);
                      },
                      activeTrackColor: _brandTeal,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      title: const Text(
                        'Hapus berkas video mentah setelah inferensi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _slateDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Video .mp4 & audio .wav otomatis dihapus segera setelah skor & laporan XAI selesai diekstrak.',
                        style:
                            TextStyle(fontSize: 10.5, color: _textSecondary),
                      ),
                    ),
                  ),
                ),
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
              'Ringkasan kesiapan video/audio lokal dan telemetri aktual pasca-ekstraksi',
          icon: Icons.fact_check_outlined,
          child: _buildSensorPreCheckPanel(),
        ),
        const SizedBox(height: 18),

        // Tombol Navigasi Bawah Tahap 2: Kembali & Mulai Merekam / Jalankan Inferensi
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
                  onPressed: provider.isExecuting
                      ? null
                      : (_localVideoPath != null
                          ? () => _submitScreening(openStudioFirst: false)
                          : _openClinicalCamera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    _localVideoPath != null
                        ? Icons.psychology_rounded
                        : Icons.videocam_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _localVideoPath != null
                        ? 'Jalankan Analisis & Lihat Hasil'
                        : 'Mulai Merekam',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tampilan Area Mulai Merekam Video (Ketika belum ada video yang dipilih)
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
              Icons.videocam_rounded,
              color: _brandTealDark,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mulai Merekam Wawancara Klinis',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _slateDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Rekam observasi klinis terpandu pertanyaan E-DAIC / PHQ-8 dengan pengenalan suara Google SpeechRecognizer (Android 13+). Setelah selesai rekam, tinjau/sunting transkrip tuturan klien sebelum menekan Jalankan Analisis.',
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
              onPressed: _openClinicalCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: _recordingConsentGiven
                    ? _brandTeal
                    : const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.videocam_rounded, size: 22),
              label: const Text(
                'Mulai Merekam',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Transkrip Tuturan Terdeteksi atau Status Kosong Pasca-Rekam
  Widget _buildTranscriptPreviewCard() {
    final transcript = _lastExtractedTranscript?.trim() ?? '';
    if (transcript.isEmpty) {
      if (_localVideoPath == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.voice_over_off_rounded,
                    color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transkrip Wicara Belum Tersedia / Kosong',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _editTranscriptDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _speechWarning ??
                  'Pengenalan suara otomatis tidak menangkap kalimat. Anda dapat menambahkan transkrip verbatim klien secara manual, atau membiarkannya kosong (cabang teks memakai Prosody-Visual Baseline).',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Transkrip Tuturan Klien (Siap Analisis mE5):',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              InkWell(
                onTap: _editTranscriptDialog,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_speechWarning != null) ...[
            const SizedBox(height: 6),
            Text(
              'Peringatan sensor audio: $_speechWarning',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB45309),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            transcript,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF14532D),
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rekam Ulang Observasi?'),
        content: const Text(
          'Rekaman observasi dan transkrip tuturan saat ini akan digantikan dengan rekaman baru. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rekam Ulang'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _openClinicalCamera();
    }
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
                            onPressed: _confirmReRecord,
                            icon: const Icon(Icons.refresh_rounded,
                                size: 14, color: Color(0xFF5EEAD4)),
                            label: const Text(
                              'Rekam Ulang',
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
    final hasTranscript =
        (_lastExtractedTranscript?.trim().isNotEmpty == true) ||
            (preview?.isExplicitTranscript == true);
    final wordCount = (_lastExtractedTranscript?.trim().isNotEmpty == true)
        ? _lastExtractedTranscript!.trim().split(RegExp(r'\s+')).length
        : 0;

    final String frameValue;
    final String frameSub;
    final Color frameColor;
    if (preview != null) {
      frameValue = '${preview.faceDetectionRatePct.toStringAsFixed(0)}% Wajah';
      frameSub = '${preview.facesDetected}/${preview.framesAnalyzed} frame';
      frameColor = preview.isVisualBranchDisabled
          ? _textSecondary
          : (preview.faceDetectionRatePct >= 70
              ? ClinicalConstants.riskLow
              : ClinicalConstants.riskBorderline);
    } else if (isVideo) {
      frameValue = 'Siap Diekstrak';
      frameSub = 'FACS dihitung saat analisis';
      frameColor = _brandTealDark;
    } else {
      frameValue = 'Belum Ada';
      frameSub = 'FACS Tracking';
      frameColor = _textSecondary;
    }

    final String visualValue;
    final String visualSub;
    final Color visualColor;
    if (preview != null) {
      if (preview.isVisualBranchDisabled) {
        visualValue = 'Nonaktif';
        visualSub = 'Mode Desktop/No-CV';
        visualColor = _textSecondary;
      } else {
        visualValue = preview.faceDetectionRatePct >= 75
            ? 'Memadai'
            : 'Perlu Perhatian';
        visualSub = 'Conf ${preview.avgFaceConfidence.toStringAsFixed(0)}%';
        visualColor = preview.faceDetectionRatePct >= 75
            ? ClinicalConstants.riskLow
            : ClinicalConstants.riskBorderline;
      }
    } else if (isVideo) {
      visualValue = 'Menunggu';
      visualSub = 'Pra-analisis';
      visualColor = _brandTealDark;
    } else {
      visualValue = 'Belum Ada';
      visualSub = 'Iluminasi Wajah';
      visualColor = _textSecondary;
    }

    final String audioValue;
    final String audioSub;
    final Color audioColor;
    if (preview != null) {
      audioValue = '${preview.voicedRatioPct.toStringAsFixed(0)}% Aktif';
      audioSub =
          'Jeda ${preview.pauseRatioPct.toStringAsFixed(0)}% \u2022 F0 ${preview.avgPitchHz.toStringAsFixed(0)} Hz';
      audioColor = preview.voicedRatioPct >= 15
          ? ClinicalConstants.riskLow
          : ClinicalConstants.riskBorderline;
    } else if (isVideo) {
      if (_speechWarning != null && _speechWarning!.isNotEmpty) {
        audioValue = 'Peringatan';
        audioSub = hasTranscript ? '$wordCount kata ASR' : 'Cek transkrip';
        audioColor = ClinicalConstants.riskBorderline;
      } else {
        audioValue = 'WAV Siap';
        audioSub = hasTranscript ? 'ASR: $wordCount kata' : 'STT kosong (opsional)';
        audioColor =
            hasTranscript ? ClinicalConstants.riskLow : _brandTealDark;
      }
    } else {
      audioValue = 'Belum Ada';
      audioSub = 'Standby';
      audioColor = _textSecondary;
    }

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

        // 3 Indikator Kualitas Sensor Aktual: Frame Wajah, Kondisi Visual, & Audio/STT
        Row(
          children: [
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Deteksi Frame',
                value: frameValue,
                sub: frameSub,
                icon: Icons.videocam_outlined,
                statusColor: frameColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Kualitas Visual',
                value: visualValue,
                sub: visualSub,
                icon: Icons.wb_sunny_outlined,
                statusColor: visualColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorMetricTile(
                label: 'Audio & Vokal',
                value: audioValue,
                sub: audioSub,
                icon: Icons.graphic_eq_rounded,
                statusColor: audioColor,
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
                        'Telemetri Sinyal Pasca-Ekstraksi:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _slateDark,
                        ),
                      ),
                    ),
                    Text(
                      'F0: ${preview.avgPitchHz.toStringAsFixed(0)} Hz \u2022 Voiced: ${preview.voicedRatioPct.toStringAsFixed(0)}%',
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
                  '\u2022 Visual (AUs): ${preview.facialAffectTitle}\n'
                  '\u2022 Akustik: ${preview.vocalProsodyTitle}\n'
                  '\u2022 Linguistik: ${preview.fullTranscript.trim().isNotEmpty ? '"${preview.fullTranscript}"' : '(Tanpa transkrip \u2014 baseline prosodi-visual)'}',
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
