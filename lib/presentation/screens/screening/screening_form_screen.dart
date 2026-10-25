import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/sample_patient_data.dart';
import '../../providers/screening_provider.dart';
import '../result/screening_result_screen.dart';

class ScreeningFormScreen extends StatefulWidget {
  const ScreeningFormScreen({super.key});

  @override
  State<ScreeningFormScreen> createState() => _ScreeningFormScreenState();
}

class _ScreeningFormScreenState extends State<ScreeningFormScreen> {
  final _participantIdController = TextEditingController(text: 'P600');
  final _counselorNoteController = TextEditingController();
  
  String _selectedSessionType = 'Sesi Intake (Awal)';
  final List<String> _sessionTypes = [
    'Sesi Intake (Awal)',
    'Konseling Lanjutan',
    'Evaluasi Rujukan',
  ];

  Map<String, dynamic>? _selectedPayload;
  bool _isLoadingFeatures = false;
  String _dataSourceDescription = 'Belum ada data tensor fitur yang dipilih';
  bool _simulateAudioAnomaly = false;

  @override
  void initState() {
    super.initState();
    // Default muat kasus acuan P600 untuk kemudahan pengujian klinis
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
      _isLoadingFeatures = true;
    });

    final data = await SamplePatientData.loadP600Features();

    setState(() {
      _selectedPayload = data;
      _participantIdController.text = data['participant_id']?.toString() ?? 'P600';
      _dataSourceDescription =
          'Kasus Klinis Acuan P600 (Golden Case: Skor ~9.69, Borderline, Visual ~56.8%)';
      _isLoadingFeatures = false;
    });
  }

  void _generateRandomSynthetic() {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'PASIEN_01'
        : _participantIdController.text.trim();

    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: _simulateAudioAnomaly,
    );

    setState(() {
      _selectedPayload = data;
      _dataSourceDescription = _simulateAudioAnomaly
          ? 'Fitur Multimodal Sintetis (Disimulasikan Sinyal Audio Lemah / Anomali)'
          : 'Fitur Multimodal Sintetis Valid (768 Teks, 248 Audio, 75 Visual)';
    });
  }

  Future<void> _submitScreening() async {
    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID Rekam Medis / Partisipan wajib diisi!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih atau siapkan data tensor multimodal sesi terlebih dahulu!'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final success = await provider.startAndExecuteScreening(
      participantId: participantId,
      textFeatures: _selectedPayload!['text_features'],
      audioFeatures: _selectedPayload!['audio_features'],
      visualFeatures: _selectedPayload!['visual_features'],
      metadata: {
        'source_app': 'FED-MIND Mobile Clinical Flutter',
        'session_type': _selectedSessionType,
        'counselor_note': _counselorNoteController.text.trim(),
        'dataset_case': _dataSourceDescription,
      },
    );

    if (!mounted) return;

    if (success && provider.currentScreening != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScreeningResultScreen(
            result: provider.currentScreening!,
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
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
            Text('Form Skrining Multimodal'),
            Text(
              'Konsol Asesmen & Triase Sesi Konseling',
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
            // 1. HEADER INFORMASI KLINIS
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA), // Teal 50
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
                      Icons.medical_services_outlined,
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
                          'Instrumen Pendukung Keputusan Klinis',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Mengintegrasikan analisis wicara, akustik nada, dan mikro-ekspresi untuk menghitung skor PHQ-8 dan atribusi Exact Shapley.',
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
                          'Data Pasien & Konteks Sesi',
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
                        labelText: 'ID Partisipan / Nomor Rekam Medis',
                        hintText: 'Misal: P600, P302, RM-2026-01',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                      ),
                      enabled: !provider.isExecuting,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tipe Sesi Konseling:',
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
                        labelText: 'Catatan Observasi Konselor (Opsional)',
                        hintText: 'Misal: Pasien tampak afek datar, kontak mata minim...',
                        prefixIcon: Icon(Icons.edit_note_rounded, size: 22),
                      ),
                      enabled: !provider.isExecuting,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. KARTU SENSOR & DATA TENSOR MULTIMODAL
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hub_outlined, color: Color(0xFF0F766E), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Pipa Data Multimodal Sesi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 14),

                    // Tombol Preset
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting || _isLoadingFeatures
                                ? null
                                : _loadP600GoldenCase,
                            icon: const Icon(Icons.verified_outlined, size: 16),
                            label: const Text(
                              'Kasus Acuan P600',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _generateRandomSynthetic,
                            icon: const Icon(Icons.shuffle_rounded, size: 16),
                            label: const Text(
                              'Sintetis Acak',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Material(
                      color: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text(
                          'Simulasi Anomali Audio (Sinyal Lemah)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        subtitle: const Text(
                          'Untuk menguji deteksi Quality Flags validitas mikrofon',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                        value: _simulateAudioAnomaly,
                        activeThumbColor: const Color(0xFF0F766E),
                        onChanged: provider.isExecuting
                            ? null
                            : (val) {
                                setState(() {
                                  _simulateAudioAnomaly = val;
                                });
                                if (_selectedPayload != null) {
                                  _generateRandomSynthetic();
                                }
                              },
                      ),
                    ),

                    if (_selectedPayload != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Representasi Vektor Tensor Aktif:',
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
                              'Teks',
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

            // 5. TOMBOL SUBMIT INFERENSI
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: provider.isExecuting ? null : _submitScreening,
                icon: const Icon(Icons.analytics_rounded, size: 20),
                label: Text(
                  provider.isExecuting
                      ? 'Sedang Memproses Analisis Sesi...'
                      : 'Jalankan Inferensi Multimodal & XAI',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
