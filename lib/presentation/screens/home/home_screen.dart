import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/history/screening_history_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/screening_form_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';
import 'package:fedmind_mobile_app/presentation/widgets/server_status_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScreeningProvider>();
      provider.checkServerHealth();
      provider.fetchHistory(limit: 5);
    });
  }

  IconData _getModalityIcon(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return Icons.text_snippet_outlined;
      case 'visual':
        return Icons.face_retouching_natural_rounded;
      case 'audio':
        return Icons.mic_none_rounded;
      default:
        return Icons.hub_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'FED-MIND',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'CLINICAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Asisten AI Konseling Klinis & Multimodal XAI',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 12, color: Color(0xFF059669)),
                SizedBox(width: 4),
                Text(
                  'RAM-Only',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: () async {
          await provider.checkServerHealth();
          await provider.fetchHistory(limit: 5);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO CALL TO ACTION (MULAI SESI KONSELING)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScreeningFormScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.record_voice_over_outlined,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'SESI KONSELING AKTIF',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Skrining Multimodal Baru',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Evaluasi tingkat keparahan depresi berbasis fusi representasi Teks percakapan, Akustik suara, dan Ekspresi wajah dengan Explainable AI (Exact Shapley).',
                            style: TextStyle(
                              color: Color(0xFFCCFBF1),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildHeroModalityTag('Teks', Icons.chat_bubble_outline),
                              const SizedBox(width: 8),
                              _buildHeroModalityTag('Audio', Icons.mic_none_outlined),
                              const SizedBox(width: 8),
                              _buildHeroModalityTag('Visual', Icons.face_outlined),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Mulai Asesmen',
                                  style: TextStyle(
                                    color: Color(0xFF0F766E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
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
              const SizedBox(height: 16),

              // 2. QUICK CLINICAL TELEMETRY CARDS
              Row(
                children: [
                  Expanded(
                    child: _buildTelemetryCard(
                      icon: Icons.assignment_turned_in_outlined,
                      iconColor: const Color(0xFF0F766E),
                      label: 'Total Skrining',
                      value: '${provider.historyItems.length}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTelemetryCard(
                      icon: Icons.auto_graph_rounded,
                      iconColor: const Color(0xFF0284C7),
                      label: 'XAI Koalisi',
                      value: '8 Koalisi',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTelemetryCard(
                      icon: Icons.verified_outlined,
                      iconColor: const Color(0xFF10B981),
                      label: 'Akurasi Baseline',
                      value: '100% Eksak',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. SERVER DIAGNOSTICS & ENKRIPSI
              const ServerStatusCard(),
              const SizedBox(height: 18),

              // 4. RIWAYAT PEMERIKSAAN TERKINI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: Color(0xFF0F766E)),
                      SizedBox(width: 6),
                      Text(
                        'Riwayat Pemeriksaan Terkini',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScreeningHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (provider.isLoadingHistory && provider.historyItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  ),
                )
              else if (provider.historyItems.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.assignment_outlined,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Belum ada skrining yang tercatat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mulai sesi konseling baru untuk mencatat evaluasi pasien.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...provider.historyItems.take(3).map((item) {
                  final riskColor = ClinicalConstants.getRiskColor(item.riskCategory);
                  final dominantMod = item.dominantModality ?? 'visual';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          await provider.loadScreeningDetail(item.screeningId);
                          if (!mounted) return;
                          if (provider.currentScreening != null) {
                            nav.push(
                              MaterialPageRoute(
                                builder: (context) => ScreeningResultScreen(
                                  result: provider.currentScreening!,
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Avatar skor bulat
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: riskColor.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.phq8Score?.toStringAsFixed(1) ?? '?',
                                  style: TextStyle(
                                    color: riskColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.participantId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          _getModalityIcon(dominantMod),
                                          size: 13,
                                          color: const Color(0xFF0F766E),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Dominan: ${dominantMod.toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              RiskBadge(riskCategory: item.riskCategory),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFFCBD5E1),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 18),

              // 5. PANDUAN PROTOKOL KLINIS & XAI UNTUK KONSELOR
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            color: Color(0xFF0F766E),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Protokol Klinis & Integritas AI',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildProtocolTile(
                        icon: Icons.balance_outlined,
                        title: 'Atribusi Eksak Shapley',
                        desc:
                            'Mengurai kontribusi 3 modalitas secara adil melalui 8 koalisi laten (v000 baseline) tanpa bias aproksimasi.',
                      ),
                      const SizedBox(height: 10),
                      _buildProtocolTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Kerahasiaan Medis Pasien',
                        desc:
                            'Representasi tensor hanya berada di memori RAM dan dihapus segera pasca inferensi untuk menjaga privasi sesi konseling.',
                      ),
                      const SizedBox(height: 10),
                      _buildProtocolTile(
                        icon: Icons.checklist_rtl_rounded,
                        title: 'Ambang Stratifikasi PHQ-8 Baku',
                        desc:
                            'Low (<8.0), Borderline (8.0–9.9), Moderate (10.0–14.9), High (>=15.0). Keputusan klinis tetap berada di tangan psikolog.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroModalityTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFCCFBF1)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
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
