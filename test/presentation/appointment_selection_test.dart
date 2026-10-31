import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';
import 'package:community_app/presentation/appointment_page.dart';

void main() {
  test(
    'a customer sees their time as booked and a full time as fully booked',
    () {
      expect(
        slotChoiceLabel(time: '09:00', open: true, heldByCustomer: true),
        '09:00 Booked',
      );
      expect(
        slotChoiceLabel(time: '09:00', open: false, heldByCustomer: false),
        '09:00 Fully booked',
      );
      expect(
        slotChoiceLabel(time: '11:00', open: true, heldByCustomer: false),
        '11:00',
      );
    },
  );

  TimeSlot at(int day, int hour, {int bookedCount = 0}) {
    return TimeSlot(
      id: 'slot-$day-$hour',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, day, hour),
      duration: const Duration(hours: 1),
      capacity: 1,
      bookedCount: bookedCount,
    );
  }

  test('a repeated clock time is shown once', () {
    final grouped = groupSlotsByDay([
      at(9, 9),
      at(9, 9, bookedCount: 1),
      at(9, 11),
    ]);

    final day = grouped[DateTime(2026, 10, 9)]!;
    expect(day.map((slot) => slot.start.hour), [9, 11]);
    expect(day.first.bookedCount, 1);
  });

  test('the same clock time stays available on another day', () {
    final chosen = openSlotAtClock(
      [at(7, 9), at(7, 11)],
      hour: 9,
      minute: 0,
      available: (slot) => slot.hasCapacity,
    );

    expect(chosen?.id, 'slot-7-9');
  });

  test('a booked vehicle offers an update when another time is chosen', () {
    final city = Vehicle(id: 'city', name: 'City run', type: VehicleType.hatch);
    final booking = Appointment(
      id: 'appointment-1',
      userId: 'alex',
      slotId: 'slot-7-9',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 7, 9),
      duration: const Duration(hours: 1),
      status: AppointmentStatus.booked,
      vehicleIds: const ['city'],
    );

    expect(
      bookingForVehicle(
        vehicle: city,
        vehicles: [city],
        dayBookings: [booking],
      )?.id,
      'appointment-1',
    );
    expect(
      bookingToUpdate(
        dayBookings: [booking],
        vehicles: [city],
        selectedIds: {'city'},
        chosenSlotId: 'slot-7-11',
      )?.id,
      'appointment-1',
    );
    expect(
      bookingToUpdate(
        dayBookings: [booking],
        vehicles: [city],
        selectedIds: {'city'},
        chosenSlotId: 'slot-7-9',
      )?.id,
      'appointment-1',
    );
  });

  test('a different treatment can be booked at another time the same day', () {
    final facial = Appointment(
      id: 'facial',
      userId: 'alex',
      slotId: 'slot-19',
      providerId: 'maegans-rides',
      serviceId: 'beauty',
      start: DateTime(2026, 10, 10, 19),
      duration: const Duration(hours: 1),
      status: AppointmentStatus.booked,
      washId: 'facial',
      washName: 'Facial',
    );

    expect(
      selectionForTreatment(treatmentId: 'massage', dayBookings: [facial]).hour,
      isNull,
    );
    expect(
      selectionForTreatment(treatmentId: 'facial', dayBookings: [facial]).hour,
      19,
    );
    expect(
      bookingToUpdate(
        dayBookings: [facial],
        vehicles: const [],
        selectedIds: const {},
        chosenSlotId: 'slot-11',
        selectedWashId: 'massage',
      ),
      isNull,
    );
    expect(
      bookingToUpdate(
        dayBookings: [facial],
        vehicles: const [],
        selectedIds: const {},
        chosenSlotId: 'slot-11',
        selectedWashId: 'facial',
      )?.id,
      'facial',
    );
  });

  test('a day shows the earliest booking when several times are booked', () {
    final early = Appointment(
      id: 'early',
      userId: 'alex',
      slotId: 'slot-7-9',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 7, 9),
      duration: const Duration(hours: 1),
      status: AppointmentStatus.booked,
      vehicleIds: const ['city'],
      washId: 'wash-quick',
    );
    final later = Appointment(
      id: 'later',
      userId: 'alex',
      slotId: 'slot-7-11',
      providerId: 'sam-shine',
      serviceId: 'car-wash',
      start: DateTime(2026, 10, 7, 11),
      duration: const Duration(hours: 1),
      status: AppointmentStatus.booked,
      vehicleIds: const ['weekend'],
      washId: 'wash-full',
    );

    expect(bookingsToShow([later, early]).map((booking) => booking.id), [
      'early',
    ]);
  });

  test('a booked clock time is not kept selected', () {
    final chosen = openSlotAtClock(
      [at(7, 9, bookedCount: 1), at(7, 11)],
      hour: 9,
      minute: 0,
      available: (slot) => slot.hasCapacity,
    );

    expect(chosen, isNull);
  });

  test('a wash shows one duration, or a range when vehicle types differ', () {
    WashOption wash({
      required int hatch,
      required int sedan,
      required int suv,
    }) {
      return WashOption(
        id: 'wash',
        providerId: 'maegans-rides',
        serviceId: 'car-wash',
        name: 'Valet wash',
        duration: Duration(hours: hatch),
        priceCents: 100,
        rates: {
          VehicleType.hatch: VehicleWashRate(
            duration: Duration(hours: hatch),
            priceCents: 100,
          ),
          VehicleType.sedan: VehicleWashRate(
            duration: Duration(hours: sedan),
            priceCents: 100,
          ),
          VehicleType.suv: VehicleWashRate(
            duration: Duration(hours: suv),
            priceCents: 100,
          ),
        },
      );
    }

    expect(
      washDurationSummary(wash(hatch: 1, sedan: 1, suv: 1)),
      'Duration: ~1h',
    );
    expect(
      washDurationSummary(wash(hatch: 3, sedan: 4, suv: 3)),
      'Duration: 3-4 hours',
    );
  });
}
