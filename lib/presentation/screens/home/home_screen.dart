import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/constants/clinical_constants.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/history/screening_history_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/result/screening_result_screen.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/screening_form_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_disclaimer_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  int _selectedGuideTab = 0; // 0: Tahapan Cek, 1: Kenali Hasil
  static bool _hasShownDisclaimer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScreeningProvider>();
      // Inisialisasi model berjalan otomatis di latar belakang tanpa menampilkan istilah teknis ke pengguna
      provider.checkServerHealth();
      provider.fetchHistory(limit: 5);

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

  String _getFriendlyModalityName(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return 'Cerita & Ungkapan';
      case 'visual':
        return 'Ekspresi Wajah';
      case 'audio':
        return 'Intonasi Suara';
      default:
        return 'Kombinasi Lengkap';
    }
  }

  String _getFriendlyRiskLabel(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Kondisi Baik & Stabil';
      case 'borderline':
        return 'Perlu Istirahat & Perhatian';
      case 'moderate':
        return 'Disarankan Konsultasi';
      case 'high':
        return 'Butuh Pendampingan Segera';
      default:
        return 'Menunggu Evaluasi';
    }
  }

  IconData _getModalityIcon(String? modality) {
    switch (modality?.toLowerCase()) {
      case 'text':
        return Icons.chat_bubble_outline_rounded;
      case 'visual':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'audio':
        return Icons.graphic_eq_rounded;
      default:
        return Icons.favorite_border_rounded;
    }
  }

  void _showAboutSheet(BuildContext context) {
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _softMintBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: _brandTealDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Privasi & Kenyamanan Anda',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Aplikasi ini dirancang untuk membantu Anda mengenali kondisi kesehatan emosional secara mandiri, nyaman, dan mudah dipahami.\n\n'
                'Seluruh proses pemeriksaan berlangsung langsung di perangkat Anda sehingga cerita, suara, dan wajah Anda tetap aman dan terjaga kerahasiaannya.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Baca Peringatan & Batasan Klinis'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandTealDark,
                    side: const BorderSide(color: Color(0xFFCCFBF1), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ClinicalDisclaimerDialog.show(context);
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    final filteredHistory = provider.historyItems.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final idMatch = item.participantId.toLowerCase().contains(q);
      final riskMatch =
          _getFriendlyRiskLabel(item.riskCategory).toLowerCase().contains(q);
      final modMatch = _getFriendlyModalityName(item.dominantModality)
          .toLowerCase()
          .contains(q);
      return idMatch || riskMatch || modMatch;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _brandTeal,
        body: RefreshIndicator(
          color: _brandTeal,
          onRefresh: () async {
            await provider.checkServerHealth();
            await provider.fetchHistory(limit: 5);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // --- BAGIAN ATAS (WELCOME BANNER TANPA HEADER APLIKASI) ---
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selamat Datang!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Bagaimana perasaan Anda hari ini?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
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
                                onTap: () => _showAboutSheet(context),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.grid_view_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kenali kondisi kesehatan mental Anda lebih awal dengan tenang, nyaman, dan rahasia.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- SHEET PUTIH MELENGKUNG (GAYA MODERN CLEAN MINIMALIST) ---
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PILL SEARCH BAR MINIMALIS
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
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari riwayat pemeriksaan...',
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
                      const SizedBox(height: 28),

                      // 2. LAYANAN UTAMA (FULL-WIDTH MOBILE-FIRST CTA)
                      const Text(
                        'Layanan Utama',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _brandTeal,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildPrimaryStartCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ScreeningFormScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildHistoryShortcutTile(
                        totalSessions: provider.historyItems.length,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ScreeningHistoryScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // 3. PANDUAN SINGKAT (TOGGLE PILL SEPERTI REFERENSI INFO / BOOKING)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Mengenal Pemeriksaan',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _brandTeal,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSegmentPill(
                                  label: 'Cara Kerja',
                                  isSelected: _selectedGuideTab == 0,
                                  onTap: () =>
                                      setState(() => _selectedGuideTab = 0),
                                ),
                                _buildSegmentPill(
                                  label: 'Arti Hasil',
                                  isSelected: _selectedGuideTab == 1,
                                  onTap: () =>
                                      setState(() => _selectedGuideTab = 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_selectedGuideTab == 0)
                        _buildHowItWorksCard()
                      else
                        _buildScoreGuideCard(),

                      const SizedBox(height: 28),

                      // 4. RIWAYAT PEMERIKSAAN TERAKHIR (GAYA LIST DOCTORS DI REFERENSI)
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Pemeriksaan Terakhir',
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ScreeningHistoryScreen(),
                                  ),
                                );
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

                      if (provider.isLoadingHistory &&
                          provider.historyItems.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(color: _brandTeal),
                          ),
                        )
                      else if (filteredHistory.isEmpty)
                        _buildFriendlyEmptyState(context)
                      else
                        ...filteredHistory.take(3).map((item) {
                          final riskColor =
                              ClinicalConstants.getRiskColor(item.riskCategory);
                          final friendlyRisk =
                              _getFriendlyRiskLabel(item.riskCategory);
                          final friendlyModality =
                              _getFriendlyModalityName(item.dominantModality);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
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
                                    await provider
                                        .loadScreeningDetail(item.screeningId);
                                    if (!mounted) return;
                                    if (provider.currentScreening != null) {
                                      nav.push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ScreeningResultScreen(
                                            result: provider.currentScreening!,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar bulat bersih seperti pada referensi
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: riskColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item.phq8Score
                                                        ?.toStringAsFixed(1) ??
                                                    '-',
                                                style: TextStyle(
                                                  color: riskColor,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'Skor',
                                                style: TextStyle(
                                                  color: riskColor.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                friendlyRisk,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5,
                                                  color: _textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    _getModalityIcon(
                                                      item.dominantModality,
                                                    ),
                                                    size: 13,
                                                    color: _textMuted,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      '${item.participantId} • Fokus: $friendlyModality',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: _textSecondary,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.bookmark_border_rounded,
                                            color: Color(0xFFCBD5E1),
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
            color: _brandTeal.withValues(alpha: 0.30),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 28,
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
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Privasi Terjaga • 100% Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(right: 64),
                      child: Text(
                        'Cek Kondisi Mental',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kenali kondisi perasaan dan emosimu melalui cerita, intonasi suara, serta ekspresi wajah secara nyaman.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x140F172A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Mulai Pemeriksaan Sekarang',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _brandTealDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: _softMintBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: _brandTealDark,
                            ),
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

  Widget _buildHistoryShortcutTile({
    required int totalSessions,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _softMintBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFCCFBF1),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.insert_chart_outlined_rounded,
                    color: _brandTealDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Pemeriksaan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalSessions == 0
                            ? 'Pantau perkembangan hasil pemeriksaan Anda'
                            : '$totalSessions sesi pemeriksaan tersimpan di perangkat',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buka',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _brandTealDark,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: _brandTealDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildStepRow(
            number: '1',
            title: 'Ceritakan Perasaan Anda',
            desc:
                'Ungkapkan apa yang sedang dirasakan secara leluasa dan nyaman.',
            icon: Icons.chat_bubble_outline_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _buildStepRow(
            number: '2',
            title: 'Kenali Nada Suara & Ekspresi',
            desc:
                'Kamera & mikrofon membantu membaca tanda kelelahan emosional secara alami.',
            icon: Icons.sentiment_satisfied_alt_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _buildStepRow(
            number: '3',
            title: 'Dapatkan Saran yang Mudah Dipahami',
            desc:
                'Hasil langsung ditampilkan beserta panduan menjaga kesehatan pikiran Anda.',
            icon: Icons.assignment_turned_in_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _softMintBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: _brandTealDark,
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
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildRiskGuideRow(
            color: ClinicalConstants.riskLowColor,
            title: 'Kondisi Baik (Skor < 8)',
            desc: 'Kondisi emosional stabil. Pertahankan pola hidup sehat.',
          ),
          const SizedBox(height: 10),
          _buildRiskGuideRow(
            color: ClinicalConstants.riskBorderlineColor,
            title: 'Perlu Perhatian (Skor 8 – 9.9)',
            desc: 'Gejala stres ringan. Luangkan waktu istirahat yang cukup.',
          ),
          const SizedBox(height: 10),
          _buildRiskGuideRow(
            color: ClinicalConstants.riskModerateColor,
            title: 'Gejala Sedang (Skor 10 – 14.9)',
            desc: 'Disarankan berbincang dengan konselor atau psikolog.',
          ),
          const SizedBox(height: 10),
          _buildRiskGuideRow(
            color: ClinicalConstants.riskHighColor,
            title: 'Perlu Pendampingan (Skor ≥ 15)',
            desc: 'Sangat dianjurkan mendapat pendampingan profesional segera.',
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGuideRow({
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendlyEmptyState(BuildContext context) {
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
          // Ilustrasi lingkaran lembut terinspirasi layar kiri referensi ("Hello!")
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: _softMintBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              size: 40,
              color: _brandTeal,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Halo! Belum Ada Pemeriksaan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _brandTeal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mulai langkah pertama untuk mengenali kondisi perasaan dan kesehatan mental Anda hari ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandTeal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScreeningFormScreen(),
                ),
              );
            },
            child: const Text(
              'Mulai Sekarang',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
