import 'package:community_app/features/profile/domain/vehicle.dart';

final class CustomerProfile {
  const CustomerProfile({
    required this.accountId,
    required this.firstName,
    required this.surname,
    required this.address,
    required this.contactNumber,
    required this.vehicles,
  });

  final String accountId;
  final String firstName;
  final String surname;
  final String address;
  final String contactNumber;
  final List<Vehicle> vehicles;

  static CustomerProfile empty(String accountId) {
    return CustomerProfile(
      accountId: accountId,
      firstName: '',
      surname: '',
      address: '',
      contactNumber: '',
      vehicles: const [],
    );
  }
}

final class VehicleInput {
  const VehicleInput({
    this.id,
    required this.name,
    required this.type,
    this.registration = '',
  });

  final String? id;
  final String name;
  final VehicleType type;
  final String registration;
}
