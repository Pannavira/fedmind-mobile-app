import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bottom Navigation Bar bergaya Clinical Modern & Minimalis
/// Dilengkapi elevated protruding center action button untuk tab "Analisa"
/// sesuai referensi UI/UX modern (floating bulge CTA).
class ClinicalBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingReviewCount;

  static const Color _brandTealDark = Color(0xFF0D9488); // Teal Utama Aplikasi
  static const Color _brandTealLight = Color(0xFF14B8A6); // Teal Aksen Terang
  static const Color _brandTealDeep = Color(0xFF0F766E); // Teal Kedalaman
  static const Color _textMuted = Color(0xFF64748B); // Slate Muted
  static const Color _borderColor = Color(0xFFF1F5F9); // Border halus

  const ClinicalBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingReviewCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 70 + bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. White Navbar Card (Sudut atas melengkung & bayangan lembut)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border(
                  top: BorderSide(color: _borderColor, width: 1.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0E0F172A),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: SizedBox(
                  height: 70,
                  child: Row(
                    children: [
                      // Tab 0: Home
                      _buildNavItem(
                        index: 0,
                        label: 'Home',
                        activeIcon: Icons.home_rounded,
                        inactiveIcon: Icons.home_outlined,
                      ),
                      // Tab 1: Simulasi
                      _buildNavItem(
                        index: 1,
                        label: 'Simulasi',
                        activeIcon: Icons.science_rounded,
                        inactiveIcon: Icons.science_outlined,
                      ),
                      // Tab 2: Ruang kosong untuk tombol Analisa yang menonjol
                      const Expanded(
                        child: SizedBox(),
                      ),
                      // Tab 3: History (dengan badge count jika ada)
                      _buildNavItem(
                        index: 3,
                        label: 'History',
                        activeIcon: Icons.extension_rounded,
                        inactiveIcon: Icons.extension_outlined,
                        badgeCount: pendingReviewCount,
                      ),
                      // Tab 4: Settings
                      _buildNavItem(
                        index: 4,
                        label: 'Settings',
                        activeIcon: Icons.settings_rounded,
                        inactiveIcon: Icons.settings_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Tombol Menonjol di Tengah untuk "Analisa" (Elevated Floating Action Button)
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCenterAnalisaButton(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol utama "Analisa" di tengah yang menonjol ke atas (protruding)
  /// dengan gradient teal serta glow shadow yang elegan (borderless seperti referensi).
  Widget _buildCenterAnalisaButton(BuildContext context) {
    final isSelected = currentIndex == 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(2);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lingkaran menonjol borderless (Floating Bulge Circle)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            width: isSelected ? 54 : 52,
            height: isSelected ? 54 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isSelected
                    ? const [_brandTealDeep, _brandTealDark]
                    : const [_brandTealDark, _brandTealLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _brandTealDark
                      .withValues(alpha: isSelected ? 0.45 : 0.28),
                  blurRadius: isSelected ? 16 : 10,
                  offset: const Offset(0, 5),
                  spreadRadius: isSelected ? 1.5 : 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: isSelected ? 26 : 24,
            ),
          ),
          const SizedBox(height: 4),
          // Label teks "Analisa" yang selaras dengan label tab lainnya
          Text(
            'Analisa',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? _brandTealDark : _textMuted,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Nav item standar untuk tab samping (Home, Simulasi, History, Settings)
  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // M3 Pill Capsule Indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOutCubic,
                    width: isSelected ? 52 : 36,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? _brandTealDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: isSelected ? Colors.white : _textMuted,
                      size: 20,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -3,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? _brandTealDark : _textMuted,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
