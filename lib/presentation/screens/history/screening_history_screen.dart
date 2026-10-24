import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

class ScreeningHistoryScreen extends StatefulWidget {
  const ScreeningHistoryScreen({super.key});

  @override
  State<ScreeningHistoryScreen> createState() => _ScreeningHistoryScreenState();
}

class _ScreeningHistoryScreenState extends State<ScreeningHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScreeningProvider>().fetchHistory();
    });
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _openDetail(ScreeningSummaryItem item) async {
    final provider = context.read<ScreeningProvider>();
    await provider.loadScreeningDetail(item.screeningId);

    if (!mounted) return;

    if (provider.currentScreening != null) {
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Skrining Pasien'),
        actions: [
          IconButton(
            onPressed: () => provider.fetchHistory(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Riwayat',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchHistory(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(ScreeningProvider provider) {
    if (provider.isLoadingHistory && provider.historyItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.historyItems.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada riwayat skrining',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jalankan skrining baru untuk melihat riwayat tersimpan.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.historyItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = provider.historyItems[index];
        final score = item.phq8Score;
        final riskColor = ClinicalConstants.getRiskColor(item.riskCategory);

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openDetail(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Skor badge bulat
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      score != null ? score.toStringAsFixed(1) : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info pasien dan waktu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.participantId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            RiskBadge(riskCategory: item.riskCategory),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (item.dominantModality != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Modalitas Dominan: ${item.dominantModality!.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
