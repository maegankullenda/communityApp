import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/scheduling/domain/time_slot.dart';

void main() {
  TimeSlot slot({int capacity = 1, int bookedCount = 0}) {
    return TimeSlot(
      id: 'slot-1',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 6, 9),
      duration: const Duration(hours: 1),
      capacity: capacity,
      bookedCount: bookedCount,
    );
  }

  test('a slot with room can take one more booking', () {
    final reserved = slot(capacity: 2).reserveOne();

    expect(reserved.bookedCount, 1);
    expect(reserved.hasCapacity, isTrue);
  });

  test('a full slot cannot be reserved again', () {
    final full = slot(bookedCount: 1);

    expect(full.hasCapacity, isFalse);
    expect(full.reserveOne, throwsStateError);
  });

  test('reserving one place leaves the other fields unchanged', () {
    final reserved = slot(capacity: 2).reserveOne();

    expect(reserved.id, 'slot-1');
    expect(reserved.providerId, 'sam-shine');
    expect(reserved.serviceId, 'car-wash');
    expect(reserved.start, DateTime(2026, 10, 6, 9));
    expect(reserved.duration, const Duration(hours: 1));
    expect(reserved.capacity, 2);
  });

  test('releasing a booking opens the time again', () {
    final released = slot(bookedCount: 1).releaseOne();

    expect(released.bookedCount, 0);
    expect(released.hasCapacity, isTrue);
    expect(slot().releaseOne, throwsStateError);
  });
}
