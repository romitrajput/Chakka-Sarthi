import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sanjay_roadlines_fleet/models/vehicle_model.dart';
import 'package:sanjay_roadlines_fleet/repositories/vehicle_repository.dart';
import 'package:sanjay_roadlines_fleet/providers/auth_provider.dart';

part 'vehicle_provider.g.dart';

@riverpod
VehicleRepository vehicleRepository(VehicleRepositoryRef ref) {
  return VehicleRepository();
}

@riverpod
class VehicleState extends _$VehicleState {
  @override
  FutureOr<List<VehicleModel>> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return [];
    return ref.read(vehicleRepositoryProvider).getAllVehicles(user.companyCode);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authStateProvider).value;
      if (user == null) return [];
      return ref.read(vehicleRepositoryProvider).getAllVehicles(user.companyCode);
    });
  }

  Future<void> addVehicle(String vehicleNumber) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await ref.read(vehicleRepositoryProvider).addVehicle(
            vehicleNumber: vehicleNumber,
            companyCode: user.companyCode,
          );
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // BULK INSERT VEHICLES
  Future<int> bulkInsertVehicles(List<String> vehicleNumbers) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return 0;

    try {
      final count = await ref.read(vehicleRepositoryProvider).bulkInsertVehicles(
            vehicleNumbers: vehicleNumbers,
            companyCode: user.companyCode,
          );
      await refresh();
      return count;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String vehicleId,
    required String status,
    String? reason,
    DateTime? from,
    DateTime? to,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(vehicleRepositoryProvider).updateVehicleStatus(
            vehicleId: vehicleId,
            status: status,
            maintenanceReason: reason,
            maintenanceFrom: from,
            maintenanceExpectedReturn: to,
          );
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await ref.read(vehicleRepositoryProvider).deleteVehicle(vehicleId);
      await refresh();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

@riverpod
Future<List<VehicleModel>> availableVehicles(AvailableVehiclesRef ref) async {
  final vehicles = await ref.watch(vehicleStateProvider.future);
  return vehicles.where((v) => v.status == 'available').toList();
}

@riverpod
Future<List<String>> allVehicleNumbers(AllVehicleNumbersRef ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(vehicleRepositoryProvider).getAllVehicleNumbers(user.companyCode);
}
