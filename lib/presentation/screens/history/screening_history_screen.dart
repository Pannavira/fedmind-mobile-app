import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/risk_badge.dart';

class ScreeningHistoryScreen extends StatefulWidget {
  final bool isTab;

  const ScreeningHistoryScreen({
    super.key,
    this.isTab = false,
  });

  @override
  State<ScreeningHistoryScreen> createState() => _ScreeningHistoryScreenState();
}

class _ScreeningHistoryScreenState extends State<ScreeningHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedVerificationFilter = 'Semua';
  String _selectedRiskFilter = 'Semua';

  final List<String> _verificationFilterOptions = const [
    'Semua',
    'Perlu Verifikasi',
    'Terverifikasi',
  ];

  final List<String> _riskFilterOptions = const [
    'Semua',
    'High',
    'Moderate',
    'Borderline',
    'Low',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScreeningProvider>().fetchHistory(limit: 100);
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
            inspectionData: provider.currentInspectionData,
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
        automaticallyImplyLeading: !widget.isTab,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Pemeriksaan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Daftar Pasien & Status Verifikasi Model',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => provider.fetchHistory(limit: 100),
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sinkronisasi Arsip Lokal',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0D9488),
        onRefresh: () => provider.fetchHistory(limit: 100),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari ID Pasien atau Nomor Rekam Medis...',
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filter Status Verifikasi
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _verificationFilterOptions.map((filter) {
                        final isSelected =
                            _selectedVerificationFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedVerificationFilter = filter;
                                });
                              }
                            },
                            selectedColor: const Color(0xFF0F172A),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 11.5,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Filter Kategori Risiko
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _riskFilterOptions.map((filter) {
                        final isSelected = _selectedRiskFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Risiko: $filter'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedRiskFilter = filter;
                                });
                              }
                            },
                            selectedColor: const Color(0xFF0D9488)
                                .withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF64748B),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 11.5,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D9488)),
      );
    }

    if (provider.historyItems.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: widget.isTab ? 100 : 20),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Belum ada data pemeriksaan klinis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mulai sesi pemeriksaan baru atau jalankan evaluasi Golden Case P600.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.historyItems.where((item) {
      final matchesQuery = query.isEmpty ||
          item.participantId.toLowerCase().contains(query) ||
          item.screeningId.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_selectedVerificationFilter == 'Perlu Verifikasi' &&
          item.isVerified) {
        return false;
      }
      if (_selectedVerificationFilter == 'Terverifikasi' && !item.isVerified) {
        return false;
      }

      if (_selectedRiskFilter == 'Semua') return true;

      final category = item.riskCategory?.toLowerCase() ?? '';
      return category == _selectedRiskFilter.toLowerCase();
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: widget.isTab ? 100 : 20),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tidak ada sesi yang sesuai filter',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sesuaikan filter status verifikasi atau kategori risiko.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, widget.isTab ? 110 : 20),
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: riskColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score != null ? score.toStringAsFixed(1) : '?',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'PHQ-8',
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: riskColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item.participantId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildVerificationBadge(item),
                          ],
                        ),
                        const SizedBox(height: 4),
                        RiskBadge(
                          riskCategory: item.riskCategory,
                          useFullClinicalLabel: true,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              ClinicalConstants.getModalityIcon(dominantMod),
                              size: 13,
                              color: const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${ClinicalConstants.getModalityCompactName(dominantMod)} • ${_formatDate(item.createdAt)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
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

  Widget _buildVerificationBadge(ScreeningSummaryItem item) {
    final verified = item.isVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verified
            ? const Color(0xFF10B981).withValues(alpha: 0.14)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: verified
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : Icons.pending_actions_rounded,
            size: 11,
            color: verified
                ? const Color(0xFF047857)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Diverifikasi' : 'Belum Terverifikasi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: verified
                  ? const Color(0xFF047857)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
