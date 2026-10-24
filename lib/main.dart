import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/screening_remote_datasource.dart';
import 'data/repositories/screening_repository.dart';
import 'presentation/providers/screening_provider.dart';
import 'presentation/screens/history/screening_history_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/screening/screening_form_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FedMindApp());
}

class FedMindApp extends StatelessWidget {
  final ScreeningRepository? repository;

  const FedMindApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    final repo = repository ??
        ScreeningRepository(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
        );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ScreeningProvider(repository: repo),
        ),
      ],
      child: MaterialApp(
        title: 'FED-MIND Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainNavigationShell(),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ScreeningFormScreen(),
    ScreeningHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Skrining',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}
