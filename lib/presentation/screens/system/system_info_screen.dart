import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/screening_provider.dart';
import '../../widgets/clinical_disclaimer_dialog.dart';
import '../../widgets/runtime_requirements_section.dart';

class SystemInfoScreen extends StatelessWidget {
  const SystemInfoScreen({super.key});

  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          color: _brandTeal,
          onRefresh: () async {
            await provider.checkServerHealth();
            await provider.fetchHistory(limit: 50);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header Teal Gradient
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
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.hub_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Node & Sistem',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Telemetri Federated Learning & CDSS',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Chip Status Node
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: provider.isServerOnline
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFFFDE68A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    provider.isServerOnline
                                        ? 'Edge Node Aktif • Komputasi On-Device Siap'
                                        : 'Menyiapkan Edge Runtime On-Device...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
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
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: Status Node FL & Spesifikasi
                      _buildSectionTitle('Arsitektur Federated Learning'),
                      const SizedBox(height: 8),
                      _buildCard(
                        children: [
                          _buildDetailRow(
                            icon: Icons.memory_rounded,
                            title: 'Model Checkpoint',
                            subtitle: 'FedMind-Multimodal-ONNX v2.4-FL',
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.functions_rounded,
                            title: 'Baseline Shapley E[f(X)]',
                            subtitle: '8.42 poin PHQ-8 (E-DAIC Reference)',
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.layers_outlined,
                            title: 'Dimensi Vektor Fitur',
                            subtitle: 'Visual: 75D FACS • Audio: 248D COVAREP • Teks: 768D MentalBERT',
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow(
                            icon: Icons.security_rounded,
                            title: 'Privasi & Keamanan',
                            subtitle: 'Zero Cloud Media Upload • Inferensi 100% on-device di memori ponsel',
                            highlightColor: const Color(0xFF059669),
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          const RuntimeRequirementsSection(),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECTION 2: Konektivitas & Diagnostik
                      _buildSectionTitle('Diagnostik Jaringan & Server'),
                      const SizedBox(height: 8),
                      _buildCard(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: provider.isServerOnline
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  provider.isServerOnline
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_queue_rounded,
                                  color: provider.isServerOnline
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.isServerOnline
                                          ? 'Server Terhubung'
                                          : 'Mode Mandiri (Offline / On-Device)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      provider.isServerOnline
                                          ? 'Sinkronisasi agregasi bobot global tersedia'
                                          : 'Inferensi tetap dapat berjalan lokal tanpa internet',
                                      style: const TextStyle(
                                        fontSize: 11.5,
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
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: provider.isCheckingHealth
                                  ? null
                                  : () async {
                                      await provider.checkServerHealth();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  provider.isServerOnline
                                                      ? 'Koneksi server normal.'
                                                      : 'Server pusat tidak merespons. Mode On-Device aktif.',
                                                ),
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                      }
                                    },
                              icon: provider.isCheckingHealth
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _brandTealDark,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 18),
                              label: Text(
                                provider.isCheckingHealth
                                    ? 'Memeriksa...'
                                    : 'Periksa Konektivitas Server',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _brandTealDark,
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECTION 3: Pedoman CDSS & Etika Klinis
                      _buildSectionTitle(
                        'Etika & Protokol Keputusan Klinis (CDSS)',
                      ),
                      const SizedBox(height: 8),
                      _buildCard(
                        children: [
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: _brandTealDark,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'FedMind dirancang sebagai Clinical Decision Support System (CDSS) pendamping konselor. Hasil model bukan vonis medis definitif dan wajib diverifikasi oleh tenaga kesehatan (Human-in-the-Loop).',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Kategori Skor PHQ-8 Terstandarisasi:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildPhqScaleRow(
                            '0 – 4',
                            'Minimal / Normal',
                            const Color(0xFF10B981),
                          ),
                          _buildPhqScaleRow(
                            '5 – 9',
                            'Gejala Ringan (Borderline)',
                            const Color(0xFF0284C7),
                          ),
                          _buildPhqScaleRow(
                            '10 – 14',
                            'Depresi Sedang',
                            const Color(0xFFF59E0B),
                          ),
                          _buildPhqScaleRow(
                            '15 – 19',
                            'Sedang - Berat',
                            const Color(0xFFEA580C),
                          ),
                          _buildPhqScaleRow(
                            '20 – 24',
                            'Depresi Berat (Kritis)',
                            const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  ClinicalDisclaimerDialog.show(context),
                              icon: const Icon(
                                Icons.gpp_good_outlined,
                                size: 18,
                              ),
                              label: const Text('Buka Lembar Protokol Lengkap'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandTeal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECTION 4: Ringkasan Penyimpanan Lokal
                      _buildSectionTitle('Penyimpanan Database Lokal (SQLite)'),
                      const SizedBox(height: 8),
                      _buildCard(
                        children: [
                          Row(
                            children: [
                              _buildStatBlock(
                                'Total Sesi',
                                '${provider.historyItems.length}',
                                _textPrimary,
                              ),
                              _buildStatBlock(
                                'Terverifikasi',
                                '${provider.verifiedCasesCount}',
                                const Color(0xFF059669),
                              ),
                              _buildStatBlock(
                                'Perlu Review',
                                '${provider.pendingVerificationCount}',
                                const Color(0xFFD97706),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Semua rekaman hasil skrining dan catatan SOAP tersimpan aman dalam database lokal SQLite di memori aplikasi.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // SECTION 5: Tentang Aplikasi
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'FED-MIND CLINICAL WORKSTATION',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: _textMuted.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Versi 0.0.1+1 (Prototype)',
                              style: TextStyle(fontSize: 11, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: _textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? highlightColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _softMintBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _brandTealDark, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: highlightColor ?? _textSecondary,
                  fontWeight: highlightColor != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhqScaleRow(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              range,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
