import 'package:community_app/features/catalog/domain/community_service.dart';
import 'package:community_app/features/catalog/domain/service_provider.dart';
import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/features/offerings/domain/service_offering.dart';
import 'package:community_app/features/scheduling/domain/opening_hours.dart';
import 'package:community_app/features/offerings/domain/treatment.dart';
import 'package:community_app/features/offerings/domain/wash_option.dart';
import 'package:community_app/features/notifications/domain/app_notification.dart';
import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/ordering/domain/menu_item.dart';
import 'package:community_app/features/profile/domain/customer_profile.dart';
import 'package:community_app/features/profile/domain/vehicle.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';
import 'package:community_app/features/scheduling/domain/time_slot.dart';

/// Matches the API's fixed-width wall-clock text, such as 09:00 on a day.
String wallClockIso(DateTime value) {
  final clock = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
  );
  String two(int number) => number.toString().padLeft(2, '0');
  final year = clock.year.toString().padLeft(4, '0');
  final milliseconds = clock.millisecond.toString().padLeft(3, '0');
  return '$year-${two(clock.month)}-${two(clock.day)}'
      'T${two(clock.hour)}:${two(clock.minute)}:${two(clock.second)}'
      '.$milliseconds';
}

DateTime parseWallClock(String value) => DateTime.parse(value);

Account accountFromJson(Map<String, dynamic> json) {
  return Account(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: switch (json['role']) {
      'provider' => AccountRole.provider,
      'admin' => AccountRole.admin,
      _ => AccountRole.customer,
    },
    providerId: json['providerId'] as String?,
  );
}

CommunityService serviceFromJson(Map<String, dynamic> json) {
  return CommunityService(
    id: json['id'] as String,
    name: json['name'] as String,
    summary: json['summary'] as String,
    fulfillment: json['fulfillment'] == 'order'
        ? FulfillmentKind.order
        : FulfillmentKind.appointment,
    active: json['active'] != false,
  );
}

Map<String, dynamic> serviceToJson(CommunityService service) {
  return {
    'name': service.name,
    'summary': service.summary,
    'fulfillment': service.fulfillment == FulfillmentKind.order
        ? 'order'
        : 'appointment',
    'active': service.active,
  };
}

ServiceProvider providerFromJson(Map<String, dynamic> json) {
  return ServiceProvider(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    bio: json['bio'] as String,
    serviceIds: {
      for (final id in json['serviceIds'] as List<dynamic>) id as String,
    },
    inactiveServiceIds: {
      for (final id
          in (json['inactiveServiceIds'] as List<dynamic>?) ?? const [])
        id as String,
    },
    active: json['active'] != false,
  );
}

Map<String, dynamic> providerToJson(ServiceProvider provider) {
  return {
    'displayName': provider.displayName,
    'bio': provider.bio,
    'serviceIds': provider.serviceIds.toList(),
    'inactiveServiceIds': provider.inactiveServiceIds.toList(),
    'active': provider.active,
  };
}

