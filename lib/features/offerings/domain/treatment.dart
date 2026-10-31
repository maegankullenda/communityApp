const beautyServiceId = 'beauty';

final class Treatment {
  const Treatment({
    required this.id,
    required this.providerId,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.duration,
    required this.priceCents,
  });

  final String id;
  final String providerId;
  final String serviceId;
  final String name;
  final String description;
  final Duration duration;
  final int priceCents;

  String get durationLabel {
    final hours = duration.inMinutes / 60;
    if (hours == hours.roundToDouble()) {
      return 'Duration: ~${hours.round()}h';
    }
    return 'Duration: ${duration.inMinutes} min';
  }
}

final class TreatmentDraft {
  const TreatmentDraft({
    this.id,
    required this.name,
    required this.description,
    required this.durationHours,
    required this.priceCents,
  });

  final String? id;
  final String name;
  final String description;
  final int? durationHours;
  final int? priceCents;
}
