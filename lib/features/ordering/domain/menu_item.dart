final class MenuItem {
  const MenuItem({
    required this.id,
    required this.providerId,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.availableFrom,
    required this.availableUntil,
  });

  final String id;
  final String providerId;
  final String serviceId;
  final String name;
  final String description;
  final int priceCents;
  final DateTime availableFrom;
  final DateTime availableUntil;

  bool isAvailableAt(DateTime instant) {
    return !instant.isBefore(availableFrom) && instant.isBefore(availableUntil);
  }
}
