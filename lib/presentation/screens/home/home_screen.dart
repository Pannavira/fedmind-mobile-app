import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/history/screening_history_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/verification/clinical_verification_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/screening_form_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_disclaimer_dialog.dart';

class HomeScreen extends StatefulWidget {
  final Function(int tabIndex, {int? formSourceOption})? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _brandTeal = Color(0xFF18B2AC);
  static const Color _brandTealDark = Color(0xFF0D9488);
  static const Color _softMintBg = Color(0xFFE6F7F6);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textMuted = Color(0xFF94A3B8);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex =
      0; // 0: Semua, 1: Perlu Verifikasi, 2: Terverifikasi
  static bool _hasShownDisclaimer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScreeningProvider>();
      provider.checkServerHealth();
      provider.fetchHistory(limit: 50);

      if (!_hasShownDisclaimer && mounted) {
        _hasShownDisclaimer = true;
        ClinicalDisclaimerDialog.show(context);
      }
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

  void _showNodeInfoSheet(BuildContext context, ScreeningProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _softMintBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: _brandTealDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Node Federated Learning & Runtime',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        Text(
                          'Status Komputasi Lokal & Keamanan Privasi',
                          style: TextStyle(
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildTelemetryRow(
                      'Model Checkpoint',
                      'FedMind-Multimodal-ONNX v2.4-FL',
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildTelemetryRow(
                      'Baseline Shapley E[f(X)]',
                      '8.42 poin PHQ-8 (E-DAIC Reference)',
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildTelemetryRow(
                      'Status Komputasi',
                      provider.isServerOnline
                          ? 'ONNX Runtime Siap (On-Device)'
                          : 'Inisialisasi Runtime...',
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildTelemetryRow(
                      'Privasi Pasien',
                      'Penyimpanan SQLite Lokal • Zero Cloud Media Upload',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.gpp_good_outlined, size: 18),
                  label: const Text('Protokol CDSS & Batasan Etika Klinis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandTealDark,
                    side: const BorderSide(
                      color: Color(0xFFCCFBF1),
                      width: 1.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ClinicalDisclaimerDialog.show(context);
                  },
                ),
              ),
              if (widget.onNavigateToTab != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.hub_outlined, size: 17),
                    label: const Text('Buka Halaman Node & Sistem Lengkap'),
                    style: TextButton.styleFrom(
                      foregroundColor: _brandTealDark,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onNavigateToTab!(4);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    final filteredHistory = provider.historyItems.where((item) {
      // 1. Text search
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final idMatch = item.participantId.toLowerCase().contains(q);
        final riskMatch = ClinicalConstants.getRiskLabel(item.riskCategory)
            .toLowerCase()
            .contains(q);
        final modMatch = ClinicalConstants.getModalityClinicalName(
          item.dominantModality,
        ).toLowerCase().contains(q);
        if (!idMatch && !riskMatch && !modMatch) return false;
      }

      // 2. Filter segment
      if (_selectedFilterIndex == 1 && item.isVerified) return false;
      if (_selectedFilterIndex == 2 && !item.isVerified) return false;

      return true;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _brandTeal,
        body: RefreshIndicator(
          color: _brandTeal,
          onRefresh: () async {
            await provider.checkServerHealth();
            await provider.fetchHistory(limit: 50);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // --- HEADER TEAL (BERSIH, MODERN, SESUAI LAST COMMIT) ---
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FEDMIND Prototype 1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sistem Pendukung Keputusan & Verifikasi Model',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _showNodeInfoSheet(context, provider),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Status chip modern & halus
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
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
                                width: 7,
                                height: 7,
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
                                      ? 'Edge Node Siap • ONNX Runtime v2.4 • Komputasi Lokal'
                                      : 'Edge Node Menyiapkan Model Lokal...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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

              // --- SHEET PUTIH MELENGKUNG (MINIMALIS, ELEGAN & NATIVE) ---
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PILL SEARCH BAR
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari ID klien atau kategori risiko...',
                            hintStyle: const TextStyle(
                              color: _textMuted,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFFCBD5E1),
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: _textMuted,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. LAYANAN PEMERIKSAAN (CARD UTAMA TASTE MODERN)
                      const Text(
                        'Layanan Asesmen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _brandTeal,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPrimaryStartCard(
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(2, formSourceOption: 0);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ScreeningFormScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // 3. STATS STRIP RINGKAS (SIMPEL & TIDAK MAKAN TEMPAT)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            _buildCompactMetricItem(
                              label: 'Total Sesi',
                              value: '${provider.historyItems.length}',
                              color: _textPrimary,
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: const Color(0xFFE2E8F0),
                            ),
                            _buildCompactMetricItem(
                              label: 'Perlu Review',
                              value: '${provider.pendingVerificationCount}',
                              color: const Color(0xFFF59E0B),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: const Color(0xFFE2E8F0),
                            ),
                            _buildCompactMetricItem(
                              label: 'Triase Kritis',
                              value: '${provider.urgentTriageCount}',
                              color: const Color(0xFFEF4444),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. ANTREAN PASIEN & FILTER
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Daftar Pasien & Riwayat',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _brandTeal,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (provider.historyItems.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                if (widget.onNavigateToTab != null) {
                                  widget.onNavigateToTab!(3);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ScreeningHistoryScreen(),
                                    ),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _brandTealDark,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Lihat Semua',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filter Segmen Pills
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            _buildFilterPill(
                              label: 'Semua (${provider.historyItems.length})',
                              isSelected: _selectedFilterIndex == 0,
                              onTap: () =>
                                  setState(() => _selectedFilterIndex = 0),
                            ),
                            _buildFilterPill(
                              label:
                                  'Perlu Review (${provider.pendingVerificationCount})',
                              isSelected: _selectedFilterIndex == 1,
                              onTap: () =>
                                  setState(() => _selectedFilterIndex = 1),
                            ),
                            _buildFilterPill(
                              label:
                                  'Terverifikasi (${provider.verifiedCasesCount})',
                              isSelected: _selectedFilterIndex == 2,
                              onTap: () =>
                                  setState(() => _selectedFilterIndex = 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // LIST PASIEN / PEMERIKSAAN
                      if (provider.isLoadingHistory &&
                          provider.historyItems.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: _brandTeal),
                          ),
                        )
                      else if (filteredHistory.isEmpty)
                        _buildCleanEmptyState(
                          context,
                          provider.historyItems.isNotEmpty,
                        )
                      else
                        ...filteredHistory.take(5).map((item) {
                          return _buildPatientSessionCard(
                            context,
                            provider,
                            item,
                          );
                        }),
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

  Widget _buildCompactMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _brandTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _brandTeal.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryStartCard({required VoidCallback onTap}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF18B2AC), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _brandTeal.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -28,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 22,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.video_camera_front_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Asesmen Baru',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Mulai Pemeriksaan Pasien',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 230,
                      child: Text(
                        'Observasi multimodal kamera & audio langsung untuk skrining depresi.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.90),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140F172A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Buka Sesi Pemeriksaan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _brandTealDark,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _brandTealDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSessionCard(
    BuildContext context,
    ScreeningProvider provider,
    dynamic item,
  ) {
    final riskColor = ClinicalConstants.getRiskColor(item.riskCategory);
    final riskLabel = ClinicalConstants.getRiskShortBadge(item.riskCategory);
    final phqScoreText = item.phq8Score != null
        ? item.phq8Score!.toStringAsFixed(1)
        : '-';
    final modalityName = ClinicalConstants.getModalityClinicalName(
      item.dominantModality,
    );
    final isVerified = item.isVerified as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              final nav = Navigator.of(context);
              await provider.loadScreeningDetail(item.screeningId);
              if (!mounted) return;
              if (provider.currentScreening != null) {
                nav.push(
                  MaterialPageRoute(
                    builder: (context) => ScreeningResultScreen(
                      result: provider.currentScreening!,
                      initialNavIndex: 0,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar icon modalitas
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _softMintBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: riskColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        item.participantId.length > 2
                            ? item.participantId.substring(0, 2).toUpperCase()
                            : item.participantId.toUpperCase(),
                        style: const TextStyle(
                          color: _brandTealDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Informasi Pasien & Skor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.participantId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  riskLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: riskColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PHQ-8: $phqScoreText • Dominan: $modalityName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge Verifikasi Konselor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          await provider.loadScreeningDetail(item.screeningId);
                          if (!mounted) return;
                          if (provider.currentScreening != null) {
                            nav.push(
                              MaterialPageRoute(
                                builder: (context) => ClinicalVerificationScreen(
                                  screening: provider.currentScreening!,
                                  inspectionData: provider.currentInspectionData,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVerified
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.check_circle_rounded
                                    : Icons.hourglass_top_rounded,
                                size: 12,
                                color: isVerified
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVerified ? 'Terverifikasi' : 'Review',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isVerified
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanEmptyState(BuildContext context, bool hasOtherItems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _softMintBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 34,
              color: _brandTeal,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasOtherItems
                ? 'Tidak Ada Kasus yang Sesuai Filter'
                : 'Belum Ada Pemeriksaan Pasien',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _brandTeal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasOtherItems
                ? 'Pilih filter status lain untuk menampilkan data klien.'
                : 'Mulai sesi intake observasi pasien atau jalankan uji data kasus standar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              if (widget.onNavigateToTab != null) {
                widget.onNavigateToTab!(2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScreeningFormScreen(),
                  ),
                );
              }
            },
            child: const Text(
              'Mulai Sesi Baru',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
