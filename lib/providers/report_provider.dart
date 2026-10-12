import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sanjay_roadlines_fleet/repositories/report_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

part 'report_provider.g.dart';

@riverpod
ReportRepository reportRepository(ReportRepositoryRef ref) {
  return ReportRepository();
}

@riverpod
class ReportState extends _$ReportState {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return {};
    return ref.read(reportRepositoryProvider).getOverallSummary(user.companyCode);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) return {};
      return ref.read(reportRepositoryProvider).getOverallSummary(user.companyCode);
    });
  }
}

@riverpod
Future<List<Map<String, dynamic>>> vehicleWiseReport(VehicleWiseReportRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(reportRepositoryProvider).getVehicleWiseReport(user.companyCode);
}
