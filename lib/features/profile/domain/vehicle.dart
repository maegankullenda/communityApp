enum VehicleType { hatch, sedan, suv }

const maxVehicles = 5;

final class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.type,
    this.registration = '',
  });

  final String id;
  final String name;
  final VehicleType type;
  final String registration;
}

String vehicleTypeLabel(VehicleType type) {
  return switch (type) {
    VehicleType.hatch => 'Hatch',
    VehicleType.sedan => 'Sedan',
    VehicleType.suv => 'SUV',
  };
}

String vehicleBookingLabel(Vehicle vehicle) {
  return '${vehicle.name} (${vehicleTypeLabel(vehicle.type)})';
}
