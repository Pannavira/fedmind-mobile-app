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
  final TextEditingController _searchController = TextEditingController();
  String _selectedRiskFilter = 'Semua';

  final List<String> _riskFilterOptions = [
    'Semua',
    'Tinggi',
    'Moderat',
    'Borderline',
    'Rendah',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScreeningProvider>().fetchHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riwayat Skrining Pasien'),
            Text(
              'Arsip Sesi Konseling & Keputusan Klinis',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => provider.fetchHistory(),
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Segarkan Riwayat',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: () => provider.fetchHistory(),
        child: Column(
          children: [
            // Search and Filters Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari berdasarkan ID Pasien atau Sesi...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _riskFilterOptions.map((filter) {
                        final isSelected = _selectedRiskFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedRiskFilter = filter;
                                });
                              }
                            },
                            selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11.5,
                            ),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0)),

            // History List
            Expanded(
              child: _buildBody(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ScreeningProvider provider) {
    if (provider.isLoadingHistory && provider.historyItems.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }

    if (provider.historyItems.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Belum ada riwayat skrining',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jalankan skrining sesi konseling baru untuk mencatat riwayat pasien.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Apply Filter & Search
    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.historyItems.where((item) {
      final matchesQuery = query.isEmpty ||
          item.participantId.toLowerCase().contains(query) ||
          item.screeningId.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_selectedRiskFilter == 'Semua') return true;

      final category = item.riskCategory?.toLowerCase() ?? '';
      switch (_selectedRiskFilter) {
        case 'Tinggi':
          return category == 'high';
        case 'Moderat':
          return category == 'moderate';
        case 'Borderline':
          return category == 'borderline';
        case 'Rendah':
          return category == 'low';
        default:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  'Tidak ditemukan data yang sesuai',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Coba ubah kata kunci pencarian atau filter tingkat risiko.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final score = item.phq8Score;
        final riskColor = ClinicalConstants.getRiskColor(item.riskCategory);
        final dominantMod = item.dominantModality ?? 'visual';

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openDetail(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Skor badge bulat
                  Container(
                    width: 48,
                    height: 48,
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
                      score != null ? score.toStringAsFixed(1) : '?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
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
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _getModalityIcon(dominantMod),
                              size: 13,
                              color: const Color(0xFF0F766E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Modalitas: ${dominantMod.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFCBD5E1),
                    size: 20,
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
