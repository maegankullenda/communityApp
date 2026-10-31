import 'package:community_app/core/result.dart';
import 'package:community_app/features/profile/domain/car_wash_pricing.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

final class VehicleSnapshot {
  const VehicleSnapshot({
    this.label,
    this.priceCents,
    this.vehicleIds = const [],
    this.vehicleTypes = const {},
  });

  final String? label;
  final int? priceCents;
  final List<String> vehicleIds;
  final Map<String, VehicleType> vehicleTypes;
}

Future<Result<VehicleSnapshot, BookingFailure>> snapshotVehicles({
  required ProfileRepository profiles,
  required String userId,
  required String serviceId,
  required List<String> vehicleIds,
}) async {
  if (!serviceRequiresVehicle(serviceId)) {
    return const Success(VehicleSnapshot());
  }
  final requested = <String>[];
  for (final id in vehicleIds) {
    if (id.isEmpty || requested.contains(id)) {
      continue;
    }
    requested.add(id);
  }
  if (requested.isEmpty) {
    return const Err(BookingFailure.vehicleRequired);
  }
  final profile = await profiles.find(userId);
  final chosen = <Vehicle>[];
  for (final id in requested) {
    final matches = [
      for (final candidate in profile.vehicles)
        if (candidate.id == id) candidate,
    ];
    if (matches.isEmpty) {
      return const Err(BookingFailure.unknownVehicle);
    }
    chosen.add(matches.single);
  }
  return Success(
    VehicleSnapshot(
      label: chosen.map(vehicleBookingLabel).join(', '),
      priceCents: chosen.fold<int>(
        0,
        (sum, vehicle) => sum + carWashPriceCents(vehicle.type),
      ),
      vehicleIds: [for (final vehicle in chosen) vehicle.id],
      vehicleTypes: {for (final vehicle in chosen) vehicle.id: vehicle.type},
    ),
  );
}
