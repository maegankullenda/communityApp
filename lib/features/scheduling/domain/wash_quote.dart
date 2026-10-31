import 'package:community_app/core/result.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

/// The price and time a set of vehicles needs for the washes they chose.
final class WashQuote {
  const WashQuote({
    required this.priceCents,
    required this.duration,
    required this.washId,
    required this.washName,
    required this.vehicleWashes,
  });

  /// Wash prices added once for each vehicle.
  final int priceCents;
  final Duration duration;

  /// Set when every vehicle takes the same wash.
  final String? washId;
  final String washName;
  final Map<String, String> vehicleWashes;
}

/// Prices each selected vehicle's wash. The same wash is charged again for
/// every vehicle. A vehicle can take a different wash from the others.
Result<WashQuote?, BookingFailure> quoteVehicleWashes({
  required List<WashOption> offered,
  required List<String> vehicleIds,
  Map<String, VehicleType> vehicleTypes = const {},
  Map<String, String> vehicleWashes = const {},
  String? washId,
}) {
  if (offered.isEmpty) {
    return const Success(null);
  }
  final assigned = <String, String>{};
  if (vehicleWashes.isNotEmpty) {
    assigned.addAll(vehicleWashes);
  } else {
    final shared = washId?.trim() ?? '';
    if (shared.isNotEmpty) {
      for (final id in vehicleIds) {
        assigned[id] = shared;
      }
    }
  }
  if (vehicleIds.isEmpty ||
      vehicleIds.any((id) => (assigned[id] ?? '').isEmpty)) {
    return const Err(BookingFailure.washRequired);
  }
  final ordered = <String, String>{};
  var priceCents = 0;
  Duration? duration;
  final names = <String>[];
  String? sharedId;
  var sameWash = true;
  for (final id in vehicleIds) {
    final chosenId = assigned[id]!;
    final matches = [
      for (final wash in offered)
        if (wash.id == chosenId) wash,
    ];
    if (matches.isEmpty) {
      return const Err(BookingFailure.unknownWash);
    }
    final wash = matches.single;
    final rate = wash.rateFor(vehicleTypes[id] ?? VehicleType.hatch);
    ordered[id] = wash.id;
    priceCents += rate.priceCents;
    if (duration == null || rate.duration > duration) {
      duration = rate.duration;
    }
    if (!names.contains(wash.name)) {
      names.add(wash.name);
    }
    sharedId ??= wash.id;
    if (sharedId != wash.id) {
      sameWash = false;
    }
  }
  return Success(
    WashQuote(
      priceCents: priceCents,
      duration: duration!,
      washId: sameWash ? sharedId : null,
      washName: names.join(', '),
      vehicleWashes: ordered,
    ),
  );
}

Future<Result<WashQuote?, BookingFailure>> loadWashQuote({
  required WashRepository washes,
  required String providerId,
  required String serviceId,
  required List<String> vehicleIds,
  Map<String, VehicleType> vehicleTypes = const {},
  Map<String, String> vehicleWashes = const {},
  String? washId,
}) async {
  final offered = await washes.washesFor(
    providerId: providerId,
    serviceId: serviceId,
  );
  return quoteVehicleWashes(
    offered: offered,
    vehicleIds: vehicleIds,
    vehicleTypes: vehicleTypes,
    vehicleWashes: vehicleWashes,
    washId: washId,
  );
}
