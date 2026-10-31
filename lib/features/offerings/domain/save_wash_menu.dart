import 'package:community_app/core/id_generator.dart';
import 'package:community_app/core/result.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/offerings/domain/wash_repository.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';

enum WashMenuFailure { emptyName, duplicateName, invalidDuration, invalidPrice }

final class VehicleRateDraft {
  const VehicleRateDraft({
    required this.durationHours,
    required this.priceCents,
  });

  final int durationHours;
  final int priceCents;
}

final class WashDraft {
  const WashDraft({
    this.id,
    required this.name,
    required this.durationHours,
    required this.priceCents,
    this.description = '',
    this.rates = const {},
  });

  final String? id;
  final String name;
  final int durationHours;
  final int priceCents;
  final String description;

  /// When empty, [durationHours] and [priceCents] apply to every vehicle type.
  final Map<VehicleType, VehicleRateDraft> rates;
}

final class SaveWashMenu {
  const SaveWashMenu({required WashRepository washes, required IdGenerator ids})
    : _washes = washes,
      _ids = ids;

  final WashRepository _washes;
  final IdGenerator _ids;

  Future<Result<List<WashOption>, WashMenuFailure>> call({
    required String providerId,
    required String serviceId,
    required List<WashDraft> washes,
  }) async {
    final names = <String>{};
    for (final wash in washes) {
      final name = wash.name.trim();
      if (name.isEmpty) {
        return const Err(WashMenuFailure.emptyName);
      }
      final key = name.toLowerCase();
      if (!names.add(key)) {
        return const Err(WashMenuFailure.duplicateName);
      }
      if (_ratesFor(wash) == null) {
        return Err(ratesFailure(wash));
      }
    }

    final current = await _washes.washesFor(
      providerId: providerId,
      serviceId: serviceId,
    );
    final known = {for (final wash in current) wash.id};
    final saved = [
      for (final wash in washes)
        _washOption(
          wash: wash,
          id: wash.id != null && known.contains(wash.id)
              ? wash.id!
              : _ids.next('wash'),
          providerId: providerId,
          serviceId: serviceId,
        ),
    ];
    await _washes.replaceWashes(
      providerId: providerId,
      serviceId: serviceId,
      washes: saved,
    );
    return Success(saved);
  }
}

WashOption _washOption({
  required WashDraft wash,
  required String id,
  required String providerId,
  required String serviceId,
}) {
  final rates = _ratesFor(wash)!;
  final hatch = rates[VehicleType.hatch]!;
  return WashOption(
    id: id,
    providerId: providerId,
    serviceId: serviceId,
    name: wash.name.trim(),
    duration: hatch.duration,
    priceCents: hatch.priceCents,
    description: wash.description.trim(),
    rates: rates,
  );
}

Map<VehicleType, VehicleWashRate>? _ratesFor(WashDraft wash) {
  if (wash.rates.isEmpty) {
    if (!washDurationHours.contains(wash.durationHours) ||
        wash.priceCents <= 0) {
      return null;
    }
    final shared = VehicleWashRate(
      duration: Duration(hours: wash.durationHours),
      priceCents: wash.priceCents,
    );
    return {for (final type in VehicleType.values) type: shared};
  }
  final rates = <VehicleType, VehicleWashRate>{};
  for (final type in VehicleType.values) {
    final rate = wash.rates[type];
    if (rate == null ||
        !washDurationHours.contains(rate.durationHours) ||
        rate.priceCents <= 0) {
      return null;
    }
    rates[type] = VehicleWashRate(
      duration: Duration(hours: rate.durationHours),
      priceCents: rate.priceCents,
    );
  }
  return rates;
}

WashMenuFailure ratesFailure(WashDraft wash) {
  final rates = wash.rates.isEmpty
      ? {
          for (final type in VehicleType.values)
            type: VehicleRateDraft(
              durationHours: wash.durationHours,
              priceCents: wash.priceCents,
            ),
        }
      : wash.rates;
  for (final rate in rates.values) {
    if (!washDurationHours.contains(rate.durationHours)) {
      return WashMenuFailure.invalidDuration;
    }
    if (rate.priceCents <= 0) {
      return WashMenuFailure.invalidPrice;
    }
  }
  return WashMenuFailure.invalidPrice;
}
