import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/core/services/validation_export_service.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/verification/clinical_verification_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/calibration_benchmark_dialog.dart';
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
            localVideoPath: provider.currentInspectionData?.videoPath,
            inspectionData: provider.currentInspectionData,
            initialNavIndex: 3,
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

  Future<void> _openVerification(ScreeningSummaryItem item) async {
    final provider = context.read<ScreeningProvider>();
    await provider.loadScreeningDetail(item.screeningId);

    if (!mounted) return;

    if (provider.currentScreening != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClinicalVerificationScreen(
            screening: provider.currentScreening!,
            localVideoPath: provider.currentInspectionData?.videoPath,
            inspectionData: provider.currentInspectionData,
            initialNavIndex: 3,
          ),
        ),
      );
      if (mounted) {
        provider.fetchHistory(limit: 100);
      }
    }
  }

  Future<void> _openExportSheet(ScreeningProvider provider) async {
    bool isCsv = true;
    bool includeUnverified = false;
    bool isLoading = true;
    bool isSavingFile = false;
    List<ScreeningResponse> loadedRecords = [];

    Future<void> reloadRecords(StateSetter setModalState) async {
      setModalState(() => isLoading = true);
      final data = await provider.loadVerifiedScreeningsForExport(
        includeUnverified: includeUnverified,
      );
      if (!mounted) return;
      setModalState(() {
        loadedRecords = data;
        isLoading = false;
      });
    }

    bool initialized = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!initialized) {
              initialized = true;
              Future.microtask(() => reloadRecords(setModalState));
            }

            final stats = ValidationExportService.computeMetrics(loadedRecords);
            final exportContent = isCsv
                ? ValidationExportService.buildAnonymizedCsv(loadedRecords)
                : ValidationExportService.buildAnonymizedJson(loadedRecords);
            final ext = isCsv ? 'csv' : 'json';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F7F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.dataset_linked_outlined,
                            color: Color(0xFF0D9488),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ekspor Dataset Validasi Ahli',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Data teranonimisasi tanpa nama pasien, berkas video/audio, atau teks SOAP mentah.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('CSV (Tabel)')),
                            selected: isCsv,
                            onSelected: (v) {
                              if (v) setModalState(() => isCsv = true);
                            },
                            selectedColor: const Color(0xFF0D9488),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCsv
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('JSON (Lengkap)')),
                            selected: !isCsv,
                            onSelected: (v) {
                              if (v) setModalState(() => isCsv = false);
                            },
                            selectedColor: const Color(0xFF0D9488),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: !isCsv
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: const Color(0xFF0D9488),
                      title: const Text(
                        'Sertakan sesi yang belum diverifikasi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      value: includeUnverified,
                      onChanged: isLoading
                          ? null
                          : (val) {
                              includeUnverified = val;
                              reloadRecords(setModalState);
                            },
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              'Baris siap ekspor: ${loadedRecords.length} sesi '
                              '(Terverifikasi: ${stats.verifiedCount}) • '
                              'MAE: ${stats.mae != null ? stats.mae!.toStringAsFixed(2) : '—'} • '
                              'RMSE: ${stats.rmse != null ? stats.rmse!.toStringAsFixed(2) : '—'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isLoading || loadedRecords.isEmpty)
                                ? null
                                : () {
                                    Clipboard.setData(
                                      ClipboardData(text: exportContent),
                                    );
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Data ${ext.toUpperCase()} (${loadedRecords.length} sesi) disalin ke Clipboard.',
                                        ),
                                        backgroundColor:
                                            const Color(0xFF0D9488),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: (isLoading ||
                                    isSavingFile ||
                                    loadedRecords.isEmpty)
                                ? null
                                : () async {
                                    final sheetNavigator =
                                        Navigator.of(sheetCtx);
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    setModalState(() => isSavingFile = true);
                                    try {
                                      final file =
                                          await ValidationExportService
                                              .saveExportToAppDocuments(
                                        content: exportContent,
                                        extension: ext,
                                      );
                                      if (!mounted) return;
                                      sheetNavigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Tersimpan di: ${file.path}',
                                          ),
                                          backgroundColor:
                                              const Color(0xFF0D9488),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      setModalState(() => isSavingFile = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal ekspor: $e'),
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.save_alt_rounded, size: 16),
                            label: Text(
                              isSavingFile ? 'Menyimpan...' : 'Simpan Berkas',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildValidationSummaryBanner(ScreeningProvider provider) {
    final stats = ValidationExportService.computeMetricsFromSummary(
      provider.historyItems,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ringkasan Validasi Ahli',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openExportSheet(provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.ios_share_rounded,
                        size: 13,
                        color: Color(0xFF0D9488),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ekspor CSV/JSON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricTile(
                'Terverifikasi',
                '${stats.verifiedCount}/${stats.totalRecords}',
              ),
              _buildMetricTile(
                'Konkordansi',
                stats.concordanceRatePct != null
                    ? '${stats.concordanceRatePct!.toStringAsFixed(0)}%'
                    : '—',
              ),
              _buildMetricTile(
                'MAE',
                stats.mae != null ? stats.mae!.toStringAsFixed(2) : '—',
              ),
              _buildMetricTile(
                'RMSE',
                stats.rmse != null ? stats.rmse!.toStringAsFixed(2) : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => CalibrationBenchmarkDialog.show(context),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Uji Kalibrasi Riwayat',
          ),
          IconButton(
            onPressed: () => _openExportSheet(provider),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Ekspor Validasi (CSV / JSON)',
          ),
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
            _buildValidationSummaryBanner(provider),
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
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _openVerification(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: verified
              ? const Color(0xFF10B981).withValues(alpha: 0.14)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: verified
                ? const Color(0xFF10B981).withValues(alpha: 0.45)
                : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified
                  ? Icons.verified_rounded
                  : Icons.hourglass_top_rounded,
              size: 11,
              color: verified
                  ? const Color(0xFF047857)
                  : const Color(0xFFD97706),
            ),
            const SizedBox(width: 4),
            Text(
              verified ? 'Terverifikasi' : 'Review',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: verified
                    ? const Color(0xFF047857)
                    : const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
