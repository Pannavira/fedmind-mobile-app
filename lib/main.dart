import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/screening_remote_datasource.dart';
import 'data/repositories/screening_repository.dart';
import 'presentation/providers/screening_provider.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/system/setup_requirements_screen.dart';

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
        title: 'FED-MIND Clinical',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SetupGate(child: MainNavigationScreen()),
      ),
    );
  }
}
