final class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.providerId,
    required this.serviceId,
    required this.start,
    required this.duration,
    required this.capacity,
    this.bookedCount = 0,
  });

  final String id;
  final String providerId;
  final String serviceId;
  final DateTime start;
  final Duration duration;
  final int capacity;
  final int bookedCount;

  bool get hasCapacity => bookedCount < capacity;

  TimeSlot reserveOne() {
    if (!hasCapacity) {
      throw StateError('Time slot $id has no remaining capacity');
    }
    return TimeSlot(
      id: id,
      providerId: providerId,
      serviceId: serviceId,
      start: start,
      duration: duration,
      capacity: capacity,
      bookedCount: bookedCount + 1,
    );
  }

  TimeSlot releaseOne() {
    if (bookedCount == 0) {
      throw StateError('Time slot $id has no booking to release');
    }
    return TimeSlot(
      id: id,
      providerId: providerId,
      serviceId: serviceId,
      start: start,
      duration: duration,
      capacity: capacity,
      bookedCount: bookedCount - 1,
    );
  }
}
