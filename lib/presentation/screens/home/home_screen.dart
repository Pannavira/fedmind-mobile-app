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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FED-MIND',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Clinical Multimodal XAI',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.checkServerHealth();
          await provider.fetchHistory(limit: 5);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. STATUS SERVER DIAGNOSTICS
              const ServerStatusCard(),
              const SizedBox(height: 16),

              // 2. HERO CALL TO ACTION (MULAI SKRINING)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScreeningFormScreen(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Skrining Multimodal Baru',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Evaluasi depresi klinis berbasis Teks, Audio, & Visual dengan Explainable AI (Exact Shapley).',
                                  style: TextStyle(
                                    color: Color(0xFFDBEAFE),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 24,
                            child: Icon(
                              Icons.arrow_forward,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. RIWAYAT TERKINI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Pemeriksaan Terkini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScreeningHistoryScreen(),
                        ),
                      );
                    },
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (provider.isLoadingHistory && provider.historyItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (provider.historyItems.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Belum ada skrining yang tercatat.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...provider.historyItems.take(3).map((item) {
                  final riskColor = ClinicalConstants.getRiskColor(item.riskCategory);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: riskColor.withValues(alpha: 0.12),
                          child: Text(
                            item.phq8Score?.toStringAsFixed(1) ?? '?',
                            style: TextStyle(
                              color: riskColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          item.participantId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Modalitas: ${(item.dominantModality ?? "-").toUpperCase()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: RiskBadge(riskCategory: item.riskCategory),
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
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // 4. KARTU FITUR RISET & ARSITEKTUR
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hub_outlined, color: Color(0xFF3B82F6), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Karakteristik Ilmiah Sistem',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPill(
                        'Exact Shapley Modality Attribution',
                        'Komputasi eksak 8 koalisi laten dengan baseline v000 tanpa sampling acak.',
                      ),
                      const SizedBox(height: 8),
                      _buildPill(
                        'Privacy-First Data Retention',
                        'Tensor multimodal hanya diproses di RAM dan tidak pernah disimpan permanen.',
                      ),
                      const SizedBox(height: 8),
                      _buildPill(
                        'Stratifikasi Risiko Presisi',
                        'Ambang klinis PHQ-8: Low (<8), Borderline (8-9.9), Moderate (10-14.9), High (>=15).',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
