import 'package:flutter/material.dart';

class ClinicalDisclaimerDialog extends StatelessWidget {
  const ClinicalDisclaimerDialog({super.key});

  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF475569);

  /// Menampilkan dialog peringatan klinis
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
      canPop: false, // Mengharuskan pengguna menekan tombol persetujuan
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER ICON & JUDUL
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: _softMintBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: _brandTealDark,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pemberitahuan Penting',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Harap dibaca sebelum menggunakan aplikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. KONTEN DENGAN SCROLL AGAR AMAN DI BERBAGAI UKURAN LAYAR
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // KOTAK PERINGATAN UTAMA (Bukan Diagnosa Mutlak)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), // Amber soft 50
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFDE68A), // Amber 200
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bukan Diagnosa Medis Mutlak',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Aplikasi ini dirancang sebagai alat bantu pendukung keputusan (decision support) untuk mengenali kecenderungan kondisi kesehatan mental, bukan sebagai vonis atau diagnosa medis mutlak.',
                                      style: TextStyle(
                                        fontSize: 12,
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
                        const SizedBox(height: 12),

                        // KOTAK KEAMANAN DATA & RUNNING OFFLINE
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4), // Emerald soft 50
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBBF7D0), // Emerald 200
                              width: 1.2,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF059669),
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '100% Berjalan Offline & Data Aman',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Seluruh proses analisis berjalan langsung secara offline di perangkat Anda tanpa membutuhkan koneksi internet. Rekaman suara, video, dan cerita Anda tidak dikirim ke server luar sehingga privasi dan keamanan data Anda terjaga sepenuhnya.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF047857),
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // POIN 1: BAGI PENGGUNA AWAM
                        _buildRoleCard(
                          icon: Icons.person_outline_rounded,
                          roleTitle: 'Untuk Pengguna Umum / Pasien',
                          explanation:
                              'Hasil dan skor evaluasi hanya memberikan gambaran awal mengenai suasana hati Anda. Penegakan diagnosis dan rencana terapi hanya dapat ditentukan oleh psikolog klinis atau psikiater berlisensi.',
                        ),
                        const SizedBox(height: 10),

                        // POIN 2: BAGI TENAGA MEDIS & KONSELOR
                        _buildRoleCard(
                          icon: Icons.medical_services_outlined,
                          roleTitle: 'Untuk Tenaga Medis & Konselor',
                          explanation:
                              'Analisis multimodal (ekspresi wajah, suara, dan teks) berfungsi sebagai instrumen triase data objektif dan tidak menggantikan pertimbangan klinis langsung (clinical judgment).',
                        ),
                        const SizedBox(height: 14),

                        // CATATAN BANTUAN DARURAT
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.support_agent_rounded,
                                color: _brandTealDark,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Butuh pertolongan darurat? Segera hubungi fasilitas kesehatan mental atau IGD terdekat.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textSecondary,
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
                ),
                const SizedBox(height: 18),

                // 3. TOMBOL PERSETUJUAN
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Saya Mengerti & Lanjutkan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

  Widget _buildRoleCard({
    required IconData icon,
    required String roleTitle,
    required String explanation,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _softMintBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _brandTealDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleTitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 11.5,
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

