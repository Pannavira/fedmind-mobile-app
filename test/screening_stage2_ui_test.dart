import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';
import 'package:fedmind_mobile_app/presentation/providers/screening_provider.dart';
import 'package:fedmind_mobile_app/presentation/screens/screening/screening_form_screen.dart';

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
    return [];
  }

  @override
  Future<int> getLocalScreeningTotalCount() async {
    return 0;
  }
}

void main() {
  testWidgets('Tahap 2 UI displays "Mulai Merekam" and does not render "Uji Transkrip"', (tester) async {
    final repo = FakeScreeningRepository();
    final provider = ScreeningProvider(repository: repo);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScreeningProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: ScreeningFormScreen(isTab: false),
        ),
      ),
    );

    await tester.pump();

    // Verify roadmap preview text in Tahap 1 shows "Mulai Merekam"
    expect(find.text('Mulai Merekam'), findsWidgets);
    expect(find.text('Pilihan Sumber Modalitas Observasi'), findsNothing);

    // Navigate to Tahap 2 by tapping "Media Video" step in stepper
    final mediaStep = find.text('Media Video');
    expect(mediaStep, findsOneWidget);
    await tester.tap(mediaStep);
    await tester.pump();

    // In Tahap 2:
    // 1. "Pilihan Sumber Modalitas Observasi" must not exist
    expect(find.text('Pilihan Sumber Modalitas Observasi'), findsNothing);

    // 2. "Uji Transkripsi Suara Langsung" or "Uji Transkrip" must not exist
    expect(find.text('Uji Transkripsi Suara Langsung'), findsNothing);
    expect(find.text('Uji Transkrip'), findsNothing);
    expect(find.text('Coba Suara'), findsNothing);

    // 3. Card Title and Button should be "Mulai Merekam"
    expect(find.text('Mulai Merekam Wawancara Klinis'), findsOneWidget);
    expect(find.text('Mulai Merekam'), findsWidgets);
  });
}
