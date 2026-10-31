import 'package:community_app/features/profile/domain/vehicle.dart';

const carWashServiceId = 'car-wash';

/// A wash is priced from the vehicle size chosen at booking time.
int carWashPriceCents(VehicleType type) {
  return switch (type) {
    VehicleType.hatch => 12000,
    VehicleType.sedan => 16000,
    VehicleType.suv => 22000,
  };
}

bool serviceRequiresVehicle(String serviceId) => serviceId == carWashServiceId;
