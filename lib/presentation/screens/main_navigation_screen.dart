import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/screening_provider.dart';
import '../widgets/clinical_bottom_nav_bar.dart';
import 'history/screening_history_screen.dart';
import 'home/home_screen.dart';
import 'screening/screening_form_screen.dart';
import 'simulation/simulation_screen.dart';
import 'system/system_info_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  /// Helper untuk berpindah tab dari child widget mana pun dalam hierarki
  static void switchTab(
    BuildContext context,
    int index, {
    int? formSourceOption,
  }) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    state?.navigateToTab(index, formSourceOption: formSourceOption);
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  final GlobalKey<ScreeningFormScreenState> _formKey =
      GlobalKey<ScreeningFormScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  void navigateToTab(int index, {int? formSourceOption}) {
    if (index < 0 || index > 4) return;
    setState(() {
      _currentIndex = index;
    });

    if (index == 2 && formSourceOption != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.setSourceOption(formSourceOption);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScreeningProvider>();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Jika sedang di tab selain Beranda, tekan back akan kembali ke Beranda dulu
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(
              onNavigateToTab: (index, {formSourceOption}) {
                navigateToTab(index, formSourceOption: formSourceOption);
              },
            ),
            const SimulationScreen(),
            ScreeningFormScreen(
              key: _formKey,
              isTab: true,
            ),
            const ScreeningHistoryScreen(
              isTab: true,
            ),
            const SystemInfoScreen(),
          ],
        ),
        bottomNavigationBar: ClinicalBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => navigateToTab(index),
          pendingReviewCount: provider.pendingVerificationCount,
        ),
      ),
    );
  }
}