TimeSlot slotFromJson(Map<String, dynamic> json) {
  return TimeSlot(
    id: json['id'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    start: parseWallClock(json['start'] as String),
    duration: Duration(minutes: json['durationMinutes'] as int),
    capacity: json['capacity'] as int,
    bookedCount: json['bookedCount'] as int,
  );
}

Map<String, dynamic> slotToJson(TimeSlot slot) {
  return {
    'id': slot.id,
    'providerId': slot.providerId,
    'serviceId': slot.serviceId,
    'start': wallClockIso(slot.start),
    'durationMinutes': slot.duration.inMinutes,
    'capacity': slot.capacity,
    'bookedCount': slot.bookedCount,
  };
}

Appointment appointmentFromJson(Map<String, dynamic> json) {
  return Appointment(
    id: json['id'] as String,
    userId: json['userId'] as String,
    slotId: json['slotId'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    start: parseWallClock(json['start'] as String),
    duration: Duration(minutes: json['durationMinutes'] as int),
    status: switch (json['status']) {
      'cancelled' => AppointmentStatus.cancelled,
      'pending' => AppointmentStatus.pending,
      'declined' => AppointmentStatus.declined,
      _ => AppointmentStatus.booked,
    },
    vehicleLabel: json['vehicleLabel'] as String?,
    priceCents: json['priceCents'] as int?,
    vehicleIds: [
      for (final id in (json['vehicleIds'] as List<dynamic>?) ?? const [])
        id as String,
    ],
    washId: json['washId'] as String?,
    washName: json['washName'] as String?,
    vehicleWashes: {
      for (final entry in ((json['vehicleWashes'] as Map?) ?? const {}).entries)
        entry.key.toString(): entry.value.toString(),
    },
    declineMessage: json['declineMessage'] as String? ?? '',
    suggestedFrom: json['suggestedFrom'] == null
        ? null
        : parseWallClock(json['suggestedFrom'] as String),
    suggestedUntil: json['suggestedUntil'] == null
        ? null
        : parseWallClock(json['suggestedUntil'] as String),
  );
}

Map<String, dynamic> washToJson(WashOption wash) {
  return {
    'id': wash.id,
    'providerId': wash.providerId,
    'serviceId': wash.serviceId,
    'name': wash.name,
    'durationMinutes': wash.duration.inMinutes,
    'priceCents': wash.priceCents,
    'description': wash.description,
    'rates': {
      for (final type in VehicleType.values)
        type.name: {
          'durationMinutes': wash.rateFor(type).duration.inMinutes,
          'priceCents': wash.rateFor(type).priceCents,
        },
    },
  };
}

WashOption washFromJson(Map<String, dynamic> json) {
  final duration = Duration(minutes: json['durationMinutes'] as int);
  final priceCents = json['priceCents'] as int;
  return WashOption(
    id: json['id'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    name: json['name'] as String,
    duration: duration,
    priceCents: priceCents,
    description: json['description'] as String? ?? '',
    rates: _washRates(json['rates'], duration, priceCents),
  );
}

Map<VehicleType, VehicleWashRate> _washRates(
  Object? value,
  Duration fallbackDuration,
  int fallbackPrice,
) {
  if (value is! Map) {
    return const {};
  }
  final rates = <VehicleType, VehicleWashRate>{};
  for (final type in VehicleType.values) {
    final rate = value[type.name];
    if (rate is! Map) {
      continue;
    }
    rates[type] = VehicleWashRate(
      duration: Duration(
        minutes:
            (rate['durationMinutes'] as int?) ?? fallbackDuration.inMinutes,
      ),
      priceCents: (rate['priceCents'] as int?) ?? fallbackPrice,
    );
  }
  return rates;
}

ServiceOffering offeringFromJson(Map<String, dynamic> json) {
  return ServiceOffering(
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    openHours: [
      for (final hour in json['openHours'] as List<dynamic>? ?? const [])
        hour as int,
    ],
    weekdayHours: [
      for (final hour in json['weekdayHours'] as List<dynamic>? ?? const [])
        hour as int,
    ],
    weekendHours: [
      for (final hour in json['weekendHours'] as List<dynamic>? ?? const [])
        hour as int,
    ],
    openWeekdays: [
      for (final day in json['openWeekdays'] as List<dynamic>? ?? const [])
        day as int,
    ],
    advanceAmount: json['advanceAmount'] as int? ?? 0,
    advanceUnit: advanceUnitFromName(json['advanceUnit'] as String?),
    openForAmount: json['openForAmount'] as int? ?? 1,
    openForUnit: switch (json['openForUnit'] as String?) {
      'day' => AdvanceUnit.day,
      'month' => AdvanceUnit.month,
      _ => AdvanceUnit.week,
    },
    autoConfirm: json['autoConfirm'] != false,
    concurrentBookings: json['concurrentBookings'] as int? ?? 1,
  );
}

Map<String, dynamic> offeringToJson(ServiceOffering offering) {
  return {
    'providerId': offering.providerId,
    'serviceId': offering.serviceId,
    'name': offering.name,
    'description': offering.description,
    'openHours': offering.openHours,
    'weekdayHours': offering.weekdayHours,
    'weekendHours': offering.weekendHours,
    'openWeekdays': offering.openWeekdays,
    'advanceAmount': offering.advanceAmount,
    'advanceUnit': offering.advanceUnit.name,
    'openForAmount': offering.openForAmount,
    'openForUnit': offering.openForUnit.name,
    'autoConfirm': offering.autoConfirm,
    'concurrentBookings': offering.concurrentBookings,
  };
}

Treatment treatmentFromJson(Map<String, dynamic> json) {
  return Treatment(
    id: json['id'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    duration: Duration(minutes: json['durationMinutes'] as int),
    priceCents: json['priceCents'] as int,
  );
}

Map<String, dynamic> treatmentToJson(Treatment treatment) {
  return {
    'id': treatment.id,
    'providerId': treatment.providerId,
    'serviceId': treatment.serviceId,
    'name': treatment.name,
    'description': treatment.description,
    'durationMinutes': treatment.duration.inMinutes,
    'priceCents': treatment.priceCents,
  };
}

MenuItem menuItemFromJson(Map<String, dynamic> json) {
  return MenuItem(
    id: json['id'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    priceCents: json['priceCents'] as int,
    availableFrom: parseWallClock(json['availableFrom'] as String),
    availableUntil: parseWallClock(json['availableUntil'] as String),
  );
}

Map<String, dynamic> menuItemToJson(MenuItem item) {
  return {
    'id': item.id,
    'providerId': item.providerId,
    'serviceId': item.serviceId,
    'name': item.name,
    'description': item.description,
    'priceCents': item.priceCents,
    'availableFrom': wallClockIso(item.availableFrom),
    'availableUntil': wallClockIso(item.availableUntil),
  };
}

CustomerOrder orderFromJson(Map<String, dynamic> json) {
  return CustomerOrder(
    id: json['id'] as String,
    userId: json['userId'] as String,
    providerId: json['providerId'] as String,
    serviceId: json['serviceId'] as String,
    placedAt: parseWallClock(json['placedAt'] as String),
    status: json['status'] == 'cancelled'
        ? OrderStatus.cancelled
        : OrderStatus.placed,
    lines: [for (final raw in json['lines'] as List<dynamic>) _orderLine(raw)],
  );
}

Map<String, dynamic> orderToJson(CustomerOrder order) {
  return {
    'id': order.id,
    'userId': order.userId,
    'providerId': order.providerId,
    'serviceId': order.serviceId,
    'placedAt': wallClockIso(order.placedAt),
    'status': order.status == OrderStatus.cancelled ? 'cancelled' : 'placed',
    'lines': [
      for (final line in order.lines)
        {
          'itemId': line.itemId,
          'name': line.name,
          'quantity': line.quantity,
          'unitPriceCents': line.unitPriceCents,
        },
    ],
  };
}

CustomerProfile profileFromJson(Map<String, dynamic> json) {
  return CustomerProfile(
    accountId: json['accountId'] as String,
    firstName: json['firstName'] as String? ?? '',
    surname: json['surname'] as String? ?? '',
    address: json['address'] as String,
    contactNumber: json['contactNumber'] as String,
    vehicles: [
      for (final vehicle in json['vehicles'] as List<dynamic>)
        Vehicle(
          id: (vehicle as Map<String, dynamic>)['id'] as String,
          name: vehicle['name'] as String,
          type: _vehicleType(vehicle['type'] as String),
          registration: vehicle['registration'] as String? ?? '',
        ),
    ],
  );
}

Map<String, dynamic> profileToJson(CustomerProfile profile) {
  return {
    'firstName': profile.firstName,
    'surname': profile.surname,
    'address': profile.address,
    'contactNumber': profile.contactNumber,
    'vehicles': [
      for (final vehicle in profile.vehicles)
        {
          'id': vehicle.id,
          'name': vehicle.name,
          'type': vehicle.type.name,
          'registration': vehicle.registration,
        },
    ],
  };
}

VehicleType _vehicleType(String value) {
  return switch (value) {
    'sedan' => VehicleType.sedan,
    'suv' => VehicleType.suv,
    _ => VehicleType.hatch,
  };
}

AppNotification notificationFromJson(Map<String, dynamic> json) {
  return AppNotification(
    id: json['id'] as String,
    accountId: json['accountId'] as String,
    appointmentId: json['appointmentId'] as String,
    kind: BookingNoticeKind.values.byName(json['kind'] as String),
    message: json['message'] as String,
    createdAt: parseWallClock(json['createdAt'] as String),
    visibleUntil: _optionalTime(json['visibleUntil']),
    read: json['read'] == true,
  );
}

DateTime? _optionalTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return parseWallClock(value);
}

Map<String, dynamic> notificationToJson(AppNotification notice) {
  return {
    'id': notice.id,
    'accountId': notice.accountId,
    'appointmentId': notice.appointmentId,
    'kind': notice.kind.name,
    'message': notice.message,
    'createdAt': wallClockIso(notice.createdAt),
    'visibleUntil': notice.visibleUntil == null
        ? null
        : wallClockIso(notice.visibleUntil!),
    'read': notice.read,
  };
}

OrderLine _orderLine(Object? raw) {
  final line = Map<String, dynamic>.from(raw as Map);
  return OrderLine(
    itemId: line['itemId'] as String,
    name: line['name'] as String,
    quantity: line['quantity'] as int,
    unitPriceCents: line['unitPriceCents'] as int,
  );
}
