import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/services/multimodal_extractor_service.dart';
import '../../../data/datasources/sample_patient_data.dart';
import '../../providers/screening_provider.dart';
import '../../widgets/local_video_player_dialog.dart';
import '../result/screening_result_screen.dart';
import 'clinical_camera_screen.dart';

class ScreeningFormScreen extends StatefulWidget {
  const ScreeningFormScreen({super.key});

  @override
  State<ScreeningFormScreen> createState() => _ScreeningFormScreenState();
}

class _ScreeningFormScreenState extends State<ScreeningFormScreen> {
  final _participantIdController = TextEditingController(text: 'P600');
  final _counselorNoteController = TextEditingController();

  String _selectedSessionType = 'Intake Session';
  final List<String> _sessionTypes = [
    'Intake Session',
    'Follow-up Counseling',
    'Referral Evaluation',
  ];

  // Data Fitur & Media State
  Map<String, dynamic>? _selectedPayload;
  String _dataSourceDescription = 'No video or sensor data selected';

  // Local Video State (Cross-Silo Edge Extraction)
  String? _localVideoPath;
  double _localVideoSizeMb = 0.0;

  @override
  void initState() {
    super.initState();
    // Default muat kasus acuan P600 untuk kenyamanan awal
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
      _localVideoSizeMb = 0.0;
    });

    final data = await SamplePatientData.loadP600Features();

    setState(() {
      _selectedPayload = data;
      _participantIdController.text = data['participant_id']?.toString() ?? 'P600';
      _dataSourceDescription =
          'P600 Reference Case (Golden Case: Score ~9.69, Borderline, Visual ~56.8%)';
    });
  }

  void _generateRandomSynthetic() {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PATIENT_01'
        : _participantIdController.text.trim();

    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: false,
    );

    setState(() {
      _selectedPayload = data;
      _localVideoPath = null;
      _localVideoSizeMb = 0.0;
      _dataSourceDescription =
          'Synthetic Multimodal Features (768 Text, 248 Audio, 75 Visual)';
    });
  }

  // --- 1. Front Camera Recording Flow ---
  Future<void> _openCameraRecording() async {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PATIENT_01'
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

  // --- 2. Gallery Video Selection Flow ---
  Future<void> _pickVideoFromGallery() async {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PATIENT_01'
        : _participantIdController.text.trim();

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );

      if (pickedFile == null || !mounted) return;

      // Save picked video to app's private sandbox
      final savedPath = await LocalStorageService.saveClinicalVideo(
        sourceFilePath: pickedFile.path,
        participantId: pid,
      );

      await _processLocalVideo(savedPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick video from gallery: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- 3. Local Video Processing for On-Device Feature Extraction ---
  Future<void> _processLocalVideo(String videoPath) async {
    final sizeMb = await LocalStorageService.getFileSizeInMb(videoPath);

    setState(() {
      _localVideoPath = videoPath;
      _localVideoSizeMb = sizeMb;
      _selectedPayload = null;
      _dataSourceDescription =
          'Patient Session Video (${sizeMb.toStringAsFixed(1)} MB) • Ready for On-Device Edge Extraction';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Video (${sizeMb.toStringAsFixed(1)} MB) loaded successfully. Tap "Run Multimodal Edge AI Screening" below.',
        ),
        backgroundColor: const Color(0xFF0F766E),
        duration: const Duration(seconds: 4),
      ),
    );
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
          content: Text('Participant / Medical Record ID is required!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_localVideoPath == null && _selectedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record a video or load sample reference data first!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // 100% ON-DEVICE INFERENCE (MOBILE EDGE OFFLINE)
    List<double> audioFeat;
    List<double> visualFeat;
    List<double> textFeat;

    if (_localVideoPath != null) {
      // Local multimodal extraction from video
      final extracted = await MultimodalExtractorService.extractFromLocalVideo(
        videoPath: _localVideoPath!,
        participantId: participantId,
      );
      audioFeat = extracted.audioFeatures;
      visualFeat = extracted.visualFeatures;
      textFeat = extracted.textFeatures;
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
    }

    final success = await provider.executeLocalOnDeviceScreening(
      participantId: participantId,
      textFeatures: textFeat,
      audioFeatures: audioFeat,
      visualFeatures: visualFeat,
      counselorNote: _counselorNoteController.text.trim(),
    );

    if (!mounted) return;

    if (success && provider.currentScreening != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScreeningResultScreen(
            result: provider.currentScreening!,
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

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Multimodal Clinical Screening'),
            Text(
              'On-Device Assessment Console (Edge AI)',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. HEADER INFORMASI KLINIS & PRIVASI
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF0F766E),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Absolute Privacy: 100% On-Device Edge AI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Multimodal model inference and Exact Shapley XAI execute autonomously in device memory with zero server dependence. Videos and clinical data never leave this device.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF115E59),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. KARTU DATA PASIEN & SESI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_pin_outlined, color: Color(0xFF0F766E), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Patient Information & Session Context',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _participantIdController,
                      decoration: const InputDecoration(
                        labelText: 'Participant ID / Medical Record Number',
                        hintText: 'E.g., P600, P302, MR-2026-01',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                      enabled: !provider.isExecuting,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Counseling Session Type:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _sessionTypes.map((type) {
                        final isSelected = _selectedSessionType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: provider.isExecuting
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedSessionType = type;
                                    });
                                  }
                                },
                          selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : const Color(0xFF64748B),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFCBD5E1),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _counselorNoteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Counselor Clinical Notes (Optional)',
                        hintText: 'E.g., Subdued affect, delayed verbal response, psychomotor retardation...',
                        prefixIcon: Icon(Icons.edit_note_rounded, size: 22),
                      ),
                      enabled: !provider.isExecuting,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. KARTU AKUISISI DATA SENSOR & VIDEO
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.video_call_rounded, color: Color(0xFF0F766E), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Patient Video & Modality Acquisition',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a video source for the clinical interview session. Feature extraction and inference occur locally on-device.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // Two Primary Action Buttons: Camera & Gallery
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _openCameraRecording,
                            icon: const Icon(Icons.videocam_rounded, size: 18),
                            label: const Text('Record Video', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _pickVideoFromGallery,
                            icon: const Icon(Icons.video_library_rounded, size: 18),
                            label: const Text('From Gallery', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Additional Options: Reference Cases & Synthetic
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _loadP600GoldenCase,
                            icon: const Icon(Icons.verified_outlined, size: 15),
                            label: const Text('P600 Reference Case', style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _generateRandomSynthetic,
                            icon: const Icon(Icons.shuffle_rounded, size: 15),
                            label: const Text('Random Synthetic', style: TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),

                    // Indikator Video Lokal Terpilih
                    if (_localVideoPath != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Patient Session Video Selected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: Color(0xFF065F46),
                                        ),
                                      ),
                                      Text(
                                        'Size: ${_localVideoSizeMb.toStringAsFixed(1)} MB • Ready for On-Device Feature Extraction',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _previewCurrentVideo,
                                  icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF0F766E)),
                                  tooltip: 'Preview Video',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFD1FAE5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.hub_outlined, size: 13, color: Color(0xFF0F766E)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Feature Pipeline: Facial Landmarks (75D) • Acoustic Prosody (248D) • Semantic Embeddings (768D)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF0F766E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _dataSourceDescription,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (_selectedPayload != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Extracted Multimodal Feature Tensors (Loaded in Memory):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalityDimBox(
                              'Text',
                              _selectedPayload!['text_features'],
                              const Color(0xFF2563EB),
                              Icons.chat_bubble_outline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildModalityDimBox(
                              'Audio',
                              _selectedPayload!['audio_features'],
                              const Color(0xFFEC4899),
                              Icons.mic_none_outlined,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildModalityDimBox(
                              'Visual',
                              _selectedPayload!['visual_features'],
                              const Color(0xFF8B5CF6),
                              Icons.face_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. PROGRESS INFERENSI AKTIF
            if (provider.isExecuting) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  children: [
                    const LinearProgressIndicator(
                      color: Color(0xFF0F766E),
                      backgroundColor: Color(0xFFCCFBF1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.executionStatusMessage,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF115E59),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. TOMBOL SUBMIT INFERENSI ON-DEVICE
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: provider.isExecuting ? null : _submitScreening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: Text(
                  provider.isExecuting
                      ? 'Executing On-Device Assessment...'
                      : 'Run Multimodal Edge AI Screening',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildModalityDimBox(
    String name,
    dynamic featureList,
    Color color,
    IconData icon,
  ) {
    final length = (featureList is List) ? featureList.length : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '1 x $length',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
