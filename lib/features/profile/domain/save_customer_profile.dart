import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/profile_repository.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';

enum ProfileFailure { emptyVehicleName, tooManyVehicles, invalidContactNumber }

final class SaveCustomerProfile {
  const SaveCustomerProfile({
    required ProfileRepository profiles,
    required IdGenerator ids,
  }) : _profiles = profiles,
       _ids = ids;

  final ProfileRepository _profiles;
  final IdGenerator _ids;

  Future<Result<CustomerProfile, ProfileFailure>> call({
    required String accountId,
    required String address,
    required String contactNumber,
    required List<VehicleInput> vehicles,
    String firstName = '',
    String surname = '',
  }) async {
    if (vehicles.length > maxVehicles) {
      return const Err(ProfileFailure.tooManyVehicles);
    }
    final phone = contactNumber.trim();
    if (!_isValidContactNumber(phone)) {
      return const Err(ProfileFailure.invalidContactNumber);
    }

    final existing = await _profiles.find(accountId);
    final existingIds = existing.vehicles.map((vehicle) => vehicle.id).toSet();
    final usedIds = <String>{};
    final savedVehicles = <Vehicle>[];
    for (final input in vehicles) {
      final name = input.name.trim();
      if (name.isEmpty) {
        return const Err(ProfileFailure.emptyVehicleName);
      }
      final requestedId = input.id;
      final id =
          requestedId != null &&
              existingIds.contains(requestedId) &&
              !usedIds.contains(requestedId)
          ? requestedId
          : _ids.next('vehicle');
      usedIds.add(id);
      savedVehicles.add(
        Vehicle(
          id: id,
          name: name,
          type: input.type,
          registration: input.registration.trim(),
        ),
      );
    }

    final profile = CustomerProfile(
      accountId: accountId,
      firstName: firstName.trim(),
      surname: surname.trim(),
      address: address.trim(),
      contactNumber: phone,
      vehicles: List.unmodifiable(savedVehicles),
    );
    await _profiles.save(profile);
    return Success(profile);
  }
}

bool _isValidContactNumber(String value) {
  if (value.isEmpty) {
    return true;
  }
  if (!RegExp(r'^[0-9+\-()\s]+$').hasMatch(value)) {
    return false;
  }
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7 && digits.length <= 15;
}
