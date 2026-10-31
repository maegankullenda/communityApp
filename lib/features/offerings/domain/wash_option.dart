import 'package:community_app/features/profile/domain/vehicle.dart';

/// Price and time for one wash on one vehicle type.
final class VehicleWashRate {
  const VehicleWashRate({required this.duration, required this.priceCents});

  final Duration duration;
  final int priceCents;

  int get durationHours => duration.inHours;
}

final class WashOption {
  const WashOption({
    required this.id,
    required this.providerId,
    required this.serviceId,
    required this.name,
    required this.duration,
    required this.priceCents,
    this.description = '',
    this.rates = const {},
  });

  final String id;
  final String providerId;
  final String serviceId;
  final String name;

  /// Hatch duration, kept for washes saved before each vehicle type had its own.
  final Duration duration;

  /// Hatch price, kept for washes saved before each vehicle type had its own.
  final int priceCents;
  final String description;
  final Map<VehicleType, VehicleWashRate> rates;

  int get durationHours => duration.inHours;

  VehicleWashRate rateFor(VehicleType type) {
    return rates[type] ??
        VehicleWashRate(duration: duration, priceCents: priceCents);
  }
}

const washDurationHours = [1, 2, 3, 4];
