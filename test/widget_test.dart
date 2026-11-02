import 'package:flutter_test/flutter_test.dart';
import 'package:fedmind_mobile_app/main.dart';
import 'package:fedmind_mobile_app/core/network/api_client.dart';
import 'package:fedmind_mobile_app/data/datasources/screening_remote_datasource.dart';
import 'package:fedmind_mobile_app/data/models/screening_models.dart';
import 'package:fedmind_mobile_app/data/repositories/screening_repository.dart';

import 'package:fedmind_mobile_app/core/services/local_inference_service.dart';

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
    return {'status': 'ok', 'model_loaded': true, 'device': 'cuda'};
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
}

void main() {
  testWidgets('FedMindApp smoke test with stub repository', (WidgetTester tester) async {
    await tester.pumpWidget(FedMindApp(repository: FakeScreeningRepository()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FED-MIND'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Screening'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
