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
  
  Map<String, dynamic>? _selectedPayload;
  bool _isLoadingFeatures = false;
  String _dataSourceDescription = 'Belum ada data tensor fitur yang dipilih';
  bool _simulateAudioAnomaly = false;

  @override
  void initState() {
    super.initState();
    // Default muat kasus acuan P600 untuk kemudahan pengujian
    _loadP600GoldenCase();
  }

  @override
  void dispose() {
    _participantIdController.dispose();
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
          'Kasus Acuan P600 (Golden Case: Skor ~9.69, Borderline, Visual ~56.8%)';
      _isLoadingFeatures = false;
    });
  }

  void _generateRandomSynthetic() {
    final pid = _participantIdController.text.trim().isEmpty
        ? 'SYNTH_01'
        : _participantIdController.text.trim();

    final data = SamplePatientData.generateSyntheticFeatures(
      participantId: pid,
      simulateAbnormalAudio: _simulateAudioAnomaly,
    );

    setState(() {
      _selectedPayload = data;
      _dataSourceDescription = _simulateAudioAnomaly
          ? 'Fitur Sintetis Acak (Disimulasikan Sinyal Audio Lemah/Anomali)'
          : 'Fitur Sintetis Acak Multimodal Valid (768 teks, 248 audio, 75 visual)';
    });
  }

  Future<void> _submitScreening() async {
    final provider = context.read<ScreeningProvider>();
    final participantId = _participantIdController.text.trim();

    if (participantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Pasien/Partisipan wajib diisi!')),
      );
      return;
    }

    if (_selectedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih atau generate fitur multimodal terlebih dahulu!')),
      );
      return;
    }

    final success = await provider.startAndExecuteScreening(
      participantId: participantId,
      textFeatures: _selectedPayload!['text_features'],
      audioFeatures: _selectedPayload!['audio_features'],
      visualFeatures: _selectedPayload!['visual_features'],
      metadata: {
        'source_app': 'FED-MIND Mobile Client Flutter',
        'device_type': 'Android Pixel 9',
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
        title: const Text('Form Skrining Multimodal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. INFO HEADER
            const Text(
              'Eksekusi Inferensi & Exact XAI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kirim representasi tensor multimodal (Teks, Audio, Visual) ke server federasi untuk inferensi triase depresi klinis.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // 2. INPUT ID PARTISIPAN
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identitas Partisipan / Pasien',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _participantIdController,
                      decoration: const InputDecoration(
                        labelText: 'Participant ID',
                        hintText: 'Misal: P600, P302, PATIENT_01',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      enabled: !provider.isExecuting,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. PILIHAN PRESET DATA TENSOR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sumber Data Tensor Multimodal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dataSourceDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
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
                            icon: const Icon(Icons.verified, size: 16),
                            label: const Text(
                              'P600 Golden Case',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: provider.isExecuting
                                ? null
                                : _generateRandomSynthetic,
                            icon: const Icon(Icons.shuffle, size: 16),
                            label: const Text(
                              'Sintetis Acak',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Checkbox Uji Coba Anomali
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Simulasikan Anomali Sinyal Audio (Poor Quality)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _simulateAudioAnomaly,
                      onChanged: provider.isExecuting
                          ? null
                          : (val) {
                              setState(() {
                                _simulateAudioAnomaly = val ?? false;
                              });
                              if (_selectedPayload != null) {
                                _generateRandomSynthetic();
                              }
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    if (_selectedPayload != null) ...[
                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),
                      _buildTensorDimPill('Teks', _selectedPayload!['text_features']),
                      const SizedBox(height: 4),
                      _buildTensorDimPill('Audio', _selectedPayload!['audio_features']),
                      const SizedBox(height: 4),
                      _buildTensorDimPill('Visual', _selectedPayload!['visual_features']),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. STATUS RUNNING / EKSEKUSI
            if (provider.isExecuting) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      provider.executionStatusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. TOMBOL SUBMIT
            ElevatedButton.icon(
              onPressed: provider.isExecuting ? null : _submitScreening,
              icon: const Icon(Icons.analytics_outlined),
              label: Text(
                provider.isExecuting
                    ? 'Sedang Memproses...'
                    : 'Jalankan Inferensi Multimodal & XAI',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTensorDimPill(String name, dynamic featureList) {
    final length = (featureList is List) ? featureList.length : 'Dim?';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Tensor $name:',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        Text(
          '1 x $length dimensi',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
