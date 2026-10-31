import 'package:community_app/features/scheduling/domain/time_slot.dart';

/// Slots that begin inside [start, start + duration).
List<TimeSlot> slotsCoveredBy({
  required Iterable<TimeSlot> slots,
  required String providerId,
  required String serviceId,
  required DateTime start,
  required Duration duration,
}) {
  final end = start.add(duration);
  final covered = [
    for (final slot in slots)
      if (slot.providerId == providerId &&
          slot.serviceId == serviceId &&
          !slot.start.isBefore(start) &&
          slot.start.isBefore(end))
        slot,
  ]..sort((a, b) => a.id.compareTo(b.id));
  return covered;
}

/// True when every slot the wash would occupy is free, or already held.
bool washFitsOn({
  required TimeSlot start,
  required Duration duration,
  required Iterable<TimeSlot> slots,
  required Set<String> heldSlotIds,
}) {
  final covered = slotsCoveredBy(
    slots: slots,
    providerId: start.providerId,
    serviceId: start.serviceId,
    start: start.start,
    duration: duration,
  );
  if (covered.isEmpty || covered.every((slot) => slot.id != start.id)) {
    return false;
  }
  return covered.every(
    (slot) => slot.hasCapacity || heldSlotIds.contains(slot.id),
  );
}
