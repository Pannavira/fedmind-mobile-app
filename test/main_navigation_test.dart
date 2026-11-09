import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/main_navigation_screen.dart';
import 'package:fedmind_mobile_app/presentation/widgets/clinical_bottom_nav_bar.dart';

class FakeLocalInferenceService extends LocalInferenceService {
  @override
  Future<void> initialize() async {}
}

class FakeScreeningRepository extends ScreeningRepository {
  FakeScreeningRepository()
      : super(
          remoteDataSource: ScreeningRemoteDataSource(apiClient: ApiClient()),
          localInferenceService: FakeLocalInferenceService(),
        );

  @override
  Future<Map<String, dynamic>> checkHealth() async {
    return {'status': 'ok', 'model_loaded': true, 'device': 'cpu'};
  }

  @override
  Future<Map<String, dynamic>> getModelInfo() async {
    return {'architecture': 'Late-Fusion Attention', 'model': 'Baseline'};
  }

  @override
  Future<ScreeningListResponse> getScreeningHistory({
    int skip = 0,
    int limit = 20,
    String? participantId,
    String? status,
  }) async {
    return ScreeningListResponse(total: 0, screenings: []);
  }

  @override
  Future<List<ScreeningSummaryItem>> getLocalScreeningHistory({
    int skip = 0,
    int limit = 50,
    String? participantId,
    String? riskCategory,
  }) async {
    return [
      ScreeningSummaryItem(
        screeningId: 'test-001',
        participantId: 'RM-2026-TEST',
        createdAt: DateTime.now().toIso8601String(),
        status: 'completed',
        riskCategory: 'moderate',
        phq8Score: 11.2,
        dominantModality: 'visual',
        isVerified: false,
      ),
    ];
  }

  @override
  Future<int> getLocalScreeningTotalCount() async {
    return 1;
  }
}

void main() {
  Widget createTestWidget() {
    final repo = FakeScreeningRepository();
    final provider = ScreeningProvider(repository: repo);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScreeningProvider>.value(value: provider),
      ],
      child: const MaterialApp(
        home: MainNavigationScreen(),
      ),
    );
  }

  Future<void> dismissDisclaimerIfPresent(WidgetTester tester) async {
    final confirmBtn = find.text('Konfirmasi Otorisasi Klinisi & Buka Konsol');
    if (confirmBtn.evaluate().isNotEmpty) {
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
      'MainNavigationScreen renders ClinicalBottomNavBar with 5 items & switches tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
    await dismissDisclaimerIfPresent(tester);

    // Pastikan 5 label tab ada di navbar
    expect(find.byType(ClinicalBottomNavBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Simulasi'), findsOneWidget);
    expect(find.text('Analisa'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Initial state harus berada di Beranda
    expect(find.text('FEDMIND Prototype 1'), findsOneWidget);

    // 1. Pindah ke Tab Simulasi (samping Home)
    await tester.tap(find.text('Simulasi'));
    await tester.pumpAndSettle();

    expect(find.text('Simulasi & Benchmark'), findsOneWidget);
    expect(find.text('Golden Case P600 (E-DAIC Reference)'), findsOneWidget);

    // 2. Pindah ke Tab Analisa
    await tester.tap(find.text('Analisa'));
    await tester.pumpAndSettle();

    expect(find.text('Pemeriksaan Baru'), findsOneWidget);
    expect(find.text('Pilihan Sumber Modalitas Observasi'), findsOneWidget);

    // 3. Pindah ke Tab History
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Pemeriksaan'), findsOneWidget);

    // 4. Pindah ke Tab Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Telemetri Federated Learning & CDSS'), findsOneWidget);
    expect(find.text('Arsitektur Federated Learning'), findsOneWidget);

    // 5. Kembali ke Home
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('FEDMIND Prototype 1'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen section "Uji Kasus Standar" is removed and "Mulai Pemeriksaan Pasien" navigates to Analisa tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
    await dismissDisclaimerIfPresent(tester);

    // Pastikan berada di Beranda
    expect(find.text('FEDMIND Prototype 1'), findsOneWidget);

    // Verifikasi shortcut "Uji Kasus Standar" sudah dihapus dari Home
    expect(find.text('Uji Kasus Standar (Golden Case P600)'), findsNothing);

    // Tekan kartu mulai pemeriksaan di Beranda
    await tester.tap(find.text('Mulai Pemeriksaan Pasien'));
    await tester.pumpAndSettle();

    // Verifikasi otomatis beralih ke tab Analisa
    expect(find.text('Pemeriksaan Baru'), findsOneWidget);
  });

  testWidgets(
      'Center prominent Analisa button renders with elevated circular design and responds to tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
    await dismissDisclaimerIfPresent(tester);

    // Pastikan tombol Analisa menonjol dengan icon analytics ada
    expect(find.byIcon(Icons.analytics_rounded), findsOneWidget);

    // Tap langsung pada ikon lingkaran tombol Analisa
    await tester.tap(find.byIcon(Icons.analytics_rounded));
    await tester.pumpAndSettle();

    // Verifikasi beralih ke halaman ScreeningFormScreen (Analisa)
    expect(find.text('Pemeriksaan Baru'), findsOneWidget);
  });
}
