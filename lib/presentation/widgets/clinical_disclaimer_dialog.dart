import 'package:flutter/material.dart';

class ClinicalDisclaimerDialog extends StatelessWidget {
  const ClinicalDisclaimerDialog({super.key});

  static const Color _clinicalTeal = Color(0xFF0D9488);
  static const Color _deepSlate = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF334155);

  /// Menampilkan dialog protokol klinis & otorisasi penggunaan CDSS
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClinicalDisclaimerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER WORKSTATION KLINIS
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _deepSlate,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.medical_information_outlined,
                        color: Color(0xFF2DD4BF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Otorisasi Konsol CDSS & Audit Model',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _deepSlate,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'FED-MIND Clinical Decision Support & XAI Workbench',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 14),

                // 2. KONTEN PROTOKOL KLINIS
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 1.1,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Instrumen Pendukung Keputusan Klinis (Human-in-the-Loop)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Estimasi skor PHQ-8 dan atribusi Exact Shapley berfungsi sebagai data objektif pendukung triangulasi asesmen, BUKAN diagnosis psikiatris/psikologis otonom. Penegakan diagnosis dan rencana intervensi tetap menjadi wewenang penuh Psikolog Klinis / Psikiater.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFFB45309),
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildProtocolRow(
                          icon: Icons.fact_check_outlined,
                          title: '1. Triangulasi & Verifikasi Ground Truth',
                          desc:
                              'Klinisi wajib memvalidasi kesesuaian model (Sesuai/Valid, Overestimated, Underestimated, atau Artefak) serta menginput skor PHQ-8 aktual dan catatan SOAP pada setiap sesi.',
                        ),
                        const SizedBox(height: 8),
                        _buildProtocolRow(
                          icon: Icons.hub_outlined,
                          title: '2. Audit Plausibilitas Modalitas (XAI)',
                          desc:
                              'Evaluasi keterwakilan sinyal Modalitas Visual (Facial Action Units / AUs), Modalitas Akustik / Prosodi Audio, dan Modalitas Teks / Linguistik terhadap observasi klinis langsung.',
                        ),
                        const SizedBox(height: 8),
                        _buildProtocolRow(
                          icon: Icons.security_rounded,
                          title: '3. Privasi Node Federated Learning (On-Device)',
                          desc:
                              'Inferensi ONNX Runtime dan penyimpanan basis data rekam medis SQLite berjalan 100% lokal di perangkat konselor (Zero Raw Data Leakage).',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. TOMBOL KONFIRMASI KLINISI
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _clinicalTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text(
                    'Konfirmasi Otorisasi Klinisi & Buka Konsol',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Icon(icon, size: 16, color: _clinicalTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _deepSlate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
